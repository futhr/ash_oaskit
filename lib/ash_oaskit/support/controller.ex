defmodule AshOaskit.Controller do
  @moduledoc """
  Phoenix controller for serving OpenAPI specifications.

  This module provides Plug-compatible controller actions for serving
  OpenAPI specs directly from your Phoenix application.

  ## Usage

  Add routes in your Phoenix router:

      scope "/api" do
        get "/openapi.json", AshOaskit.Controller, :spec
        get "/openapi-3.0.json", AshOaskit.Controller, :spec_30
        get "/openapi-3.1.json", AshOaskit.Controller, :spec_31
      end

  ## Configuration

  Configure domains and metadata in your application config:

      config :ash_oaskit,
        domains: [MyApp.Blog, MyApp.Accounts],
        title: "My API",
        api_version: "1.0.0",
        description: "My awesome API",
        version: "3.1"

  ## Per-Route Options

  Override configuration per-route using Phoenix's private assigns:

      get "/api/openapi.json", AshOaskit.Controller, :spec,
        private: %{ash_oaskit: [
          domains: [MyApp.Blog],
          title: "Blog API"
        ]}

  ## Response Format

  All actions return JSON with `application/json` content type and
  pretty-printed output for readability.

  ## Actions

    * `spec/2` - Serves the spec using the configured default version
    * `spec_30/2` - Always serves an OpenAPI 3.0 spec
    * `spec_31/2` - Always serves an OpenAPI 3.1 spec
  """

  import Plug.Conn

  @doc """
  Serve the OpenAPI spec using the configured default version.
  """
  @spec spec(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def spec(conn, _) do
    opts = get_options(conn)
    spec = AshOaskit.spec(opts)
    json_response(conn, spec)
  end

  @doc """
  Serve an OpenAPI 3.0 spec.
  """
  @spec spec_30(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def spec_30(conn, _) do
    opts = conn |> get_options() |> Keyword.put(:version, "3.0")
    spec = AshOaskit.spec(opts)
    json_response(conn, spec)
  end

  @doc """
  Serve an OpenAPI 3.1 spec.
  """
  @spec spec_31(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def spec_31(conn, _) do
    opts = conn |> get_options() |> Keyword.put(:version, "3.1")
    spec = AshOaskit.spec(opts)
    json_response(conn, spec)
  end

  # Get options from conn.private or application config
  defp get_options(conn) do
    route_opts = Map.get(conn.private, :ash_oaskit, [])

    default_opts = [
      domains: Application.get_env(:ash_oaskit, :domains, []),
      title: Application.get_env(:ash_oaskit, :title),
      api_version: Application.get_env(:ash_oaskit, :api_version),
      description: Application.get_env(:ash_oaskit, :description),
      servers: Application.get_env(:ash_oaskit, :servers),
      version: Application.get_env(:ash_oaskit, :version, "3.1")
    ]

    default_opts
    |> Keyword.merge(route_opts)
    |> Enum.reject(fn {_, v} -> is_nil(v) end)
  end

  defp json_response(conn, spec) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Oaskit.SpecDumper.to_json!(spec, pretty: true))
  end
end
