defmodule AshOaskit.Core.SchemaRef do
  @moduledoc """
  Builds OpenAPI `$ref` objects pointing to component schemas.

  JSON Schema references (`$ref`) are the standard mechanism for reusing
  schema definitions in OpenAPI specifications. Every resource, relationship,
  and error schema is defined once under `components/schemas` and referenced
  elsewhere via a `$ref` pointer.

  ## Why string keys?

  The Oaskit normalizer identifies references by checking for the `"$ref"`
  **string** key. Using an atom key (`:$ref`) would cause the normalizer to
  miss the reference entirely, resulting in broken specs. This module
  encapsulates that convention so callers never need to remember it.

  ## Usage

  Import or alias in any module that needs to emit `$ref` pointers:

      import AshOaskit.Core.SchemaRef

      # Inside a schema map
      %{
        "data" => schema_ref("User"),
        "included" => %{"type" => "array", "items" => schema_ref("User")}
      }

  ## Callers

  Used across the generator pipeline:

  | Module | Purpose |
  |--------|---------|
  | `Generator` | Top-level component wiring |
  | `PathBuilder` | Request/response body refs |
  | `ErrorSchemas` | Error source schema refs |
  | `MultipartSupport` | File upload schema refs |
  | `ResourceSchemas` | Resource data/attributes refs |
  | `IncludedResources` | Polymorphic included refs |
  | `RouteResponses` | Relationship route response refs |

  ## Examples

      iex> AshOaskit.Core.SchemaRef.schema_ref("Post")
      %{"$ref" => "#/components/schemas/Post"}

      iex> AshOaskit.Core.SchemaRef.schema_ref_path("PostAttributes")
      "#/components/schemas/PostAttributes"
  """

  @doc """
  Builds a `$ref` path string pointing to a component schema.

  Returns the full JSON Pointer path for use in `$ref` values.

  ## Parameters

    - `name` - The schema name as registered under `components/schemas`

  ## Examples

      iex> AshOaskit.Core.SchemaRef.schema_ref_path("User")
      "#/components/schemas/User"

      iex> AshOaskit.Core.SchemaRef.schema_ref_path("UserAttributes")
      "#/components/schemas/UserAttributes"
  """
  @spec schema_ref_path(String.t()) :: String.t()
  def schema_ref_path(name), do: "#/components/schemas/#{name}"

  @doc ~S"""
  Builds a JSON Schema `$ref` object pointing to a component schema.

  Returns a map with a single `"$ref"` string key. The key is intentionally
  a string — see the module documentation for why.

  ## Parameters

    - `name` - The schema name as registered under `components/schemas`

  ## Examples

      iex> AshOaskit.Core.SchemaRef.schema_ref("User")
      %{"$ref" => "#/components/schemas/User"}

      iex> AshOaskit.Core.SchemaRef.schema_ref("PostRelationships")
      %{"$ref" => "#/components/schemas/PostRelationships"}
  """
  @spec schema_ref(String.t()) :: map()
  def schema_ref(name), do: %{"$ref" => schema_ref_path(name)}
end
