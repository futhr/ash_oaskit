defmodule AshOaskit.Schemas.References do
  @moduledoc "Checks local component pointers without interpreting literal JSON data as schemas."

  @schema_maps ~w(properties patternProperties $defs definitions dependentSchemas)
  @schema_lists ~w(allOf anyOf oneOf prefixItems)
  @schema_values ~w(items additionalItems additionalProperties unevaluatedItems unevaluatedProperties contains propertyNames not if then else)

  @doc """
  Checks local `#/components/schemas/` references in an OpenAPI document or schema.
  Examples, defaults, constants, enums, and extension payloads are literal data.
  External references and anchors are left to the caller's full schema validator.
  """
  @spec validate!(term(), map()) :: :ok
  def validate!(document, schemas) do
    missing =
      document
      |> collect(root_mode(document), MapSet.new())
      |> Enum.reject(&resolves?(schemas, &1))
      |> Enum.sort()

    if missing != [] do
      raise ArgumentError,
            "OpenAPI schemas contain missing local component references: " <>
              Enum.join(missing, ", ")
    end

    :ok
  end

  defp root_mode(document) when is_map(document) do
    if Map.has_key?(document, :openapi) or Map.has_key?(document, "openapi"),
      do: :object,
      else: :schema
  end

  defp root_mode(_), do: :schema

  defp collect(value, mode, refs) when is_struct(value),
    do: collect(Map.from_struct(value), mode, refs)

  defp collect(value, :schema_map, refs) when is_map(value),
    do: Enum.reduce(value, refs, fn {_, child}, acc -> collect(child, :schema, acc) end)

  defp collect(value, mode, refs) when is_map(value) do
    Enum.reduce(value, refs, fn {key, child}, acc ->
      collect_field(to_string(key), child, mode, acc)
    end)
  end

  defp collect(value, mode, refs) when is_list(value),
    do: Enum.reduce(value, refs, &collect(&1, mode, &2))

  defp collect(_, _, refs), do: refs

  defp collect_field("$ref", "#/components/schemas/" <> pointer, _, refs),
    do: MapSet.put(refs, pointer)

  defp collect_field(key, _, _, refs) when key in ~w(example default enum const value), do: refs
  defp collect_field("examples", _, :schema, refs), do: refs
  defp collect_field("x-" <> _, _, _, refs), do: refs

  defp collect_field(key, value, _, refs) when key in @schema_maps or key == "schemas",
    do: collect(value, :schema_map, refs)

  defp collect_field(key, value, _, refs)
       when key in @schema_lists or key in @schema_values or key == "schema",
       do: collect(value, :schema, refs)

  defp collect_field(_, value, mode, refs), do: collect(value, mode, refs)

  defp resolves?(schemas, pointer) do
    valid_encoding? = not Regex.match?(~r/%(?![0-9a-fA-F]{2})/, pointer)
    pointer = URI.decode(pointer)

    if valid_encoding? and String.valid?(pointer) and not Regex.match?(~r/~(?:[^01]|$)/, pointer) do
      segments = pointer |> String.split("/") |> Enum.map(&unescape/1)
      resolve(schemas, segments) != :error
    else
      false
    end
  end

  defp unescape(segment), do: segment |> String.replace("~1", "/") |> String.replace("~0", "~")
  defp resolve(value, []), do: {:ok, value}

  defp resolve(value, [segment | rest]) when is_map(value) do
    case fetch_key(value, segment) do
      {:ok, child} -> resolve(child, rest)
      :error -> :error
    end
  end

  defp resolve(value, [segment | rest]) when is_list(value) do
    with true <- Regex.match?(~r/^(0|[1-9][0-9]*)$/, segment),
         {index, ""} <- Integer.parse(segment),
         {:ok, child} <- Enum.fetch(value, index) do
      resolve(child, rest)
    else
      _ -> :error
    end
  end

  defp resolve(_, _), do: :error

  defp fetch_key(map, key) do
    case Map.fetch(map, key) do
      :error -> fetch_native_key(map, key)
      found -> found
    end
  end

  defp fetch_native_key(map, key) do
    case Integer.parse(key) do
      {integer, ""} -> fetch_integer_key(map, key, integer)
      _ -> fetch_atom_key(map, key)
    end
  end

  defp fetch_integer_key(map, key, integer) do
    if Integer.to_string(integer) == key and Map.has_key?(map, integer),
      do: Map.fetch(map, integer),
      else: fetch_atom_key(map, key)
  end

  defp fetch_atom_key(map, key) do
    Map.fetch(map, String.to_existing_atom(key))
  rescue
    ArgumentError -> :error
  end
end
