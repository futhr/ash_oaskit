# Agent Guidelines for AshOaskit

## Project Overview

AshOaskit generates OpenAPI 3.0 and 3.1 specifications from Ash Framework domains. It introspects Ash resources for schemas and reads AshJsonApi configurations for routes.

## Architecture

### Generation Flow

```
AshOaskit.spec(opts)
        │
        ▼
    OpenApi.spec/1 ──► version routing
        │
    ┌───┴───┐
    ▼       ▼
  V31     V30
    │       │
    └───┬───┘
        ▼
  Shared.generate ──► Generator.generate
        │
   ┌────┼────────────┐
   ▼    ▼            ▼
InfoBuilder  PathBuilder  SchemaBuilder
   │         │              │
   │         │         ┌────┼──────────┐
   │         │         ▼    ▼          ▼
   │         │    ResourceSchemas  RelationshipSchemas
   │         │         │               │
   │         │    PropertyBuilders  EmbeddedSchemas
   ▼         ▼         ▼
 Info +   Paths +   Components
 Tags   Operations  (Schemas)
Servers
```

### Module Structure

```
lib/ash_oaskit.ex                          # Main public API (spec, validate)
lib/ash_oaskit/
  open_api.ex                              # Version routing (spec → V30/V31)
  open_api_controller.ex                   # Behaviour for Phoenix controllers
  phoenix_introspection.ex                 # Extract routes from Phoenix router
  router.ex                                # Router macro for serving specs
  spec_builder.ex                          # SpecBuilder behaviour
  spec_builder/default.ex                  # Default SpecBuilder implementation
  core/
    config.ex                              # Config — AshJsonApi DSL reader
    path_utils.ex                          # Core.PathUtils — path param conversion
    schema_ref.ex                          # Core.SchemaRef — $ref object builder
    spec_modifier.ex                       # SpecModifier — post-generation hooks
    type_mapper.ex                         # TypeMapper — Ash → JSON Schema types
  generators/
    generator.ex                           # Generator — orchestrates all builders
    info_builder.ex                        # InfoBuilder — info, servers, tags
    path_builder.ex                        # PathBuilder — paths and operations
    shared.ex                              # Shared — entry point for both versions
    v30.ex                                 # V30 — OpenAPI 3.0 entry point
    v31.ex                                 # V31 — OpenAPI 3.1 entry point
  parameters/
    filter_builder.ex                      # FilterBuilder — filter query params
    query_parameters.ex                    # QueryParameters — page, fields, include, sort
    sort_builder.ex                        # SortBuilder — sort param schemas
  resources/
    included_resources.ex                  # IncludedResources — included array schemas
    resource_identifier.ex                 # ResourceIdentifier — type+id linkage
    tag_builder.ex                         # TagBuilder — operation grouping tags
  responses/
    error_schemas.ex                       # ErrorSchemas — JSON:API error responses
    response_links.ex                      # ResponseLinks — self, related, pagination links
    response_meta.ex                       # ResponseMeta — pagination meta schemas
  routes/
    relationship_routes.ex                 # RelationshipRoutes — relationship endpoints
    route_operations.ex                    # RouteOperations — operation object builder
    route_responses.ex                     # RouteResponses — response schema builder
  schemas/
    embedded_schemas.ex                    # EmbeddedSchemas — embedded resource detection
    nullable.ex                            # Schemas.Nullable — version-aware nullable
    property_builders.ex                   # PropertyBuilders — attrs/calcs/aggregates
    relationship_schemas.ex                # RelationshipSchemas — relationship linkage
    resource_schemas.ex                    # ResourceSchemas — resource schema generation
    schema_builder.ex                      # SchemaBuilder — accumulator with cycle detection
  support/
    controller.ex                          # Controller — Phoenix controller for specs
    multipart_support.ex                   # MultipartSupport — file upload schemas
    security.ex                            # Security — security scheme generation
  router/
    plug.ex                                # Router.Plug — Plug for serving specs
mix/tasks/
    ash_oaskit.generate.ex                 # CLI: mix ash_oaskit.generate
    ash_oaskit.install.ex                  # CLI: mix ash_oaskit.install
```

### Test Structure

Tests mirror the lib/ directory structure 1:1. Each source module has a corresponding `_test.exs` file in the matching path. Additional cross-cutting integration tests live at the `test/ash_oaskit/` root:

- `advanced_types_test.exs` — Cross-cutting TypeMapper coverage
- `calculations_aggregates_test.exs` — PropertyBuilders integration
- `components_test.exs` — Full components object
- `format_strings_test.exs` — JSON Schema format strings
- `integration_test.exs` — End-to-end spec generation
- `cross_version_contamination_test.exs` — Cross-version feature leakage checks
- `open_api_test.exs` — Core OpenApi module tests
- `openapi_30_compliance_test.exs` — OpenAPI 3.0 spec compliance checks
- `openapi_31_compliance_test.exs` — OpenAPI 3.1 spec compliance checks
- `parameter_styles_test.exs` — Parameter serialization
- `phoenix_introspection_test.exs` — Phoenix router extraction
- `response_codes_test.exs` — HTTP response codes
- `router_test.exs` — Router macro tests
- `spec_builder_test.exs` — SpecBuilder behaviour tests
- `webhooks_test.exs` — OpenAPI 3.1 webhooks

