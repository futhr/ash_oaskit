defmodule AshOaskit.Core.PathRegistryTest do
  use ExUnit.Case, async: true
  alias AshOaskit.Core.PathRegistry

  test "bulk construction preserves operations and rejects conflicting templates and values" do
    entries = [
      {"/items/{id}", "get", %{operationId: "get"}},
      {"/items/{id}", "post", %{operationId: "post"}},
      {"/health", "get", %{operationId: "health"}}
    ]

    expected = Enum.reduce(entries, %{}, fn {p, m, o}, acc -> PathRegistry.put(acc, p, m, o) end)
    assert PathRegistry.from_operations(entries) === expected
    assert PathRegistry.from_operations(Enum.reverse(entries) ++ entries) === expected
    assert PathRegistry.from_operations([]) == %{}
    assert PathRegistry.merge(%{"/empty" => %{}}, %{}) == %{"/empty" => %{}}

    for build <- [
          &PathRegistry.from_operations/1,
          fn es ->
            Enum.reduce(es, %{}, fn {p, m, o}, acc -> PathRegistry.put(acc, p, m, o) end)
          end
        ] do
      assert_raise ArgumentError, ~r/path templates/, fn ->
        build.(entries ++ [{"/items/{name}", "delete", %{}}])
      end

      assert_raise ArgumentError, ~r/Conflicting OpenAPI operations/, fn ->
        build.([{"/numeric", "get", %{example: 1}}, {"/numeric", "get", %{example: 1.0}}])
      end
    end
  end

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

  test "explicit identifiers keep their value and generated collisions are suffixed" do
    paths = %{
      "/named" => %{"post" => %{operationId: "sign_out"}},
      "/generated" => %{"post" => %{operationId: "sign_out"}}
    }

    unique = PathRegistry.disambiguate(paths, [{"/named", "post"}])

    assert unique["/named"]["post"].operationId == "sign_out"
    assert unique["/generated"]["post"].operationId =~ ~r/^sign_out_[0-9a-f]{16}$/
    assert unique == PathRegistry.validate_ids!(unique)
  end

  test "duplicate explicit identifiers are kept for validation to reject" do
    paths = %{
      "/one" => %{"get" => %{operationId: "me"}},
      "/two" => %{"get" => %{operationId: "me"}}
    }

    explicit = [{"/one", "get"}, {"/two", "get"}]
    assert PathRegistry.disambiguate(paths, explicit) == paths

    assert_raise ArgumentError, ~r/Duplicate operationId "me"/, fn ->
      paths |> PathRegistry.disambiguate(explicit) |> PathRegistry.validate_ids!()
    end
  end
end
