# AshOaskit

[![Hex.pm](https://img.shields.io/hexpm/v/ash_oaskit.svg)](https://hex.pm/packages/ash_oaskit)
[![Docs](https://img.shields.io/badge/docs-hexdocs-blue.svg)](https://hexdocs.pm/ash_oaskit)
[![CI](https://github.com/futhr/ash_oaskit/actions/workflows/ci.yml/badge.svg)](https://github.com/futhr/ash_oaskit/actions/workflows/ci.yml)
[![Coverage](https://codecov.io/gh/futhr/ash_oaskit/branch/main/graph/badge.svg)](https://codecov.io/gh/futhr/ash_oaskit)
[![License](https://img.shields.io/github/license/futhr/ash_oaskit.svg)](LICENSE.md)

**Dual-version OpenAPI specification generator for [Ash Framework](https://ash-hq.org/)**

[Installation](#installation) |
[Quick Start](#quick-start) |
[Configuration](#configuration) |
[API Reference](#api-reference) |
[Phoenix Integration](#phoenix-integration)

---

## Overview

AshOaskit generates OpenAPI specifications from your Ash domains, supporting both 3.0 and 3.1 versions.

## Background

This project was created to address the need for OpenAPI 3.1 specification support in the Ash ecosystem. [AshJsonApi](https://hexdocs.pm/ash_json_api) provides excellent JSON:API compliance and served as significant inspiration for this library's approach to introspecting Ash resources. However, it generates OpenAPI 3.0 specifications.

OpenAPI 3.1 brings full alignment with JSON Schema 2020-12, enabling:

- Type arrays for nullable fields (`["string", "null"]` instead of `nullable: true`)
- Better validation tooling compatibility
- Improved schema reuse patterns

This library complements AshJsonApi by reading its route configurations and generating modern OpenAPI specifications while maintaining backwards compatibility with 3.0 for teams that need it.

AshOaskit is built on top of [Oaskit](https://hexdocs.pm/oaskit), a toolkit for building and manipulating OpenAPI specifications in Elixir. All generated specs are normalized and validated through Oaskit's pipeline, and JSON output uses Oaskit's `SpecDumper` for proper key ordering.

## Features

AshOaskit provides:

- **Automatic Schema Extraction** - Derives JSON Schema from Ash resource attributes
- **AshJsonApi Integration** - Builds paths from configured routes
- **Dual Version Support** - Generate 3.0 or 3.1 specs from the same codebase
- **Spec Validation** - Validate generated specs against the OpenAPI schema via Oaskit
- **Phoenix Controller** - Serve specs directly from your application
- **CLI Generation** - Generate static spec files for documentation

## Feature Comparison

| Feature | OpenAPI 3.0 | OpenAPI 3.1 |
|---------|-------------|-------------|
| Nullable Types | `nullable: true` | `type: ["string", "null"]` |
| JSON Schema | Draft 04 subset | Draft 2020-12 |
| Tool Support | Wider compatibility | Modern validation |

## Installation

Add `ash_oaskit` to your dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ash_oaskit, "~> 0.1.1"},
    # Optional: For YAML output
    {:ymlr, "~> 5.0", optional: true}
  ]
end
```

## Quick Start

### Define a Spec Module (Recommended)

```elixir
defmodule MyAppWeb.ApiSpec do
  use AshOaskit,
    domains: [MyApp.Blog],
    title: "My API",
    api_version: "1.0.0"
end
```

Serve it (with a [Redoc](https://redocly.com/redoc) UI) from your
Phoenix or Plug router:

```elixir
use AshOaskit.Router,
  spec: MyAppWeb.ApiSpec,
  open_api: "/openapi",
  redoc: "/redoc"
```

The spec module implements the [oaskit](https://hexdocs.pm/oaskit)
behaviour: the generated spec is cached in `:persistent_term`, served by
`Oaskit.SpecController`, exportable with `mix openapi.dump
MyAppWeb.ApiSpec`, and usable with `Oaskit.Plugs.SpecProvider` for
request validation of hand-written controllers. See the
[Spec Modules guide](guides/spec-modules.md).

> #### Development {: .tip}
>
> Add `config :ash_oaskit, cache_specs: false` to `config/dev.exs` so
> code reloads regenerate the spec.

### Generate a Spec Programmatically

```elixir
# OpenAPI 3.1 (default)
spec = AshOaskit.spec(domains: [MyApp.Blog], title: "My API")
#=> %{"openapi" => "3.1.0", "info" => %{"title" => "My API", ...}, ...}

# OpenAPI 3.0
spec = AshOaskit.spec_30(domains: [MyApp.Blog])
#=> %{"openapi" => "3.0.3", ...}
```

### CLI Generation

```bash
# Export a spec module (preferred — uses the exact spec your app serves)
mix openapi.dump MyAppWeb.ApiSpec --pretty -o openapi.json

# Generate without a spec module
mix ash_oaskit.generate -d MyApp.Blog -o openapi.json

# Generate OpenAPI 3.0 spec
mix ash_oaskit.generate -d MyApp.Blog -v 3.0 -o openapi-3.0.json

# Generate YAML format (requires ymlr)
mix ash_oaskit.generate -d MyApp.Blog -f yaml -o openapi.yaml
```

### Field Visibility

Specs include only fields marked `public? true` — the same set
AshJsonApi serializes:

```elixir
attributes do
  uuid_primary_key :id

  attribute :title, :string do
    public? true
  end

  # Not public: never appears in the generated spec
  attribute :internal_notes, :string
end
```

## Configuration

### Application Config

```elixir
config :ash_oaskit,
  version: "3.1",           # Default OpenAPI version
  title: "My API",          # Default API title
  api_version: "1.0.0"      # Default API version
```

### Spec Options

| Option | Type | Description |
|--------|------|-------------|
| `:domains` | `[module()]` | **Required.** Ash domains to include |
| `:version` | `String.t()` | OpenAPI version: `"3.0"` or `"3.1"` |
| `:title` | `String.t()` | API title for info section |
| `:api_version` | `String.t()` | API version string |
| `:description` | `String.t()` | API description |
| `:servers` | `[map()]` | Server URLs or server objects |
| `:contact` | `map()` | Contact information |
| `:license` | `map()` | License information |
| `:terms_of_service` | `String.t()` | Terms of service URL |
| `:security` | `[map()]` | Security requirements |

## API Reference

### Core Functions

```elixir
# Generate spec with options
AshOaskit.spec(domains: [Domain], title: "API", api_version: "1.0")

# Version-specific shortcuts
AshOaskit.spec_30(domains: [Domain])  # Force 3.0
AshOaskit.spec_31(domains: [Domain])  # Force 3.1
```

### Spec Validation

Generated specs can be validated against the OpenAPI schema:

```elixir
spec = AshOaskit.spec(domains: [MyApp.Blog])

# Returns {:ok, %Oaskit.Spec.OpenAPI{}} or {:error, reason}
{:ok, validated} = AshOaskit.validate(spec)

# Raises on invalid specs
validated = AshOaskit.validate!(spec)
```

### Type Mapping

| Ash Type | JSON Schema | Format |
|----------|-------------|--------|
| `:string`, `:ci_string`, `:atom`, `:module` | `string` | - |
| `:integer` | `integer` | - |
| `:float` | `number` | `float` |
| `:decimal` | `number` | `double` |
| `:boolean` | `boolean` | - |
| `:date` | `string` | `date` |
| `:time`, `:time_usec` | `string` | `time` |
| `:datetime`, `:utc_datetime`, `:utc_datetime_usec`, `:naive_datetime` | `string` | `date-time` |
| `:duration` | `string` | `duration` |
| `:uuid`, `:uuid_v7` | `string` | `uuid` |
| `:binary` | `string` | `binary` |
| `:url_encoded_binary`, `Ash.Type.File` | `string` | `byte` |
| `:map`, `:keyword`, `:tuple` | `object` | - |
| `:vector` | `array` of `number` | - |
| `:term`, `:function` | `{}` (any) | - |
| `{:array, type}` | `array` | items: nested |
| `Ash.Type.Enum` implementors | `string` + `enum` | from `values/0` |
| `Ash.Type.NewType` wrappers | (subtype schema) | via `subtype_of/0` |

See `AshOaskit.TypeMapper` for unions, structs, embedded resources, and
custom types with a `json_schema/1` callback.

### Constraint Mapping

| Ash Constraint | JSON Schema |
|----------------|-------------|
| `:min_length` | `minLength` |
| `:max_length` | `maxLength` |
| `:min` | `minimum` |
| `:max` | `maximum` |
| `:match` (Regex) | `pattern` |
| `:one_of` | `enum` |

## Router Integration

Works in both Phoenix Router and Plug.Router — the macro detects the
router type:

```elixir
defmodule MyAppWeb.Router do
  use MyAppWeb, :router

  use AshOaskit.Router,
    spec: MyAppWeb.ApiSpec,
    open_api: "/openapi",
    redoc: "/redoc"

  # Your other routes, pipelines, scopes, etc.
end
```

Generates:

- `GET /openapi.json` — the spec, served from cache (`?pretty=1` to format)
- `GET /redoc` — Redoc UI

Serve OpenAPI 3.0 and 3.1 side by side with two spec modules:

```elixir
use AshOaskit.Router,
  spec: [{"3.1", MyAppWeb.ApiSpecV31}, {"3.0", MyAppWeb.ApiSpecV30}],
  open_api: "/openapi"

# GET /openapi.json     -> 3.1 (first entry)
# GET /openapi/3.1.json -> 3.1
# GET /openapi/3.0.json -> 3.0
```

<details>
<summary>Legacy domains mode (deprecated)</summary>

Passing `:domains` directly still works but regenerates the spec on
every request and emits a compile-time deprecation warning:

```elixir
use AshOaskit.Router,
  domains: [MyApp.Blog, MyApp.Accounts],
  open_api: "/docs/openapi",
  title: "My API",
  version: "1.0.0"
```

Migrate by moving the options into a spec module (`use AshOaskit`) and
passing it as `spec:`.

</details>

## AshJsonApi Integration

AshOaskit reads routes from domains using `AshJsonApi.Domain`:

```elixir
defmodule MyApp.Blog do
  use Ash.Domain, extensions: [AshJsonApi.Domain]

  json_api do
    routes do
      base_route "/posts", MyApp.Blog.Post do
        get :read
        index :read
        post :create
        patch :update
        delete :destroy
      end
    end
  end

  resources do
    resource MyApp.Blog.Post
  end
end
```

## Why Dual Version Support?

- **Legacy Tooling** - Some API gateways only support OpenAPI 3.0
- **Modern Validation** - OpenAPI 3.1 uses JSON Schema 2020-12
- **Gradual Migration** - Upgrade specs without breaking consumers

## Development

```bash
mix test            # Run tests
mix check           # Run quality checks
mix docs            # Generate documentation
mix coveralls.html  # Check test coverage
```

## References

- [OpenAPI Specification](https://spec.openapis.org/oas/latest.html)
- [Ash Framework](https://ash-hq.org/)
- [AshJsonApi](https://hexdocs.pm/ash_json_api)
- [Oaskit](https://hexdocs.pm/oaskit)
- [JSON Schema](https://json-schema.org/)

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

MIT License. See [LICENSE.md](LICENSE.md) for details.
