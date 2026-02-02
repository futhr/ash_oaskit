defmodule AshOaskit.Schemas.Nullable do
  @moduledoc """
  Version-aware nullable schema construction for OpenAPI 3.0 and 3.1.

  OpenAPI 3.0 and 3.1 represent nullable types differently. This module
  provides version-dispatched helpers so callers can write
  `make_nullable(schema, version)` without branching on the version
  themselves.

  ## Version Differences

  | Version | Simple types | Complex types (`$ref`, `oneOf`) |
  |---------|-------------|-------------------------------|
  | 3.0 | `nullable: true` added to schema | `nullable: true` added to schema |
  | 3.1 | `type` becomes `[type, :null]` array | Wrapped in `oneOf: [%{type: :null}, schema]` |

  ## Which function to use

  - **`make_nullable/2`** — For schemas with a simple `:type` atom key
    (e.g., `%{type: :string}`, `%{type: :integer, format: :int32}`).

  - **`make_nullable_oneof/2`** — For complex schemas that cannot use
    the type-array approach: `$ref` objects, resource identifiers, link
    objects, or schemas that already contain a `:oneOf` key.

  ## Relationship to TypeMapper

  `TypeMapper` has its own string-key nullable helpers that operate on
  `"type"` string keys for external-facing JSON Schema output. Those are
  intentionally separate because they handle a different key convention.

  ## Callers

  | Module | Function used |
  |--------|---------------|
  | `PropertyBuilders` | `make_nullable/2` (via `defdelegate`) |
  | `RelationshipSchemas` | `make_nullable/2` |
  | `ResourceIdentifier` | `make_nullable_oneof/2` |
  | `RouteResponses` | `make_nullable/2`, `make_nullable_oneof/2` |
  | `ResponseLinks` | `make_nullable_oneof/2` |
  | `ResponseMeta` | `make_nullable/2` |

  ## Examples

      iex> AshOaskit.Schemas.Nullable.make_nullable(%{type: :string}, "3.0")
      %{type: :string, nullable: true}

      iex> AshOaskit.Schemas.Nullable.make_nullable(%{type: :string}, "3.1")
      %{type: [:string, :null]}

      iex> AshOaskit.Schemas.Nullable.make_nullable_oneof(
      ...>   %{"$ref" => "#/components/schemas/User"},
      ...>   "3.1"
      ...> )
      %{oneOf: [%{type: :null}, %{"$ref" => "#/components/schemas/User"}]}
  """

  @doc """
  Makes a schema nullable based on OpenAPI version.

  For schemas with a simple `:type` atom key:
  - OpenAPI 3.0: adds `nullable: true`
  - OpenAPI 3.1: converts type to array `[type, :null]`

  Returns the schema unchanged in 3.1 mode if no `:type` key is present.
  Use `make_nullable_oneof/2` for complex schemas without a `:type` key.

  ## Parameters

    - `schema` - A map with a `:type` atom key
    - `version` - OpenAPI version string (`"3.0"` or `"3.1"`)

  ## Examples

      iex> AshOaskit.Schemas.Nullable.make_nullable(%{type: :string}, "3.1")
      %{type: [:string, :null]}

      iex> AshOaskit.Schemas.Nullable.make_nullable(%{type: :string}, "3.0")
      %{type: :string, nullable: true}

      iex> AshOaskit.Schemas.Nullable.make_nullable(%{type: :integer, format: :int32}, "3.1")
      %{type: [:integer, :null], format: :int32}

      iex> AshOaskit.Schemas.Nullable.make_nullable(%{oneOf: [%{type: :string}]}, "3.1")
      %{oneOf: [%{type: :string}]}
  """
  @spec make_nullable(map(), String.t()) :: map()
  def make_nullable(schema, "3.1"), do: make_nullable_31(schema)
  def make_nullable(schema, _version), do: Map.put(schema, :nullable, true)

  @doc ~S"""
  Makes a complex schema nullable using a `oneOf` wrapper.

  For schemas that cannot use the simple type-array approach (e.g.,
  `$ref` schemas, resource identifiers, link objects):
  - OpenAPI 3.0: adds `nullable: true` to the schema
  - OpenAPI 3.1: wraps in `%{oneOf: [%{type: :null}, schema]}`

  If the schema already has a `:oneOf` key, prepends the null type
  to the existing list instead of double-wrapping.

  ## Parameters

    - `schema` - Any map representing a JSON Schema
    - `version` - OpenAPI version string (`"3.0"` or `"3.1"`)

  ## Examples

      iex> AshOaskit.Schemas.Nullable.make_nullable_oneof(%{type: :object, properties: %{}}, "3.0")
      %{type: :object, properties: %{}, nullable: true}

      iex> AshOaskit.Schemas.Nullable.make_nullable_oneof(%{type: :object, properties: %{}}, "3.1")
      %{oneOf: [%{type: :null}, %{type: :object, properties: %{}}]}

      iex> AshOaskit.Schemas.Nullable.make_nullable_oneof(
      ...>   %{"$ref" => "#/components/schemas/User"},
      ...>   "3.1"
      ...> )
      %{oneOf: [%{type: :null}, %{"$ref" => "#/components/schemas/User"}]}

      iex> AshOaskit.Schemas.Nullable.make_nullable_oneof(
      ...>   %{oneOf: [%{type: :string}, %{type: :integer}]},
      ...>   "3.1"
      ...> )
      %{oneOf: [%{type: :null}, %{type: :string}, %{type: :integer}]}
  """
  @spec make_nullable_oneof(map(), String.t()) :: map()
  def make_nullable_oneof(schema, "3.1"), do: make_nullable_oneof_31(schema)
  def make_nullable_oneof(schema, _version), do: Map.put(schema, :nullable, true)

  defp make_nullable_31(%{type: type} = schema) when is_atom(type) do
    Map.put(schema, :type, [type, :null])
  end

  defp make_nullable_31(schema), do: schema

  defp make_nullable_oneof_31(%{oneOf: schemas}) do
    %{oneOf: [%{type: :null} | schemas]}
  end

  defp make_nullable_oneof_31(schema) do
    %{oneOf: [%{type: :null}, schema]}
  end
end
