defmodule AshOaskit.Schemas.Nullable do
  @moduledoc """
  Version-aware nullable schema construction for OpenAPI 3.0/3.1.

  Provides two strategies for making schemas nullable:

  - `make_nullable/2` — For schemas with a simple `:type` atom key.
    Converts to `[type, :null]` array (3.1) or adds `nullable: true` (3.0).

  - `make_nullable_oneof/2` — For complex schemas (e.g. `$ref`, resource
    identifiers, link objects). Wraps in `oneOf` with `%{type: :null}` (3.1)
    or adds `nullable: true` (3.0).

  TypeMapper's string-key nullable helpers are intentionally separate — they
  operate on `"type"` string keys for external-facing JSON Schema output.
  """

  @doc """
  Makes a schema nullable based on OpenAPI version.

  For schemas with a simple `:type` atom key:
  - OpenAPI 3.0: adds `nullable: true`
  - OpenAPI 3.1: converts type to array `[type, :null]`

  Returns the schema unchanged in 3.1 mode if no `:type` key is present.
  Use `make_nullable_oneof/2` for complex schemas.

  ## Examples

      iex> AshOaskit.Schemas.Nullable.make_nullable(%{type: :string}, "3.1")
      %{type: [:string, :null]}

      iex> AshOaskit.Schemas.Nullable.make_nullable(%{type: :string}, "3.0")
      %{type: :string, nullable: true}

      iex> AshOaskit.Schemas.Nullable.make_nullable(%{type: :integer, format: :int32}, "3.1")
      %{type: [:integer, :null], format: :int32}
  """
  @spec make_nullable(map(), String.t()) :: map()
  def make_nullable(schema, "3.1"), do: make_nullable_31(schema)
  def make_nullable(schema, _version), do: Map.put(schema, :nullable, true)

  @doc """
  Makes a complex schema nullable using a oneOf wrapper.

  For schemas that cannot use the simple type-array approach (e.g.
  `$ref` schemas, resource identifiers, link objects):
  - OpenAPI 3.0: adds `nullable: true` to the schema
  - OpenAPI 3.1: wraps in `%{oneOf: [%{type: :null}, schema]}`

  If the schema already has a `:oneOf` key, prepends the null type
  to the existing list instead of double-wrapping.

  ## Examples

      iex> AshOaskit.Schemas.Nullable.make_nullable_oneof(%{type: :object, properties: %{}}, "3.0")
      %{type: :object, properties: %{}, nullable: true}

      iex> AshOaskit.Schemas.Nullable.make_nullable_oneof(%{type: :object, properties: %{}}, "3.1")
      %{oneOf: [%{type: :null}, %{type: :object, properties: %{}}]}
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