## Key Patterns

### Version Differences

- **3.0**: `nullable: true` for optional fields
- **3.1**: `type: ["string", "null"]` for optional fields

Handled by `Schemas.Nullable` (atom-key schemas) and `TypeMapper` (string-key schemas).

### Type Mapping

All type conversions go through `TypeMapper`. When adding new types:

1. Add to `@simple_type_schemas` map for basic types
2. Handle in `complex_type_schema/1` for compound types
3. Add to `@ash_type_to_atom` for Ash.Type.* module normalization

`PropertyBuilders` also maintains a parallel `@type_to_schema_map` for calculation/aggregate type resolution.

### Schema Building

`SchemaBuilder` uses an accumulator pattern:

- `mark_seen/2` prevents infinite recursion on self-referential types
- `add_schema/3` deduplicates (first definition wins)
- Separate tracking for input vs output schemas
- Sub-modules: `ResourceSchemas`, `RelationshipSchemas`, `EmbeddedSchemas`, `PropertyBuilders`

### $ref Convention

`Core.SchemaRef` builds `$ref` objects with **string** keys (`"$ref"` not `:$ref`). This is required because the Oaskit normalizer detects references by checking for the `"$ref"` string key.

### Path Utilities

`Core.PathUtils` provides shared functions for Phoenix-to-OpenAPI path conversion (`:id` → `{id}`), parameter extraction, and humanization. Used by `PathBuilder`, `PhoenixIntrospection`, and `RouteOperations`.

### Spec Modification

`SpecModifier` enables post-generation customization via function callbacks or MFA tuples. Used for adding security schemes, custom headers, webhooks, deprecation markers, etc.

### SpecBuilder Behaviour

`SpecBuilder` defines a behaviour for custom spec generation. The default implementation delegates to `AshOaskit.spec/1`. Custom implementations can add security schemes, feature flags, or domain filtering.

### Router Macro

`AshOaskit.Router` provides a `use` macro for both Phoenix Router and Plug.Router that auto-generates versioned spec endpoints. Automatically detects the router type and generates appropriate routes inline. Supports custom SpecBuilder, format selection (JSON/YAML), and Phoenix router introspection.

## Testing

- Test resources defined in `test/support/test_resources.ex`
- Relationship resources in `test/support/relationship_resources.ex`
- Use `AshOaskit.Test.Blog` for full feature testing
- Use `AshOaskit.Test.SimpleDomain` / `AshOaskit.Test.EdgeCaseDomain` for edge cases
- Warning-producing tests use `ExUnit.CaptureLog` to keep output clean

## Common Tasks

### Adding a New Ash Type

1. Update `TypeMapper` (`lib/ash_oaskit/core/type_mapper.ex`) with the mapping
2. Update `PropertyBuilders` (`lib/ash_oaskit/schemas/property_builders.ex`) if needed for calculation/aggregate support
3. Add tests in `test/ash_oaskit/core/type_mapper_test.exs`
4. Update type mapping table in README.md and usage-rules.md

### Adding a New OpenAPI Feature

1. Implement in `Generator` or the appropriate sub-module
2. Handle version differences via `Schemas.Nullable` or direct version branching
3. Add tests for both versions (use existing V30/V31 test patterns)

### Modifying Schema Generation

1. Update the appropriate sub-module under `schemas/`
2. Ensure cycle detection still works (`SchemaBuilder.mark_seen/2` / `seen?/2`)
3. Test with `embedded_schemas_test.exs` and `relationship_schemas_test.exs`

### Adding a SpecModifier Helper

1. Add to `SpecModifier` (`lib/ash_oaskit/core/spec_modifier.ex`)
2. Add catch-all with `Logger.warning` for invalid inputs
3. Add tests in `test/ash_oaskit/core/spec_modifier_test.exs`

### Adding Phoenix Integration

1. For controller features: update `Controller` (`lib/ash_oaskit/support/controller.ex`)
2. For router features: update `Router` (`lib/ash_oaskit/router.ex`) and `Router.Plug`
3. For controller introspection: update `PhoenixIntrospection` and `OpenApiController`

## Code Quality

All code must pass:

```bash
mix check # Runs all 10 tools:
```

- `mix compile --warnings-as-errors`
- `mix credo --strict`
- `mix dialyzer`
- `mix doctor`
- `mix format --check-formatted`
- `mix hex.audit`
- `mix deps.audit`
- `mix sobelow`
- `mix test`
- `mix deps.unlock --check-unused`

## Guidelines

- Do not modify generated specs after generation (use SpecModifier instead)
- Do not assume AshJsonApi is always present (graceful degradation)
- Do not add dependencies without discussion
- Use `Core.SchemaRef.schema_ref/1` for all `$ref` construction (string keys required)
- Use `Schemas.Nullable` for nullable handling (not inline version branching)
- Use `Core.PathUtils` for path parameter operations (not inline regex)
- Use `Logger.warning` in catch-all clauses for unknown inputs
- Use `ExUnit.CaptureLog` in tests that trigger Logger.warning
- Keep test files mirroring lib/ directory structure
