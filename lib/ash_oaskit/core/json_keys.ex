defmodule AshOaskit.Core.JsonKeys do
  @moduledoc "Checks native JSON object names and string encodings before normalization."

  @doc """
  Returns the value unchanged, raising `ArgumentError` for duplicate JSON names
  or unsupported map keys. Object names and string values must be valid UTF-8.
  Atom, string, and integer keys are accepted, but two
  keys that normalize to the same string are ambiguous even if their values match.
  No atoms are created and no values are encoded or decoded.
  """
  @spec validate!(term()) :: term()
  def validate!(value) do
    walk(value, [])
    value
  end

  defp walk(value, path) when is_struct(value), do: walk(Map.from_struct(value), path)

  defp walk(value, path) when is_map(value) do
    Enum.reduce(value, MapSet.new(), fn {key, child}, names ->
      name = json_name!(key, path)

      if MapSet.member?(names, name) do
        raise ArgumentError, "ambiguous JSON key #{inspect(name)} at #{location(path)}"
      end

      walk(child, [name | path])
      MapSet.put(names, name)
    end)
  end

  defp walk(value, path) when is_list(value) do
    value |> Enum.with_index() |> Enum.each(fn {child, index} -> walk(child, [index | path]) end)
  end

  defp walk(value, path) when is_binary(value), do: validate_utf8!(value, path)
  defp walk(_, _), do: :ok

  defp json_name!(key, path) when is_binary(key) do
    validate_utf8!(key, [key | path])
    key
  end

  defp json_name!(key, _) when is_atom(key), do: Atom.to_string(key)
  defp json_name!(key, _) when is_integer(key), do: Integer.to_string(key)

  defp json_name!(key, path),
    do: raise(ArgumentError, "invalid JSON key #{inspect(key)} at #{location(path)}")

  defp validate_utf8!(text, path) do
    unless String.valid?(text),
      do: raise(ArgumentError, "invalid UTF-8 JSON string at #{location(path)}")
  end

  defp location(path), do: "$" <> Enum.map_join(Enum.reverse(path), &"[#{inspect(&1)}]")
end
