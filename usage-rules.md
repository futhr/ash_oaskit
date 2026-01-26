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

## Phoenix Controller

```elixir
# router.ex
get "/openapi.json", AshOaskit.Controller, :spec,
  private: %{ash_oaskit: [domains: [MyApp.Blog], title: "My API"]}

get "/openapi-3.0.json", AshOaskit.Controller, :spec_30,
  private: %{ash_oaskit: [domains: [MyApp.Blog]]}
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
| `:datetime`, `:utc_datetime`, `:naive_datetime` | `string` | `date-time` |
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
lib/ash_oaskit.ex                    # Main API
lib/ash_oaskit/
  open_api.ex                        # Core generation
  controller.ex                      # Phoenix controller
  type_mapper.ex                     # Type conversion
  schema_builder.ex                  # Schema construction
  filter_builder.ex                  # Filter parameters
  sort_builder.ex                    # Sort parameters
  query_parameters.ex                # Query param schemas
  generators/{v30,v31}.ex            # Version generators
mix/tasks/
  ash_oaskit.generate.ex             # CLI task
  ash_oaskit.install.ex              # Igniter installer
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
