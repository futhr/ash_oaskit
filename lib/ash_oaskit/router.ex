defmodule AshOaskit.Router do
  @moduledoc """
  Router macro for serving OpenAPI specs with minimal configuration.

  This macro provides a simple way to add OpenAPI specification endpoints to your
  Phoenix or Plug router. It automatically generates routes for both OpenAPI 3.0
  and 3.1 versions.

  ## Usage with Phoenix Router

  Add to your Phoenix router inside a scope:

      defmodule MyAppWeb.Router do
        use MyAppWeb, :router

        scope "/api" do
          pipe_through :api

          use AshOaskit.Router,
            domains: [MyApp.Blog, MyApp.Accounts],
            open_api: "/docs/openapi",
            title: "My API",
            version: "1.0.0"
        end
      end

  ## Usage with Plug.Router

      defmodule MyApp.Router do
        use Plug.Router

        plug :match
        plug :dispatch

        use AshOaskit.Router,
          domains: [MyApp.Blog],
          open_api: "/openapi",
          title: "My API"
      end

  ## Options

    * `:domains` - List of Ash domains to include (required)
    * `:open_api` - Base path for OpenAPI endpoints (required)
    * `:title` - API title (default: "API")
    * `:version` - API version string (default: "1.0.0")
    * `:description` - API description (optional)
    * `:openapi_versions` - List of OpenAPI versions to serve (default: ["3.0", "3.1"])
    * `:default_version` - Default OpenAPI version (default: "3.1")
    * `:formats` - Output formats (default: [:json])
    * `:servers` - List of server URLs or server objects (optional)
    * `:router` - Phoenix router module for controller introspection (optional)
    * `:modify_open_api` - Post-processing function for spec customization (optional)
    * `:spec_builder` - Custom SpecBuilder module (default: `AshOaskit.SpecBuilder.Default`)

  ## Generated Routes

  With `open_api: "/openapi"` and default options, generates:

      GET /openapi.json       -> Default version (3.1) spec
      GET /openapi/3.0.json   -> OpenAPI 3.0 spec
      GET /openapi/3.1.json   -> OpenAPI 3.1 spec

  With `formats: [:json, :yaml]`, also generates:

      GET /openapi.yaml       -> Default version (3.1) spec in YAML
      GET /openapi/3.0.yaml   -> OpenAPI 3.0 spec in YAML
      GET /openapi/3.1.yaml   -> OpenAPI 3.1 spec in YAML

  ## Examples

  ### Minimal Setup

      use AshOaskit.Router,
        domains: [MyApp.Blog],
        open_api: "/openapi",
        title: "Blog API"

  ### With Phoenix Controller Introspection

  Include routes from Phoenix controllers implementing `AshOaskit.OpenApiController`:

      use AshOaskit.Router,
        domains: [MyApp.Blog],
        router: MyAppWeb.Router,  # Pass the router for controller introspection
        open_api: "/openapi",
        title: "Blog API"

  ### With Custom SpecBuilder

  For customization (security schemes, feature flags, domain filtering):

      use AshOaskit.Router,
        spec_builder: MyApp.OpenApi.SpecBuilder,
        domains: [MyApp.Blog],
        open_api: "/openapi",
        title: "Blog API"

  Where `MyApp.OpenApi.SpecBuilder` implements `AshOaskit.SpecBuilder`:

      defmodule MyApp.OpenApi.SpecBuilder do
        @behaviour AshOaskit.SpecBuilder

        @impl true
        def spec(openapi_version, opts) do
          AshOaskit.spec(
            domains: opts[:domains],
            version: openapi_version,
            title: opts[:title],
            router: opts[:router]  # Pass through router option
          )
          |> add_security_schemes()
        end

        defp add_security_schemes(spec) do
          put_in(spec, ["components", "securitySchemes"], %{
            "bearerAuth" => %{"type" => "http", "scheme" => "bearer"}
          })
        end
      end

  ### With Post-Processing Hook

  Modify the generated spec before serving:

      use AshOaskit.Router,
        domains: [MyApp.Blog],
        open_api: "/openapi",
        title: "Blog API",
        modify_open_api: &MyApp.OpenApi.add_custom_fields/1

  ### Full Configuration

      use AshOaskit.Router,
        domains: [MyApp.Blog, MyApp.Accounts],
        open_api: "/api/docs/openapi",
        title: "My API",
        version: "2.0.0",
        description: "API for blog and user management",
        openapi_versions: ["3.0", "3.1"],
        default_version: "3.1",
        formats: [:json, :yaml],
        router: MyAppWeb.Router,
        servers: [
          %{url: "https://api.example.com", description: "Production"},
          %{url: "http://localhost:4000", description: "Development"}
        ]

  ### Single OpenAPI Version

      use AshOaskit.Router,
        domains: [MyApp.Blog],
        open_api: "/openapi",
        title: "Blog API",
        openapi_versions: ["3.1"],
        default_version: "3.1"

  ## Alternative: Programmatic API (Advanced)

  For complete control over routing and serving, use the programmatic API:

      spec = AshOaskit.spec(domains: [MyApp.Blog], version: "3.1")

  This is an escape hatch for edge cases not covered by the Router macro.
  """

  @doc false
  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      alias AshOaskit.Router

      # Extract options - these are now evaluated at compile time in the caller's context
      domains = Keyword.fetch!(opts, :domains)
      base_path = Keyword.fetch!(opts, :open_api)
      title = Keyword.get(opts, :title, "API")
      version = Keyword.get(opts, :version, "1.0.0")
      description = Keyword.get(opts, :description)
      openapi_versions = Keyword.get(opts, :openapi_versions, ["3.0", "3.1"])
      default_version = Keyword.get(opts, :default_version, "3.1")
      formats = Keyword.get(opts, :formats, [:json])
      servers = Keyword.get(opts, :servers, [])
      router = Keyword.get(opts, :router)
      modify_open_api = Keyword.get(opts, :modify_open_api)
      spec_builder = Keyword.get(opts, :spec_builder, AshOaskit.SpecBuilder.Default)

      # Store config at module attribute level for route handlers
      @ash_oaskit_domains domains
      @ash_oaskit_title title
      @ash_oaskit_version version
      @ash_oaskit_description description
      @ash_oaskit_servers servers
      @ash_oaskit_router router
      @ash_oaskit_modify_open_api modify_open_api
      @ash_oaskit_spec_builder spec_builder

      # Generate routes for each format
      for format <- formats do
        ext = Atom.to_string(format)

        # Default route (e.g., /openapi.json)
        # Using Plug.Router.get/2 directly
        Plug.Router.get "#{base_path}.#{ext}" do
          config = %{
            domains: @ash_oaskit_domains,
            title: @ash_oaskit_title,
            version: @ash_oaskit_version,
            description: @ash_oaskit_description,
            servers: @ash_oaskit_servers,
            router: @ash_oaskit_router,
            modify_open_api: @ash_oaskit_modify_open_api,
            spec_builder: @ash_oaskit_spec_builder,
            openapi_version: unquote(default_version),
            format: unquote(format)
          }

          conn = Plug.Conn.put_private(var!(conn), :ash_oaskit, config)
          Router.Plug.call(conn, [])
        end

        # Version-specific routes (e.g., /openapi/3.0.json, /openapi/3.1.json)
        for openapi_version <- openapi_versions do
          Plug.Router.get "#{base_path}/#{openapi_version}.#{ext}" do
            config = %{
              domains: @ash_oaskit_domains,
              title: @ash_oaskit_title,
              version: @ash_oaskit_version,
              description: @ash_oaskit_description,
              servers: @ash_oaskit_servers,
              router: @ash_oaskit_router,
              modify_open_api: @ash_oaskit_modify_open_api,
              spec_builder: @ash_oaskit_spec_builder,
              openapi_version: unquote(openapi_version),
              format: unquote(format)
            }

            conn = Plug.Conn.put_private(var!(conn), :ash_oaskit, config)
            Router.Plug.call(conn, [])
          end
        end
      end
    end
  end
end
