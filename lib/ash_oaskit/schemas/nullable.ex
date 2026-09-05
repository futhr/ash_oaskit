defmodule AshOaskit.Schemas.Nullable do
  @moduledoc """
  Adds null to a schema without discarding its constraints.

  OpenAPI 3.1 uses type arrays for simple schemas; 3.0 uses an explicit
  type with `nullable: true`. References and compositions use `anyOf`,
  since `oneOf` rejects null when the original schema already accepts it.
  Atom keys are the default; TypeMapper requests string keys.
  """

  @doc "Makes a schema nullable, preserving enum values and composition constraints."
  @spec make_nullable(map(), String.t(), :atom | :string) :: map()
  def make_nullable(schema, version, keys \\ :atom)
  def make_nullable(schema, _, _) when map_size(schema) == 0, do: schema

  def make_nullable(schema, version, keys) do
    type_key = key(:type, keys)

    if Map.has_key?(schema, type_key) and not complex?(schema, keys) do
      schema
      |> nullable_type(version, keys)
      |> nullable_enum(keys)
    else
      wrap(schema, version, keys)
    end
  end

  @doc "Makes a complex schema nullable. The historical name is retained for compatibility."
  @spec make_nullable_oneof(map(), String.t()) :: map()
  def make_nullable_oneof(schema, "3.1"), do: wrap(schema, "3.1", :atom)
  def make_nullable_oneof(schema, version), do: make_nullable(schema, version)

  defp nullable_type(schema, "3.1", keys) do
    Map.update!(schema, key(:type, keys), fn type ->
      Enum.uniq(List.wrap(type) ++ [key(:null, keys)])
    end)
  end

  defp nullable_type(schema, _, keys), do: Map.put(schema, key(:nullable, keys), true)

  defp nullable_enum(schema, keys) do
    enum_key = key(:enum, keys)

    if Map.has_key?(schema, enum_key) do
      Map.update!(schema, enum_key, &Enum.uniq(&1 ++ [nil]))
    else
      schema
    end
  end

  defp complex?(schema, keys) do
    Map.has_key?(schema, "$ref") or
      Enum.any?([:oneOf, :anyOf, :allOf, :not, :const, :if], &Map.has_key?(schema, key(&1, keys)))
  end

  defp wrap(schema, version, keys) do
    null_schema =
      if version == "3.1" do
        %{key(:type, keys) => key(:null, keys)}
      else
        %{
          key(:type, keys) => key(:object, keys),
          key(:nullable, keys) => true,
          key(:enum, keys) => [nil]
        }
      end

    case Map.get(schema, key(:anyOf, keys)) do
      branches when is_list(branches) and map_size(schema) == 1 ->
        %{key(:anyOf, keys) => Enum.uniq([null_schema | branches])}

      _ ->
        %{key(:anyOf, keys) => [null_schema, schema]}
    end
  end

  defp key(atom, :atom), do: atom
  defp key(atom, :string), do: Atom.to_string(atom)
end
