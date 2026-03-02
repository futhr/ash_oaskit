<div align="center">

# AshOaskit

[![Hex.pm](https://img.shields.io/hexpm/v/ash_oaskit.svg)](https://hex.pm/packages/ash_oaskit)
[![Hex Docs](https://img.shields.io/badge/hex-docs-blue.svg)](https://hexdocs.pm/ash_oaskit)
[![CI](https://github.com/futhr/ash_oaskit/actions/workflows/ci.yml/badge.svg)](https://github.com/futhr/ash_oaskit/actions/workflows/ci.yml)
[![Coverage](https://codecov.io/gh/futhr/ash_oaskit/branch/main/graph/badge.svg)](https://codecov.io/gh/futhr/ash_oaskit)
[![License](https://img.shields.io/github/license/futhr/ash_oaskit.svg)](LICENSE.md)

**Dual-version OpenAPI specification generator for [Ash Framework](https://ash-hq.org/)**

[Installation](#installation) |
[Quick Start](#quick-start) |
[Configuration](#configuration) |
[API Reference](#api-reference) |
[Phoenix Integration](#phoenix-integration)

</div>

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
    {:ash_oaskit, "~> 0.1.0"},
    # Optional: For YAML output
    {:ymlr, "~> 5.0", optional: true}
  ]
end
```

## Quick Start

### Generate a Spec

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
# Generate OpenAPI 3.1 spec
mix ash_oaskit.generate -d MyApp.Blog -o openapi.json

# Generate OpenAPI 3.0 spec
mix ash_oaskit.generate -d MyApp.Blog -v 3.0 -o openapi-3.0.json

# Generate YAML format (requires ymlr)
mix ash_oaskit.generate -d MyApp.Blog -f yaml -o openapi.yaml
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
| `:string`, `:ci_string`, `:atom` | `string` | - |
| `:integer` | `integer` | - |
| `:float` | `number` | `float` |
| `:decimal` | `number` | `double` |
| `:boolean` | `boolean` | - |
| `:date` | `string` | `date` |
| `:time` | `string` | `time` |
| `:datetime`, `:utc_datetime`, `:utc_datetime_usec`, `:naive_datetime` | `string` | `date-time` |
| `:uuid` | `string` | `uuid` |
| `:binary` | `string` | `binary` |
| `:map` | `object` | - |
| `:term` | `{}` (any) | - |
| `{:array, type}` | `array` | items: nested |

### Constraint Mapping

| Ash Constraint | JSON Schema |
|----------------|-------------|
| `:min_length` | `minLength` |
| `:max_length` | `maxLength` |
| `:min` | `minimum` |
| `:max` | `maximum` |
| `:match` (Regex) | `pattern` |
| `:one_of` | `enum` |

## Phoenix Integration

### Router Setup

```elixir
# router.ex
scope "/api" do
  # Serve default version
  get "/openapi.json", AshOaskit.Controller, :spec,
    private: %{
      ash_oaskit: [
        domains: [MyApp.Blog, MyApp.Accounts],
        title: "My API",
        api_version: "1.0.0"
      ]
    }

  # Version-specific endpoints
  get "/openapi-3.0.json", AshOaskit.Controller, :spec_30,
    private: %{ash_oaskit: [domains: [MyApp.Blog]]}

  get "/openapi-3.1.json", AshOaskit.Controller, :spec_31,
    private: %{ash_oaskit: [domains: [MyApp.Blog]]}
end
```

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
