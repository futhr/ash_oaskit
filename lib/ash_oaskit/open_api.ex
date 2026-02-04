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

  - `openapi` - Version string ("3.0.3" or "3.1.0")
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

  The generated spec is normalized through `Oaskit.normalize_spec!/1` to ensure
  canonical form with proper key ordering and structure.

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
      "3.0.3"

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

    raw_spec =
      case version do
        v when v in ["3.1", "3.1.0"] ->
          V31.generate(domains, opts)

        v when v in ["3.0", "3.0.0", "3.0.3"] ->
          V30.generate(domains, opts)

        other ->
          raise ArgumentError, """
          Unsupported OpenAPI version: #{inspect(other)}

          Supported versions:
            - "3.0", "3.0.0", or "3.0.3" for OpenAPI 3.0
            - "3.1" or "3.1.0" for OpenAPI 3.1 (default)

          Example:
            AshOaskit.spec(domains: [MyDomain], version: "3.1")
          """
      end

    Oaskit.normalize_spec!(raw_spec)
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
  Validate an OpenAPI specification through Oaskit.

  Returns `{:ok, %Oaskit.Spec.OpenAPI{}}` on success or `{:error, error}` on failure.
  The spec should already be normalized (as returned by `spec/1`).

  ## Examples

      iex> spec = AshOaskit.OpenApi.spec(domains: [AshOaskit.Test.Blog])
      ...> {:ok, validated} = AshOaskit.OpenApi.validate(spec)
      ...> validated.__struct__
      Oaskit.Spec.OpenAPI

  """
  @spec validate(map()) :: {:ok, struct()} | {:error, term()}
  def validate(spec) when is_map(spec) do
    Oaskit.SpecValidator.validate(spec)
  end

  @doc """
  Validate an OpenAPI specification through Oaskit.

  Returns `%Oaskit.Spec.OpenAPI{}` on success or raises on failure.
  The spec should already be normalized (as returned by `spec/1`).

  ## Examples

      iex> spec = AshOaskit.OpenApi.spec(domains: [AshOaskit.Test.Blog])
      ...> validated = AshOaskit.OpenApi.validate!(spec)
      ...> validated.__struct__
      Oaskit.Spec.OpenAPI

  """
  @spec validate!(map()) :: struct()
  def validate!(spec) when is_map(spec) do
    Oaskit.SpecValidator.validate!(spec)
  end

  @doc """
  Convert a spec to a JSON-encodable map.

  Handles Oaskit structs by normalizing through Oaskit and encoding via
  `Oaskit.SpecDumper` to produce a plain map.
  """
  @spec to_map(map()) :: map()
  def to_map(spec) when is_struct(spec) do
    Oaskit.normalize_spec!(spec)
  end

  def to_map(spec) when is_map(spec), do: spec

  # Get the default OpenAPI version from application config
  defp default_version do
    Application.get_env(:ash_oaskit, :version, "3.1")
  end
end
