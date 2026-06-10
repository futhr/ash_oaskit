defmodule AshOaskit.Spec do
  @moduledoc """
  Runtime support and behaviour for spec modules defined with `use AshOaskit`.

  A spec module turns a set of Ash domains into a long-lived OpenAPI
  spec that integrates with the whole `Oaskit` toolchain:

      defmodule MyAppWeb.ApiSpec do
        use AshOaskit,
          domains: [MyApp.Blog],
          title: "My API",
          api_version: "1.0.0"
      end

  `use AshOaskit` implements the `Oaskit` behaviour, so the module
  gains, with no extra code:

  - **Caching** — the generated spec is stored in `:persistent_term`
    and the Ash domain walk runs once, not per request
  - **Serving** — `Oaskit.SpecController` can serve it as JSON or
    render a Redoc UI
  - **Request validation** — `Oaskit.Plugs.SpecProvider` +
    `Oaskit.Plugs.ValidateRequest` work for hand-written Phoenix
    controllers documented alongside the Ash routes
  - **Export** — `mix openapi.dump MyAppWeb.ApiSpec`

  ## Options

  | Option | Type | Default | Description |
  |--------|------|---------|-------------|
  | `:domains` | `[module()]` | **required** | Ash domains to include |
  | `:version` | `"3.0"` or `"3.1"` | `"3.1"` | OpenAPI version |
  | `:title` | `String.t()` | `"API"` | `info.title` |
  | `:api_version` | `String.t()` | `"1.0.0"` | `info.version` |
  | `:description` | `String.t()` | `nil` | `info.description` |
  | `:terms_of_service` | `String.t()` | `nil` | `info.termsOfService` |
  | `:contact` | `map()` | `nil` | `info.contact` |
  | `:license` | `map()` | `nil` | `info.license` |
  | `:servers` | `[String.t() \\| map()]` | `[]` | `servers` array |
  | `:security` | `[map()]` | `nil` | Top-level security requirements |
  | `:external_docs` | `map()` | `nil` | External documentation object |
  | `:router` | `module()` | `nil` | Phoenix router for controller introspection |
  | `:modify_open_api` | function or MFA | `nil` | Post-generation hook (see `AshOaskit.SpecModifier`) |
  | `:spec_builder` | `module()` | `nil` | `AshOaskit.SpecBuilder` implementation |
  | `:cache` | `boolean()` | `true` | Cache the generated spec |

  ## Customizing the spec

  Override `c:modify_spec/1` to post-process the generated map (the
  result is what gets cached):

      defmodule MyAppWeb.ApiSpec do
        use AshOaskit, domains: [MyApp.Blog]

        @impl AshOaskit.Spec
        def modify_spec(spec) do
          put_in(spec, ["components", "securitySchemes"], %{
            "bearerAuth" => %{"type" => "http", "scheme" => "bearer"}
          })
        end
      end

  All `Oaskit` callbacks remain overridable too — `cache/1` to swap the
  cache backend, `cache_variant/0` to key the cache (e.g. per tenant),
  and `jsv_opts/0` for validation tuning.

  ## Caching

  The spec is generated once and cached in `:persistent_term` under
  `{:ash_oaskit_cache, module, cache_variant}`. Two switches disable it:

  - per module: `use AshOaskit, cache: false, ...`
  - globally at runtime: `config :ash_oaskit, cache_specs: false`
    (recommended in `dev.exs` so code reloads regenerate the spec)

  ## Dual-version output

  An Oaskit spec module is one spec by contract. To serve OpenAPI 3.0
  and 3.1 side by side, define two spec modules with different
  `:version` options.
  """

  @typedoc "Compile-time options accepted by `use AshOaskit`."
  @type option ::
          {:domains, [module()]}
          | {:version, String.t()}
          | {:title, String.t()}
          | {:api_version, String.t()}
          | {:description, String.t()}
          | {:terms_of_service, String.t()}
          | {:contact, map()}
          | {:license, map()}
          | {:servers, [String.t() | map()]}
          | {:security, [map()]}
          | {:external_docs, map()}
          | {:router, module()}
          | {:modify_open_api, function() | {module(), atom(), [term()]}}
          | {:spec_builder, module()}
          | {:cache, boolean()}

  @doc """
  Invoked after the spec is generated, before it is cached.

  Override to add security schemes, vendor extensions, or any other
  post-processing. Receives and must return the spec map.
  """
  @callback modify_spec(spec :: map()) :: map()

  @known_options ~w(domains version title api_version description terms_of_service
                    contact license servers security external_docs router
                    modify_open_api spec_builder cache)a

  @valid_versions ~w(3.0 3.1)

  @doc """
  Validates `use AshOaskit` options at compile time.

  Raises `ArgumentError` for unknown options, a missing or empty
  `:domains` list, or an unsupported `:version`.

  ## Examples

      iex> AshOaskit.Spec.validate_opts!([domains: [MyApp.Blog]], MyModule)
      [domains: [MyApp.Blog]]
  """
  @spec validate_opts!([option()], module()) :: [option()]
  def validate_opts!(opts, module) do
    unless Keyword.keyword?(opts) do
      raise ArgumentError,
            "use AshOaskit expects a keyword list of options, got: #{inspect(opts)}"
    end

    case Keyword.keys(opts) -- @known_options do
      [] ->
        :ok

      unknown ->
        raise ArgumentError, """
        use AshOaskit in #{inspect(module)} got unknown option(s): \
        #{inspect(unknown)}. Known options: #{inspect(@known_options)}\
        """
    end

    validate_domains!(Keyword.get(opts, :domains), module)
    validate_version!(Keyword.get(opts, :version, "3.1"), module)

    opts
  end

  @doc """
  Builds (and caches) the OpenAPI spec for a spec module.

  Used by the `spec/0` callback that `use AshOaskit` defines. The cache
  is keyed on the module and its `cache_variant/0`, and can be disabled
  per module (`cache: false`) or globally
  (`config :ash_oaskit, cache_specs: false`).

  ## Parameters

    - `module` - The spec module (`use AshOaskit`)
    - `opts` - The validated `use AshOaskit` options

  ## Returns

  The OpenAPI specification map.
  """
  @spec build(module(), [option()]) :: map()
  def build(module, opts) do
    if cache?(opts) do
      cache_key = {:ash_oaskit_cache, module, module.cache_variant()}
      Oaskit.cached(module, cache_key, fn -> generate(module, opts) end)
    else
      generate(module, opts)
    end
  end

  defp generate(module, opts) do
    opts
    |> generate_spec()
    |> module.modify_spec()
  end

  # With a custom spec builder, go through the legacy SpecBuilder
  # contract (where :version means the API version); otherwise call the
  # generator directly with full option fidelity
  defp generate_spec(opts) do
    openapi_version = Keyword.get(opts, :version, "3.1")

    case Keyword.get(opts, :spec_builder) do
      nil ->
        opts
        |> Keyword.take(@known_options -- [:spec_builder, :cache])
        |> AshOaskit.OpenApi.spec()

      builder ->
        builder_opts =
          opts
          |> Keyword.drop([:spec_builder, :cache, :version, :api_version])
          |> Keyword.put(:version, Keyword.get(opts, :api_version, "1.0.0"))
          |> Map.new()

        builder.spec(openapi_version, builder_opts)
    end
  end

  defp cache?(opts) do
    Keyword.get(opts, :cache, true) and
      Application.get_env(:ash_oaskit, :cache_specs, true)
  end

  defp validate_domains!(domains, module) do
    unless is_list(domains) and domains != [] and Enum.all?(domains, &is_atom/1) do
      raise ArgumentError, """
      use AshOaskit in #{inspect(module)} requires a non-empty :domains \
      list of Ash domain modules, got: #{inspect(domains)}\
      """
    end
  end

  defp validate_version!(version, module) do
    unless version in @valid_versions do
      raise ArgumentError, """
      use AshOaskit in #{inspect(module)} got an unsupported :version \
      #{inspect(version)}. Supported versions: #{inspect(@valid_versions)}\
      """
    end
  end
end
