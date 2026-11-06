defmodule AshOaskit.Test.SchemaValidation do
  @moduledoc false

  @spec json_schema(map(), String.t()) :: map()
  def json_schema(schema, "3.0"), do: upgrade_nullable(schema)
  def json_schema(schema, _), do: schema

  # JSV consumes JSON Schema, not OpenAPI 3.0's nullable extension.
  defp upgrade_nullable(value) when is_map(value) do
    nullable = value["nullable"]

    value =
      Map.new(Map.delete(value, "nullable"), fn {key, item} -> {key, upgrade_nullable(item)} end)

    if nullable && value["type"], do: Map.update!(value, "type", &[&1, "null"]), else: value
  end

  defp upgrade_nullable(value) when is_list(value), do: Enum.map(value, &upgrade_nullable/1)
  defp upgrade_nullable(value), do: value
end
