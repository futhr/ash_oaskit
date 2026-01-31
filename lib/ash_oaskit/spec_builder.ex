defmodule AshOaskit.SpecBuilder do
  @moduledoc """
  Behaviour for customizing OpenAPI spec generation.

  Implement this behaviour to add custom security schemes, feature flags,
  domain filtering, or any post-processing to generated specs.

  ## Example

      defmodule MyApp.OpenApi.SpecBuilder do
        @behaviour AshOaskit.SpecBuilder

        @impl true
        def spec(openapi_version, opts) do
          AshOaskit.spec(
            domains: opts[:domains],
            version: openapi_version,
            title: opts[:title],
            api_version: opts[:version]
          )
          |> add_security_schemes()
          |> add_feature_flags()
        end

        defp add_security_schemes(spec) do
          put_in(spec, ["components", "securitySchemes"], %{
            "bearerAuth" => %{
              "type" => "http",
              "scheme" => "bearer",
              "bearerFormat" => "JWT"
            }
          })
        end

        defp add_feature_flags(spec) do
          Map.put(spec, "x-features", %{"beta" => true})
        end
      end

  ## Usage with Router

      use AshOaskit.Router,
        spec_builder: MyApp.OpenApi.SpecBuilder,
        open_api: "/openapi",
        title: "My API",
        domains: [MyApp.Blog]  # Passed to spec_builder
  """

  @doc """
  Generate an OpenAPI spec for the given version and options.

  ## Parameters

    * `openapi_version` - The OpenAPI version ("3.0" or "3.1")
    * `opts` - Options map containing:
      * `:domains` - List of Ash domains
      * `:title` - API title
      * `:version` - API version string
      * `:description` - API description (optional)
      * `:servers` - List of server URLs (optional)
      * `:format` - Output format (:json or :yaml)
      * Plus any custom options passed to the router

  ## Returns

  A map representing the OpenAPI specification.
  """
  @callback spec(openapi_version :: String.t(), opts :: map()) :: map()
end
