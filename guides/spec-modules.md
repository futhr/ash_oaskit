# Spec Modules

A spec module turns your Ash domains into a long-lived OpenAPI spec that
plugs into the whole [oaskit](https://hexdocs.pm/oaskit) toolchain. It is
the recommended way to use AshOaskit.

## Defining a spec module

```elixir
defmodule MyAppWeb.ApiSpec do
  use AshOaskit,
    domains: [MyApp.Blog, MyApp.Accounts],
    title: "My API",
    api_version: "1.0.0"
end
```

`use AshOaskit` implements the `Oaskit` behaviour: `MyAppWeb.ApiSpec.spec/0`
returns the generated spec map, cached in `:persistent_term` so the Ash
domain walk runs once — not on every request.

All options:

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
| `:servers` | list | `[]` | `servers` array |
| `:security` | `[map()]` | `nil` | Top-level security requirements |
| `:external_docs` | `map()` | `nil` | External documentation object |
| `:router` | `module()` | `nil` | Phoenix router for controller introspection |
| `:modify_open_api` | function/MFA | `nil` | Post-generation hook |
| `:spec_builder` | `module()` | `nil` | `AshOaskit.SpecBuilder` implementation |
| `:cache` | `boolean()` | `true` | Cache the generated spec |

## Serving the spec

Through the router macro (Phoenix or Plug.Router):

```elixir
use AshOaskit.Router,
  spec: MyAppWeb.ApiSpec,
  open_api: "/openapi",
  redoc: "/redoc"
```

This serves `GET /openapi.json` (append `?pretty=1` for readable output)
and a [Redoc](https://redocly.com/redoc) UI at `GET /redoc`.

Or wire `Oaskit.SpecController` directly:

```elixir
get "/openapi.json", Oaskit.SpecController, spec: MyAppWeb.ApiSpec
get "/redoc", Oaskit.SpecController, redoc: "/openapi.json"
```

> #### Scoped routers {: .info}
>
> Redoc fetches the spec by absolute URL. If the router macro runs inside
> a `scope "/api"`, pass `redoc_spec_url: "/api/openapi.json"`.

## Customizing the generated spec

Override `modify_spec/1` — it runs after generation and its result is
what gets cached:

```elixir
defmodule MyAppWeb.ApiSpec do
  use AshOaskit, domains: [MyApp.Blog]

  @impl AshOaskit.Spec
  def modify_spec(spec) do
    spec
    |> put_in(["components", "securitySchemes"], %{
      "bearerAuth" => %{"type" => "http", "scheme" => "bearer"}
    })
    |> Map.put("security", [%{"bearerAuth" => []}])
  end
end
```

The `Oaskit` callbacks are also overridable:

- `cache/1` — swap `:persistent_term` for another cache backend
- `cache_variant/0` — key the cache, e.g. per tenant
- `jsv_opts/0` — JSV validation options for request validation

## Caching in development

`:persistent_term` survives code reloads, so a stale spec can linger in
dev. Disable caching there:

```elixir
# config/dev.exs
config :ash_oaskit, cache_specs: false
```

The switch is read at runtime on every call, so no recompilation is
needed. A single module can also opt out with `use AshOaskit, cache: false`.

## Dual-version output

An Oaskit spec module is one spec by contract. To serve OpenAPI 3.0 and
3.1 side by side, define two modules and register both:

```elixir
defmodule MyAppWeb.ApiSpecV31 do
  use AshOaskit, domains: [MyApp.Blog], version: "3.1"
end

defmodule MyAppWeb.ApiSpecV30 do
  use AshOaskit, domains: [MyApp.Blog], version: "3.0"
end

use AshOaskit.Router,
  spec: [{"3.1", MyAppWeb.ApiSpecV31}, {"3.0", MyAppWeb.ApiSpecV30}],
  open_api: "/openapi"

# GET /openapi.json     -> 3.1 (first entry)
# GET /openapi/3.1.json -> 3.1
# GET /openapi/3.0.json -> 3.0
```

## Exporting the spec

```sh
mix openapi.dump MyAppWeb.ApiSpec --pretty -o priv/static/openapi.json
```

oaskit's dump task uses the exact spec your application serves —
including `modify_spec/1` post-processing.
