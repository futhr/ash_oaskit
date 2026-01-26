defmodule AshOaskit do
  @moduledoc """
  OpenAPI specification generator for Ash Framework domains.

  AshOaskit automatically generates OpenAPI 3.0 and 3.1 specifications from your
  Ash domains by introspecting resources, attributes, actions, and AshJsonApi routes.

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
  │ (metadata)    │      │ (Ash→JSON type) │
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
  - **Plug Controller** - Serve specs directly from your Phoenix app
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

  ## Generated Spec Structure

  ```
  openapi: "3.1.0"
  info:
    title: "API"
    version: "1.0.0"
  paths:
    /posts:
      get: ...        # index action
      post: ...       # create action
    /posts/{id}:
      get: ...        # read action
      patch: ...      # update action
      delete: ...     # destroy action
  components:
    schemas:
      Post: ...       # Resource schema
      PostInput: ...  # Input schema for create/update
      Error: ...      # JSON:API error object
  ```

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

  ## Phoenix Integration

  Add to your router to serve specs:

      scope "/api" do
        get "/openapi.json", AshOaskit.Controller, :spec
        get "/openapi.yaml", AshOaskit.Controller, :spec_yaml
      end

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
  | `AshOaskit.OpenApi` | Main entry point for spec generation |
  | `AshOaskit.Config` | Configuration and domain introspection |
  | `AshOaskit.TypeMapper` | Ash type to JSON Schema mapping |
  | `AshOaskit.SchemaBuilder` | Component schema construction |
  | `AshOaskit.FilterBuilder` | Filter parameter generation |
  | `AshOaskit.SortBuilder` | Sort parameter generation |
  | `AshOaskit.QueryParameters` | Query parameter schemas |
  | `AshOaskit.Controller` | Phoenix controller for serving specs |

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
