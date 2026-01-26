# Agent Guidelines for AshOaskit

## Project Overview

AshOaskit generates OpenAPI 3.0 and 3.1 specifications from Ash Framework domains. It introspects Ash resources for schemas and reads AshJsonApi configurations for routes.

## Architecture

```
AshOaskit.spec/1
      │
      ├─► AshOaskit.OpenApi ─► Version routing
      │         │
      │         ├─► V31.generate/2 (OpenAPI 3.1)
      │         └─► V30.generate/2 (OpenAPI 3.0)
      │
      ├─► SchemaBuilder ─► Accumulates schemas with cycle detection
      │
      ├─► TypeMapper ─► Ash types → JSON Schema
      │
      └─► Config ─► Reads AshJsonApi DSL settings
```

## Key Patterns

### Version Differences

- **3.0**: `nullable: true` for optional fields
- **3.1**: `type: ["string", "null"]` for optional fields

### Type Mapping

All type conversions go through `AshOaskit.TypeMapper`. When adding new types:

1. Add to `@simple_type_schemas` map for basic types
2. Handle in `complex_type_schema/1` for compound types
3. Add to `@ash_type_to_atom` for Ash.Type.* module normalization

### Schema Building

`SchemaBuilder` uses an accumulator pattern:

- `mark_seen/2` prevents infinite recursion on self-referential types
- `add_schema/3` deduplicates (first definition wins)
- Separate tracking for input vs output schemas

## Testing

- Test resources defined in `test/support/test_resources.ex`
- Use `FakeDomain` for minimal domain testing
- Use `AshOaskit.Test.Blog` for full feature testing

## Common Tasks

### Adding a New Ash Type

1. Update `TypeMapper` with the mapping
2. Add tests in `type_mapper_test.exs`
3. Update type mapping table in README.md

### Adding a New OpenAPI Feature

1. Implement in both `V30` and `V31` generators
2. Handle version differences appropriately
3. Add tests for both versions

### Modifying Schema Generation

1. Update `SchemaBuilder` functions
2. Ensure cycle detection still works
3. Test with `embedded_resources_test.exs` and `relationships_test.exs`

## Code Quality

All code must pass:

- `mix format`
- `mix credo --strict`
- `mix dialyzer`
- `mix test` (1340+ tests)

## Guidelines

- Do not modify generated specs after generation (use SpecModifier instead)
- Do not assume AshJsonApi is always present (graceful degradation)
- Do not add dependencies without discussion
