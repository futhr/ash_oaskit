defmodule AshOaskit do
  @moduledoc """
  OpenAPI specification generator for Ash Framework domains.

  AshOaskit automatically generates OpenAPI 3.0 and 3.1 specifications from your
  Ash domains by introspecting resources, attributes, actions, and AshJsonApi routes.

  ## Three Levels of Customization

  AshOaskit provides three levels of customization for serving OpenAPI specs:

  ### 1. Router Macro (Simple)

  For quick setup with standard endpoints:

      # In your Phoenix router
      scope "/api" do
        pipe_through :api

        use AshOaskit.Router,
          domains: [MyApp.Blog, MyApp.Accounts],
          open_api: "/docs/openapi",
          title: "My API",
          version: "1.0.0"
      end

  This automatically generates routes for both OpenAPI 3.0 and 3.1:

      GET /api/docs/openapi.json      -> Default (3.1) spec
      GET /api/docs/openapi/3.0.json  -> OpenAPI 3.0 spec
      GET /api/docs/openapi/3.1.json  -> OpenAPI 3.1 spec

  ### 2. Router Macro + Custom SpecBuilder

  For customization (security schemes, feature flags, domain filtering):

      use AshOaskit.Router,
        spec_builder: MyApp.OpenApi.SpecBuilder,
        domains: [MyApp.Blog],
        open_api: "/openapi",
        title: "My API"

  Where `MyApp.OpenApi.SpecBuilder` implements `AshOaskit.SpecBuilder`:

      defmodule MyApp.OpenApi.SpecBuilder do
        @behaviour AshOaskit.SpecBuilder

        @impl true
        def spec(openapi_version, opts) do
          AshOaskit.spec(
            domains: opts[:domains],
            version: openapi_version,
            title: opts[:title]
          )
          |> add_security_schemes()
          |> add_feature_flags()
        end

        defp add_security_schemes(spec) do
          put_in(spec, ["components", "securitySchemes"], %{
            "bearerAuth" => %{
              "type" => "http",
              "scheme" => "bearer",
              "bearerFormat" => "JWT"
            }
          })
        end

        defp add_feature_flags(spec) do
          Map.put(spec, "x-features", %{"beta" => true})
        end
      end

  ### 3. Programmatic API (Advanced)

  For complete control over routing and serving:

      # Generate spec programmatically in your own controller
      spec = AshOaskit.spec(
        domains: [MyApp.Blog],
        version: "3.1",
        title: "My API"
      )
      |> add_custom_processing()

  This is an escape hatch for edge cases not covered by the Router macro.

  ## When to Use Which

  | Use Case | Approach |
  |----------|----------|
  | Standard API documentation | Router Macro |
  | Custom security schemes | Router + SpecBuilder |
  | Feature flags / extensions | Router + SpecBuilder |
  | Version-specific domains | Router + SpecBuilder |
  | Non-standard routing | Programmatic API |
  | Complete custom control | Programmatic API |

  ## Architecture Overview

  ```
  ┌────────────────┐
  │   Ash Domain   │
  │   (Resources)  │
  └───────┬────────┘
          │
          ▼
  ┌───────────────┐      ┌─────────────────┐
  │    Config     │─────▶│   TypeMapper    │
  │ (metadata)    │      │ (Ash -> JSON)   │
  └───────┬───────┘      └────────┬────────┘
          │                       │
          ▼                       ▼
  ┌───────────────┐      ┌─────────────────┐
  │ SchemaBuilder │◀─────│  FilterBuilder  │
  │ (components)  │      │  SortBuilder    │
  └───────┬───────┘      │  QueryParams    │
          │              └─────────────────┘
          ▼
  ┌───────────────┐      ┌─────────────────┐
  │   Generator   │─────▶│  ResponseLinks  │
  │  (v30/v31)    │      │  ResponseMeta   │
  └───────┬───────┘      │  ErrorSchemas   │
          │              └─────────────────┘
          ▼
  ┌───────────────┐
  │  OpenAPI Spec │
  │  (JSON/YAML)  │
  └───────────────┘
  ```

  ## Features

  - **Dual Version Support** - Generate OpenAPI 3.0 or 3.1 specifications
  - **Automatic Schema Generation** - Extracts schemas from Ash resource attributes
  - **AshJsonApi Integration** - Builds paths from AshJsonApi routes when available
  - **JSON:API Compliance** - Generates proper JSON:API document structures
  - **Type Mapping** - Comprehensive Ash type to JSON Schema conversion
  - **Filter Support** - Generates filter parameter schemas from resource filters
  - **Sort Support** - Generates sort parameter schemas from resource sorts
  - **Pagination** - Handles offset, keyset, and cursor pagination styles
  - **Relationships** - Proper handling of belongs_to, has_many, has_one
  - **Router Macro** - Quick setup for serving specs in Phoenix
  - **SpecBuilder Behaviour** - Customizable spec generation via behaviour
  - **Plug Controller** - Flexible controller for custom configurations
  - **Mix Task** - Generate spec files from the command line

  ## Quick Start

      # Generate OpenAPI 3.1 spec (default)
      spec = AshOaskit.spec(domains: [MyApp.Blog])

      # Generate OpenAPI 3.0 spec
      spec = AshOaskit.spec_30(domains: [MyApp.Blog])

      # With full options
      spec = AshOaskit.spec(
        domains: [MyApp.Blog, MyApp.Accounts],
        title: "My API",
        api_version: "2.0.0",
        description: "Blog and Accounts API",
        servers: ["https://api.example.com"]
      )

  ## Options

  All functions accept these common options:

    * `:domains` - List of Ash domains to include (required)
    * `:version` - OpenAPI version: `"3.0"` or `"3.1"` (default: `"3.1"`)
    * `:title` - API title (default: `"API"`)
    * `:api_version` - API version string (default: `"1.0.0"`)
    * `:description` - API description
    * `:servers` - List of server URLs or server objects
    * `:contact` - Contact information map with `:name`, `:email`, `:url`
    * `:license` - License information map with `:name`, `:url`
    * `:terms_of_service` - Terms of service URL
    * `:security` - Security requirements list
    * `:external_docs` - External documentation map

  ## Configuration

  Set defaults in your application config:

      config :ash_oaskit,
        version: "3.1",
        title: "My API",
        api_version: "1.0.0",
        domains: [MyApp.Blog, MyApp.Accounts]

  ## Mix Task

  Generate spec files from the command line:

      # Generate JSON spec
      mix ash_oaskit.generate --domains MyApp.Blog --output openapi.json

      # Generate YAML spec with options
      mix ash_oaskit.generate \\
        --domains MyApp.Blog,MyApp.Accounts \\
        --output openapi.yaml \\
        --title "My API" \\
        --version 3.0

  ## Module Overview

  | Module | Purpose |
  |--------|---------|
  | `AshOaskit.Router` | Router macro for quick Phoenix integration |
  | `AshOaskit.SpecBuilder` | Behaviour for custom spec generation |
  | `AshOaskit.SpecBuilder.Default` | Default SpecBuilder implementation |
  | `AshOaskit.Controller` | Plug controller for serving specs |
  | `AshOaskit.OpenApi` | Main entry point for spec generation |
  | `AshOaskit.Config` | Configuration and domain introspection |
  | `AshOaskit.TypeMapper` | Ash type to JSON Schema mapping |

  See individual module documentation for detailed information.
  """

  alias AshOaskit.OpenApi

  @doc """
  Generate an OpenAPI specification for the given domains.

  This is the main entry point for generating OpenAPI specifications. It delegates
  to `AshOaskit.OpenApi.spec/1` and supports both OpenAPI 3.0 and 3.1 versions.

  ## Options

    * `:domains` - List of Ash domains to include (required)
    * `:version` - OpenAPI version: "3.0" or "3.1" (default: "3.1")
    * `:title` - API title (default: "API")
    * `:api_version` - API version string (default: "1.0.0")
    * `:servers` - List of server URLs
    * `:description` - API description

  ## Examples

      iex> spec = AshOaskit.spec(domains: [AshOaskit.Test.Blog])
      ...> spec["openapi"]
      "3.1.0"

      iex> spec = AshOaskit.spec(domains: [AshOaskit.Test.Blog], version: "3.0")
      ...> spec["openapi"]
      "3.0.0"

      iex> spec = AshOaskit.spec(domains: [AshOaskit.Test.Blog], title: "My API")
      ...> spec["info"]["title"]
      "My API"

  ## Return Value

  Returns a map representing the complete OpenAPI specification that can be
  encoded to JSON or YAML.
  """
  defdelegate spec(opts), to: OpenApi

  @doc """
  Generate an OpenAPI 3.0 specification.

  Convenience function that calls `spec/1` with `version: "3.0"`.

  OpenAPI 3.0 uses `nullable: true` for optional fields and has some
  differences in how types are represented compared to 3.1.

  ## Examples

      iex> spec = AshOaskit.spec_30(domains: [AshOaskit.Test.Blog])
      ...> spec["openapi"]
      "3.0.0"

  See `spec/1` for full options documentation.
  """
  defdelegate spec_30(opts), to: OpenApi

  @doc """
  Generate an OpenAPI 3.1 specification.

  Convenience function that calls `spec/1` with `version: "3.1"`.

  OpenAPI 3.1 aligns more closely with JSON Schema and uses
  `type: ["string", "null"]` for nullable fields.

  ## Examples

      iex> spec = AshOaskit.spec_31(domains: [AshOaskit.Test.Blog])
      ...> spec["openapi"]
      "3.1.0"

  See `spec/1` for full options documentation.
  """
  defdelegate spec_31(opts), to: OpenApi
end
