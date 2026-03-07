defmodule AshOaskit.Router do
  @moduledoc """
  Router macro for serving OpenAPI specs with minimal configuration.

  Works with both Phoenix Router and Plug.Router. Automatically detects the
  router type and generates appropriate routes.

  ## Usage with Phoenix Router

      defmodule MyAppWeb.Router do
        use MyAppWeb, :router

        use AshOaskit.Router,
          domains: [MyApp.Blog, MyApp.Accounts],
          open_api: "/docs/openapi",
          title: "My API",
          version: "1.0.0"
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
  """

  @doc false
  defmacro __using__(opts) do
    # Both Phoenix Router and Plug.Router routes must be generated inline
    # (not via @before_compile) because:
    # - Plug.Router: routes after catch-all `match _` are unreachable
    # - Phoenix Router: routes registered after Phoenix's own @before_compile
    #   are excluded from the routing table
    #
    # Detection happens at macro expansion time via __CALLER__.
    is_phoenix =
      Enum.any?(__CALLER__.macros, fn {mod, _} -> mod == Phoenix.Router end)

    if is_phoenix do
      build_phoenix_quoted(opts)
    else
      build_plug_quoted(opts)
    end
  end

  defp build_phoenix_quoted(opts) do
    quote bind_quoted: [opts: opts] do
      require Phoenix.Router

      base_path = Keyword.fetch!(opts, :open_api)
      openapi_versions = Keyword.get(opts, :openapi_versions, ["3.0", "3.1"])
      default_version = Keyword.get(opts, :default_version, "3.1")
      formats = Keyword.get(opts, :formats, [:json])

      config = %{
        domains: Keyword.fetch!(opts, :domains),
        title: Keyword.get(opts, :title, "API"),
        version: Keyword.get(opts, :version, "1.0.0"),
        description: Keyword.get(opts, :description),
        servers: Keyword.get(opts, :servers, []),
        router: Keyword.get(opts, :router),
        modify_open_api: Keyword.get(opts, :modify_open_api),
        spec_builder: Keyword.get(opts, :spec_builder, AshOaskit.SpecBuilder.Default)
      }

      for format <- formats do
        ext = Atom.to_string(format)

        Phoenix.Router.get(
          "#{base_path}.#{ext}",
          AshOaskit.Router.Plug,
          Map.merge(config, %{openapi_version: default_version, format: format})
        )

        for openapi_version <- openapi_versions do
          Phoenix.Router.get(
            "#{base_path}/#{openapi_version}.#{ext}",
            AshOaskit.Router.Plug,
            Map.merge(config, %{openapi_version: openapi_version, format: format})
          )
        end
      end
    end
  end

  defp build_plug_quoted(opts) do
    quote bind_quoted: [opts: opts] do
      base_path = Keyword.fetch!(opts, :open_api)
      openapi_versions = Keyword.get(opts, :openapi_versions, ["3.0", "3.1"])
      default_version = Keyword.get(opts, :default_version, "3.1")
      formats = Keyword.get(opts, :formats, [:json])

      # credo:disable-for-next-line Credo.Check.Design.DuplicatedCode
      @__ash_oaskit_config %{
        domains: Keyword.fetch!(opts, :domains),
        title: Keyword.get(opts, :title, "API"),
        version: Keyword.get(opts, :version, "1.0.0"),
        description: Keyword.get(opts, :description),
        servers: Keyword.get(opts, :servers, []),
        router: Keyword.get(opts, :router),
        modify_open_api: Keyword.get(opts, :modify_open_api),
        spec_builder: Keyword.get(opts, :spec_builder, AshOaskit.SpecBuilder.Default)
      }

      for format <- formats do
        ext = Atom.to_string(format)

        Plug.Router.get "#{base_path}.#{ext}" do
          config =
            Map.merge(@__ash_oaskit_config, %{
              openapi_version: unquote(default_version),
              format: unquote(format)
            })

          conn = Plug.Conn.put_private(var!(conn), :ash_oaskit, config)
          # credo:disable-for-next-line Credo.Check.Design.AliasUsage
          AshOaskit.Router.Plug.call(conn, [])
        end

        for openapi_version <- openapi_versions do
          Plug.Router.get "#{base_path}/#{openapi_version}.#{ext}" do
            config =
              Map.merge(@__ash_oaskit_config, %{
                openapi_version: unquote(openapi_version),
                format: unquote(format)
              })

            conn = Plug.Conn.put_private(var!(conn), :ash_oaskit, config)
            # credo:disable-for-next-line Credo.Check.Design.AliasUsage
            AshOaskit.Router.Plug.call(conn, [])
          end
        end
      end
    end
  end
end
