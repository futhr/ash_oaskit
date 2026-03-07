# AshOaskit Usage Rules

OpenAPI specification generator for Ash Framework domains. Supports OpenAPI 3.0 and 3.1.

## API

```elixir
# Generate spec (defaults to 3.1)
AshOaskit.spec(domains: [MyApp.Blog])
AshOaskit.spec_30(domains: [MyApp.Blog])  # Force 3.0
AshOaskit.spec_31(domains: [MyApp.Blog])  # Force 3.1

# Full options
AshOaskit.spec(
  domains: [MyApp.Blog, MyApp.Accounts],
  version: "3.1",
  title: "My API",
  api_version: "2.0.0",
  description: "API description",
  servers: [%{"url" => "https://api.example.com"}],
  contact: %{"name" => "Support", "email" => "api@example.com"},
  license: %{"name" => "MIT"},
  security: [%{"bearerAuth" => []}]
)
```

## CLI

```bash
mix ash_oaskit.generate -d MyApp.Blog -o openapi.json
mix ash_oaskit.generate -d MyApp.Blog,MyApp.Accounts -v 3.0 -o openapi.yaml -f yaml
mix ash_oaskit.generate --domains MyApp.Blog --title "My API" --api-version 1.0.0
```

## Router Macro

```elixir
# Phoenix Router
use AshOaskit.Router,
  domains: [MyApp.Blog],
  open_api: "/openapi",
  title: "My API"

# Plug.Router — same options, place before catch-all `match _`
use AshOaskit.Router,
  domains: [MyApp.Blog],
  open_api: "/openapi",
  title: "My API"
```

## Domain Setup

```elixir
defmodule MyApp.Blog do
  use Ash.Domain, extensions: [AshJsonApi.Domain]

  resources do
    resource MyApp.Blog.Post
  end

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
end
```

## Resource Setup

```elixir
defmodule MyApp.Blog.Post do
  use Ash.Resource, domain: MyApp.Blog, extensions: [AshJsonApi.Resource]

  json_api do
    type "post"
  end

  attributes do
    uuid_primary_key :id
    attribute :title, :string, allow_nil?: false, constraints: [min_length: 1, max_length: 255]
    attribute :body, :string, description: "Post content"
    attribute :status, :atom, constraints: [one_of: [:draft, :published]], default: :draft
  end

  actions do
    defaults [:read, :destroy]
    create :create, accept: [:title, :body, :status]
    update :update, accept: [:title, :body, :status]
  end
end
```

## Type Mapping

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
| `{:array, type}` | `array` | - |

## Constraint Mapping

| Ash | JSON Schema |
|-----|-------------|
| `:min_length` | `minLength` |
| `:max_length` | `maxLength` |
| `:min` | `minimum` |
| `:max` | `maximum` |
| `:match` | `pattern` |
| `:one_of` | `enum` |

## Version Differences

- **3.0**: `nullable: true` for nullable fields
- **3.1**: `type: ["string", "null"]` for nullable fields (JSON Schema 2020-12)

## Module Structure

```
lib/ash_oaskit.ex                              # Main API (spec, validate)
lib/ash_oaskit/
  open_api.ex                                  # Version routing
  open_api_controller.ex                       # Controller behaviour
  phoenix_introspection.ex                     # Phoenix router extraction
  router.ex                                    # Router macro
  spec_builder.ex                              # SpecBuilder behaviour
  spec_builder/default.ex                      # Default SpecBuilder
  core/
    config.ex                                  # AshJsonApi DSL reader
    path_utils.ex                              # Path param conversion
    schema_ref.ex                              # $ref object builder
    spec_modifier.ex                           # Post-generation hooks
    type_mapper.ex                             # Ash → JSON Schema types
  generators/
    generator.ex                               # Main orchestrator
    info_builder.ex                            # Info, servers, tags
    path_builder.ex                            # Paths and operations
    shared.ex                                  # Entry point (both versions)
    v30.ex                                     # OpenAPI 3.0 entry
    v31.ex                                     # OpenAPI 3.1 entry
  parameters/
    filter_builder.ex                          # Filter query params
    query_parameters.ex                        # page, fields, include, sort
    sort_builder.ex                            # Sort param schemas
  resources/
    included_resources.ex                      # Included array schemas
    resource_identifier.ex                     # Type+id linkage
    tag_builder.ex                             # Operation grouping tags
  responses/
    error_schemas.ex                           # JSON:API error responses
    response_links.ex                          # Self, related, pagination links
    response_meta.ex                           # Pagination meta schemas
  routes/
    relationship_routes.ex                     # Relationship endpoints
    route_operations.ex                        # Operation object builder
    route_responses.ex                         # Response schema builder
  schemas/
    embedded_schemas.ex                        # Embedded resource detection
    nullable.ex                                # Version-aware nullable
    property_builders.ex                       # Attrs/calcs/aggregates → schema
    relationship_schemas.ex                    # Relationship linkage schemas
    resource_schemas.ex                        # Resource schema generation
    schema_builder.ex                          # Accumulator + cycle detection
  support/
    controller.ex                              # Phoenix controller
    multipart_support.ex                       # File upload schemas
    security.ex                                # Security schemes
  router/
    plug.ex                                    # Plug for serving specs
mix/tasks/
  ash_oaskit.generate.ex                       # CLI: mix ash_oaskit.generate
  ash_oaskit.install.ex                        # CLI: mix ash_oaskit.install
```

## Configuration

```elixir
config :ash_oaskit,
  version: "3.1",
  title: "My API",
  api_version: "1.0.0"
```

## Testing

```elixir
test "generates valid spec" do
  spec = AshOaskit.spec(domains: [MyApp.Blog])
  assert spec["openapi"] == "3.1.0"
  assert is_map(spec["paths"])
  assert is_map(spec["components"]["schemas"])
end
```

## Development

```bash
mix deps.get && mix test && mix check
```
