defmodule AshOaskit.Router.Plug do
  @moduledoc """
  Plug for serving OpenAPI specifications via the Router macro.

  This plug is used internally by `AshOaskit.Router` to handle requests
  for OpenAPI specifications. It reads configuration from `conn.private.ash_oaskit`.

  ## Direct Usage (Advanced)

  While typically used via `AshOaskit.Router`, you can use this plug directly:

      # In your router
      get "/openapi.json", AshOaskit.Router.Plug, :call,
        private: %{
          ash_oaskit: %{
            domains: [MyApp.Blog],
            title: "My API",
            version: "1.0.0",
            openapi_version: "3.1",
            format: :json
          }
        }

  ## Configuration

  The plug reads these keys from `conn.private.ash_oaskit`:

    * `:domains` - List of Ash domains to include (required)
    * `:title` - API title (default: "API")
    * `:version` - API version string (default: "1.0.0")
    * `:description` - API description (optional)
    * `:openapi_version` - OpenAPI version: "3.0" or "3.1" (default: "3.1")
    * `:format` - Output format: `:json` or `:yaml` (default: `:json`)
    * `:servers` - List of server URLs or objects (optional)
    * `:spec_builder` - Custom SpecBuilder module (default: `AshOaskit.SpecBuilder.Default`)
  """

  @behaviour Plug

  import Plug.Conn

  @doc false
  @impl Plug
  def init(opts), do: opts

  @doc false
  @impl Plug
  def call(conn, opts) do
    # Config comes from either:
    # 1. Phoenix Router: opts is the config map passed via Phoenix.Router.get/3
    # 2. Plug.Router: config stored in conn.private[:ash_oaskit]
    config =
      case opts do
        %{domains: _} -> opts
        _ -> conn.private[:ash_oaskit] || %{}
      end

    domains = Map.get(config, :domains, [])

    if domains == [] do
      conn
      |> put_resp_content_type("application/json")
      |> send_resp(500, Jason.encode!(%{error: "No domains configured for OpenAPI spec"}))
    else
      spec = generate_spec(config)
      send_spec(conn, spec, Map.get(config, :format, :json))
    end
  end

  @doc """
  Generate OpenAPI spec from configuration map.

  Uses the configured `spec_builder` module if provided,
  otherwise falls back to `AshOaskit.SpecBuilder.Default`.

  ## Examples

      config = %{
        domains: [MyApp.Blog],
        title: "My API",
        openapi_version: "3.1"
      }
      spec = AshOaskit.Router.Plug.generate_spec(config)

      # With custom spec_builder
      config = %{
        domains: [MyApp.Blog],
        spec_builder: MyApp.CustomSpecBuilder,
        openapi_version: "3.1"
      }
      spec = AshOaskit.Router.Plug.generate_spec(config)
  """
  @spec generate_spec(map()) :: map()
  def generate_spec(config) do
    spec_builder = Map.get(config, :spec_builder, AshOaskit.SpecBuilder.Default)
    openapi_version = Map.get(config, :openapi_version, "3.1")

    spec_builder.spec(openapi_version, config)
  end

  defp send_spec(conn, spec, :json) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Oaskit.SpecDumper.to_json!(spec, pretty: true))
  end

  defp send_spec(conn, spec, :yaml) do
    if Code.ensure_loaded?(Ymlr) do
      conn
      |> put_resp_content_type("application/x-yaml")
      |> send_resp(200, Ymlr.document!(spec))
    else
      send_spec(conn, spec, :json)
    end
  end

  defp send_spec(conn, spec, _unknown) do
    send_spec(conn, spec, :json)
  end
end
