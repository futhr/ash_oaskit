defmodule AshOaskit.OpenApi do
  @moduledoc """
  Core OpenAPI spec generator for Ash domains.

  This module provides the main entry point for generating OpenAPI specifications
  from Ash domains. It routes to version-specific generators based on configuration.

  ## Overview

  The OpenApi module acts as a facade that:

  1. Validates input options (domains must be provided)
  2. Determines the target OpenAPI version (3.0 or 3.1)
  3. Delegates to the appropriate version-specific generator

  ## Version Selection

  ```
  spec(opts)
       │
       ├── version: "3.1" ──▶ V31.generate/2
       │
       └── version: "3.0" ──▶ V30.generate/2
  ```

  The version can be specified via:
  - `:version` option in the function call
  - Application config: `config :ash_oaskit, version: "3.1"`
  - Default: "3.1"

  ## Generated Spec Structure

  Both versions produce a map with this structure:

  - `openapi` - Version string ("3.0.0" or "3.1.0")
  - `info` - Title, version, description, contact, license
  - `servers` - List of server objects
  - `paths` - API endpoints from AshJsonApi routes
  - `components` - Schemas, parameters, responses
  - `tags` - Grouping tags for operations

  ## Usage Examples

      # Basic usage with defaults
      spec = AshOaskit.OpenApi.spec(domains: [MyApp.Blog])

      # With full options
      spec = AshOaskit.OpenApi.spec(
        domains: [MyApp.Blog, MyApp.Accounts],
        version: "3.1",
        title: "My API",
        api_version: "2.0.0",
        description: "API for managing blogs and accounts",
        servers: ["https://api.example.com"]
      )

      # Convert to JSON
      json = Jason.encode!(spec)

  ## Version-Specific Differences

  | Feature | OpenAPI 3.0 | OpenAPI 3.1 |
  |---------|-------------|-------------|
  | Nullable | `nullable: true` | `type: ["string", "null"]` |
  | Examples | `example` only | `example` and `examples` |
  | JSON Schema | Draft 5 subset | Draft 2020-12 aligned |
  """

  alias AshOaskit.Generators.{V30, V31}

  @doc """
  Generate an OpenAPI specification for the given domains.

  ## Options

    * `:domains` - List of Ash domains to include (required)
    * `:version` - OpenAPI version: "3.0" or "3.1" (default from config or "3.1")
    * `:title` - API title
    * `:api_version` - API version string
    * `:servers` - List of server URLs
    * `:description` - API description

  ## Examples

      iex> spec = AshOaskit.OpenApi.spec(domains: [AshOaskit.Test.Blog])
      ...> spec["openapi"]
      "3.1.0"

      iex> spec = AshOaskit.OpenApi.spec(domains: [AshOaskit.Test.Blog], version: "3.0")
      ...> spec["openapi"]
      "3.0.0"

      iex> spec = AshOaskit.OpenApi.spec(domains: [AshOaskit.Test.Blog], title: "Test API")
      ...> spec["info"]["title"]
      "Test API"

  """
  @spec spec(keyword()) :: map()
  def spec(opts \\ []) do
    version = Keyword.get(opts, :version, default_version())
    domains = opts |> Keyword.get(:domains, []) |> List.wrap()

    if domains == [] do
      raise ArgumentError, "at least one domain must be specified via :domains option"
    end

    case version do
      v when v in ["3.1", "3.1.0"] ->
        V31.generate(domains, opts)

      v when v in ["3.0", "3.0.0"] ->
        V30.generate(domains, opts)

      other ->
        raise ArgumentError,
              "unsupported OpenAPI version: #{inspect(other)}. " <>
                "Supported versions are \"3.0\" and \"3.1\""
    end
  end

  @doc """
  Generate an OpenAPI 3.0 specification.

  Shorthand for `spec(Keyword.put(opts, :version, "3.0"))`.
  """
  @spec spec_30(keyword()) :: map()
  def spec_30(opts \\ []) do
    opts
    |> Keyword.put(:version, "3.0")
    |> spec()
  end

  @doc """
  Generate an OpenAPI 3.1 specification.

  Shorthand for `spec(Keyword.put(opts, :version, "3.1"))`.
  """
  @spec spec_31(keyword()) :: map()
  def spec_31(opts \\ []) do
    opts
    |> Keyword.put(:version, "3.1")
    |> spec()
  end

  @doc """
  Convert a spec to a JSON-encodable map.

  This handles the differences between OpenApiSpex structs and oaskit structs.
  """
  @spec to_map(map()) :: map()
  def to_map(spec) when is_struct(spec) do
    # Both OpenApiSpex and oaskit implement Jason.Encoder
    spec
    |> Jason.encode!()
    |> Jason.decode!()
  end

  def to_map(spec) when is_map(spec), do: spec

  # Get the default OpenAPI version from application config
  defp default_version do
    Application.get_env(:ash_oaskit, :version, "3.1")
  end
end
