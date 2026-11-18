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
          redoc3: "/redoc"
      end

  Generates:

      GET /openapi.json   -> the spec served by Oaskit.SpecController
      GET /redoc          -> Redoc 3 UI rendering /openapi.json

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
    * `:redoc3` - Path to serve the Redoc 3 UI (optional). Oaskit loads a
      pinned Redoc 3 bundle from `https://cdn.redoc.ly` with Subresource
      Integrity, starts it from an inline module script, and sets
      `"disableTelemetry" => true` unless `:redoc_config` defines that key.
      A Content Security Policy on this route must allow that origin and
      `'unsafe-inline'` in `script-src`.
    * `:redoc` - Path to serve the Redoc 2 UI (optional). May be combined
      with `:redoc3` on a different path.
    * `:redoc_spec_url` - Absolute URL path Redoc fetches the spec from.
      Defaults to `"\#{open_api}.json"` — set this when the router macro
      runs inside a `scope` with a path prefix, because Redoc fetches
      by absolute URL (e.g. `redoc_spec_url: "/api/openapi.json"`)
    * `:redoc_config` - Redoc configuration map passed unchanged to the
      served UI (optional). Redoc 2 and Redoc 3 accept different options;
      follow the [Redoc 3 migration
      guide](https://redocly.com/docs/redoc/v3.x/config-migration) when
      moving a route from `:redoc` to `:redoc3`.
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

  # `:redoc3` and `:redoc` are the `Oaskit.SpecController` options for the
  # Redoc 3 and Redoc 2 pages.
  defp redoc_routes(opts, base_path) do
    spec_url = Keyword.get(opts, :redoc_spec_url, "#{base_path}.json")

    config_opts =
      case Keyword.get(opts, :redoc_config) do
        nil -> []
        config -> [redoc_config: config]
      end

    for ui <- [:redoc3, :redoc], path = Keyword.get(opts, ui) do
      {path, [{ui, spec_url} | config_opts]}
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

      unless Application.compile_env(
               :ash_oaskit,
               :suppress_router_deprecation_warnings,
               false
             ) do
        # credo:disable-for-next-line
        IO.warn(
          "use AshOaskit.Router with :domains is deprecated; define a spec module " <>
            "with `use AshOaskit, domains: [...]` and pass it as spec: MySpec " <>
            "to gain caching, Redoc, and oaskit integration",
          Macro.Env.stacktrace(__ENV__)
        )
      end

      base_path = Keyword.fetch!(opts, :open_api)
      openapi_versions = Keyword.get(opts, :openapi_versions, ["3.0", "3.1"])
      default_version = Keyword.get(opts, :default_version, "3.1")
      formats = Keyword.get(opts, :formats, [:json])

      config =
        opts
        |> Map.new()
        |> Map.put_new(:title, "API")
        |> Map.put_new(:version, "1.0.0")
        |> Map.put_new(:servers, [])
        |> Map.put_new(:spec_builder, AshOaskit.SpecBuilder.Default)

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
      unless Application.compile_env(
               :ash_oaskit,
               :suppress_router_deprecation_warnings,
               false
             ) do
        # credo:disable-for-next-line
        IO.warn(
          "use AshOaskit.Router with :domains is deprecated; define a spec module " <>
            "with `use AshOaskit, domains: [...]` and pass it as spec: MySpec " <>
            "to gain caching, Redoc, and oaskit integration",
          Macro.Env.stacktrace(__ENV__)
        )
      end

      base_path = Keyword.fetch!(opts, :open_api)
      openapi_versions = Keyword.get(opts, :openapi_versions, ["3.0", "3.1"])
      default_version = Keyword.get(opts, :default_version, "3.1")
      formats = Keyword.get(opts, :formats, [:json])

      @__ash_oaskit_config opts
                           |> Map.new()
                           |> Map.put_new(:title, "API")
                           |> Map.put_new(:version, "1.0.0")
                           |> Map.put_new(:servers, [])
                           |> Map.put_new(:spec_builder, AshOaskit.SpecBuilder.Default)

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
