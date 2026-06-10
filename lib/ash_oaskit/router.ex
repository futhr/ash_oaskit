defmodule AshOaskit.Router do
  @moduledoc """
  Router macro for serving OpenAPI specs with minimal configuration.

  Works with both Phoenix Router and Plug.Router. Automatically detects the
  router type and generates appropriate routes.

  ## Spec module mode (recommended)

  Pass a spec module defined with `use AshOaskit` to serve it through
  `Oaskit.SpecController`, gaining persistent_term caching and an
  optional Redoc UI:

      defmodule MyAppWeb.Router do
        use MyAppWeb, :router

        use AshOaskit.Router,
          spec: MyAppWeb.ApiSpec,
          open_api: "/openapi",
          redoc: "/redoc"
      end

  Generates:

      GET /openapi.json   -> the spec served by Oaskit.SpecController
      GET /redoc          -> Redoc UI rendering /openapi.json

  To serve OpenAPI 3.0 and 3.1 side by side, pass `{suffix, module}`
  pairs (the first entry also serves as the default at `open_api.json`):

      use AshOaskit.Router,
        spec: [{"3.1", MyAppWeb.ApiSpecV31}, {"3.0", MyAppWeb.ApiSpecV30}],
        open_api: "/openapi"

      GET /openapi.json      -> 3.1 spec (first entry)
      GET /openapi/3.1.json  -> 3.1 spec
      GET /openapi/3.0.json  -> 3.0 spec

  ### Spec mode options

    * `:spec` - A spec module (`use AshOaskit`) or list of
      `{suffix, module}` pairs (required for this mode)
    * `:open_api` - Base path for OpenAPI endpoints (required)
    * `:redoc` - Path to serve the Redoc UI (optional)
    * `:redoc_spec_url` - Absolute URL path Redoc fetches the spec from.
      Defaults to `"\#{open_api}.json"` — set this when the router macro
      runs inside a `scope` with a path prefix, because Redoc fetches
      by absolute URL (e.g. `redoc_spec_url: "/api/openapi.json"`)
    * `:redoc_config` - Redoc configuration map (optional)
    * `:resp_headers` - Response headers map for the JSON endpoints
      (optional, e.g. CORS headers)

  ## Legacy domains mode (deprecated)

  Passing `:domains` directly is deprecated: the spec is regenerated on
  every request. Define a spec module with `use AshOaskit` and switch to
  the `:spec` option.

      use AshOaskit.Router,
        domains: [MyApp.Blog, MyApp.Accounts],
        open_api: "/docs/openapi",
        title: "My API",
        version: "1.0.0"

  ### Legacy mode options

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

    spec_mode? = is_list(opts) and Keyword.has_key?(opts, :spec)

    case {spec_mode?, is_phoenix} do
      {true, true} -> build_phoenix_spec_quoted(opts)
      {true, false} -> build_plug_spec_quoted(opts)
      {false, true} -> build_phoenix_quoted(opts)
      {false, false} -> build_plug_quoted(opts)
    end
  end

  @doc false
  @spec __spec_mode_routes__(keyword()) :: [{String.t(), keyword()}]
  def __spec_mode_routes__(opts) do
    if Keyword.has_key?(opts, :domains) do
      raise ArgumentError,
            "use AshOaskit.Router accepts either :spec or :domains, not both. " <>
              "Move the domains into your spec module (use AshOaskit, domains: [...])."
    end

    base_path = Keyword.fetch!(opts, :open_api)
    resp_headers = Keyword.get(opts, :resp_headers)

    spec_routes(Keyword.fetch!(opts, :spec), base_path, resp_headers) ++
      redoc_routes(opts, base_path)
  end

  defp spec_routes(spec_module, base_path, resp_headers) when is_atom(spec_module) do
    [{"#{base_path}.json", controller_opts(spec_module, resp_headers)}]
  end

  defp spec_routes([{_, _} | _] = versioned, base_path, resp_headers) do
    [{_, default_module} | _] = versioned

    default = {"#{base_path}.json", controller_opts(default_module, resp_headers)}

    suffixed =
      Enum.map(versioned, fn {suffix, spec_module} ->
        {"#{base_path}/#{suffix}.json", controller_opts(spec_module, resp_headers)}
      end)

    [default | suffixed]
  end

  defp spec_routes(other, _, _) do
    raise ArgumentError,
          "use AshOaskit.Router expected :spec to be a spec module or a list of " <>
            "{suffix, module} pairs, got: #{inspect(other)}"
  end

  defp redoc_routes(opts, base_path) do
    case Keyword.get(opts, :redoc) do
      nil ->
        []

      redoc_path ->
        redoc_opts =
          [redoc: Keyword.get(opts, :redoc_spec_url, "#{base_path}.json")] ++
            case Keyword.get(opts, :redoc_config) do
              nil -> []
              config -> [redoc_config: config]
            end

        [{redoc_path, redoc_opts}]
    end
  end

  defp controller_opts(spec_module, nil), do: [spec: spec_module]
  defp controller_opts(spec_module, headers), do: [spec: spec_module, resp_headers: headers]

  defp build_phoenix_spec_quoted(opts) do
    quote bind_quoted: [opts: opts] do
      require Phoenix.Router

      for {path, controller_opts} <- AshOaskit.Router.__spec_mode_routes__(opts) do
        Phoenix.Router.get(path, Oaskit.SpecController, controller_opts)
      end
    end
  end

  defp build_plug_spec_quoted(opts) do
    quote bind_quoted: [opts: opts] do
      for {path, controller_opts} <- AshOaskit.Router.__spec_mode_routes__(opts) do
        @__ash_oaskit_spec_route_opts Oaskit.SpecController.init(controller_opts)

        Plug.Router.get path do
          # credo:disable-for-next-line Credo.Check.Design.AliasUsage
          Oaskit.SpecController.call(var!(conn), @__ash_oaskit_spec_route_opts)
        end
      end
    end
  end

  defp build_phoenix_quoted(opts) do
    quote bind_quoted: [opts: opts] do
      require Phoenix.Router

      # credo:disable-for-next-line
      IO.warn(
        "use AshOaskit.Router with :domains is deprecated; define a spec module " <>
          "with `use AshOaskit, domains: [...]` and pass it as spec: MySpec " <>
          "to gain caching, Redoc, and oaskit integration",
        Macro.Env.stacktrace(__ENV__)
      )

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
      # credo:disable-for-next-line
      IO.warn(
        "use AshOaskit.Router with :domains is deprecated; define a spec module " <>
          "with `use AshOaskit, domains: [...]` and pass it as spec: MySpec " <>
          "to gain caching, Redoc, and oaskit integration",
        Macro.Env.stacktrace(__ENV__)
      )

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
