defmodule AshOaskit.Core.PathRegistryTest do
  use ExUnit.Case, async: true
  alias AshOaskit.Core.PathRegistry

  test "rejects conflicting operations and equivalent parameter templates" do
    paths = PathRegistry.put(%{}, "/items/{id}", "get", %{operationId: "get_item"})
    assert PathRegistry.merge(paths, paths) == paths

    assert_raise ArgumentError, ~r/Conflicting OpenAPI operations/, fn ->
      PathRegistry.put(paths, "/items/{id}", "get", %{operationId: "other"})
    end

    assert_raise ArgumentError, ~r/path templates/, fn ->
      PathRegistry.put(paths, "/items/{name}", "post", %{})
    end
  end

  test "generated identifiers are stable and unique across routes for one action" do
    paths = %{
      "/one" => %{"get" => %{operationId: "read"}},
      "/two" => %{"get" => %{operationId: "read"}}
    }

    assert_raise ArgumentError, ~r/Duplicate operationId/, fn ->
      PathRegistry.validate_ids!(paths)
    end

    unique = PathRegistry.disambiguate(paths)
    assert unique == paths |> Enum.reverse() |> Map.new() |> PathRegistry.disambiguate()
    assert unique == PathRegistry.validate_ids!(unique)
    refute unique["/one"]["get"].operationId == unique["/two"]["get"].operationId
  end
end
