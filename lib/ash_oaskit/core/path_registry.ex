defmodule AshOaskit.Core.PathRegistry do
  @moduledoc "Conflict detection and stable operation identifiers for generated path maps."

  alias AshOaskit.Core.PathUtils

  @doc "Adds an operation, rejecting conflicting methods and equivalent path templates."
  @spec put(map(), String.t(), String.t(), map()) :: map()
  def put(paths, path, method, operation) do
    shape = PathUtils.template_shape(path)

    equivalent =
      Enum.find(Map.keys(paths), &(&1 != path and PathUtils.template_shape(&1) == shape))

    if equivalent,
      do: raise(ArgumentError, "Conflicting OpenAPI path templates: #{equivalent} and #{path}")

    put_method(paths, path, method, operation)
  end

  @doc "Builds a path map with one template-shape lookup per operation."
  @spec from_operations(Enumerable.t()) :: map()
  def from_operations(operations) do
    build_operations(operations, %{}, %{})
  end

  defp build_operations(operations, paths, index) do
    {paths, _index} =
      Enum.reduce(operations, {paths, index}, fn {path, method, operation}, {paths, index} ->
        index = index_path!(index, path)
        {put_method(paths, path, method, operation), index}
      end)

    paths
  end

  defp index_path!(index, path) do
    shape = PathUtils.template_shape(path)

    case Map.fetch(index, shape) do
      :error ->
        Map.put(index, shape, path)

      {:ok, ^path} ->
        index

      {:ok, equivalent} ->
        raise ArgumentError, "Conflicting OpenAPI path templates: #{equivalent} and #{path}"
    end
  end

  defp put_method(paths, path, method, operation) do
    Map.update(paths, path, %{method => operation}, fn methods ->
      case Map.fetch(methods, method) do
        :error ->
          Map.put(methods, method, operation)

        {:ok, ^operation} ->
          methods

        {:ok, _} ->
          raise ArgumentError,
                "Conflicting OpenAPI operations for #{String.upcase(method)} #{path}"
      end
    end)
  end

  @doc "Merges path maps without silently replacing operations."
  @spec merge(map(), map()) :: map()
  def merge(left, right) do
    index = Enum.reduce(Map.keys(left), %{}, &index_path!(&2, &1))

    right
    |> Stream.flat_map(fn {path, methods} ->
      Enum.map(methods, fn {method, operation} -> {path, method, operation} end)
    end)
    |> build_operations(left, index)
  end

  @doc "Disambiguates generated identifiers with a deterministic method/path suffix."
  @spec disambiguate(map()) :: map()
  def disambiguate(paths) do
    counts = paths |> operations() |> Enum.frequencies_by(fn {_, _, op} -> op[:operationId] end)

    Map.new(paths, fn {path, methods} ->
      {path,
       Map.new(methods, fn {method, op} ->
         id = op[:operationId]

         op =
           if id && counts[id] > 1,
             do: Map.put(op, :operationId, id <> "_" <> suffix(method, path)),
             else: op

         {method, op}
       end)}
    end)
  end

  @doc "Checks global operationId uniqueness, including explicit controller identifiers."
  @spec validate_ids!(map()) :: map()
  def validate_ids!(paths) do
    _ =
      Enum.reduce(operations(paths), %{}, fn {path, method, op}, seen ->
        id = op[:operationId] || op["operationId"]

        if id && Map.has_key?(seen, id),
          do: raise(ArgumentError, "Duplicate operationId #{inspect(id)} at #{method} #{path}")

        if id, do: Map.put(seen, id, true), else: seen
      end)

    paths
  end

  @doc "Returns a stable identifier suffix for a method and served path."
  @spec suffix(atom() | String.t(), String.t()) :: String.t()
  def suffix(method, path),
    do:
      :sha256
      |> :crypto.hash("#{method} #{path}")
      |> Base.encode16(case: :lower)
      |> binary_part(0, 16)

  defp operations(paths),
    do: for({path, methods} <- paths, {method, op} <- methods, is_map(op), do: {path, method, op})
end
