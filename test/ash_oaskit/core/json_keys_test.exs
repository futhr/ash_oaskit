defmodule AshOaskit.Core.JsonKeysTest do
  use ExUnit.Case, async: true
  alias AshOaskit.Core.JsonKeys

  defmodule AmbiguousType do
    @spec json_schema(term()) :: map()
    def json_schema(_), do: %{:type => "string", "type" => "integer"}
  end

  test "custom type callbacks reject ambiguity before calculation schema conversion" do
    assert_raise ArgumentError, ~r/ambiguous JSON key "type".*attribute :payload/, fn ->
      AshOaskit.SchemaBuilder.PropertyBuilders.calculation_to_schema(%{version: "3.1"}, %{
        name: :payload,
        type: AmbiguousType,
        allow_nil?: false
      })
    end
  end

  test "preserves native values and supported structured values without serialization" do
    value = %{"values" => [nil, true, false, 1, 1.0, "1", [], %{}], atom: ~D[2026-09-11]}
    assert JsonKeys.validate!(value) === value
    assert JsonKeys.validate!(%{200 => %{description: "OK"}}) === %{200 => %{description: "OK"}}
  end

  test "rejects all ambiguous aliases, including equal and numerically equivalent values" do
    for value <- [
          %{:name => 1, "name" => 2},
          %{:name => 1, "name" => 1},
          %{:name => 1, "name" => 1.0},
          %{200 => true, "200" => false}
        ] do
      assert_raise ArgumentError, ~r/ambiguous JSON key/, fn -> JsonKeys.validate!(value) end
    end
  end

  test "reports nested object and array locations" do
    assert_raise ArgumentError, ~r/\$\["payload"\]\[0\]/, fn ->
      JsonKeys.validate!(%{payload: [%{:name => 1, "name" => 2}]})
    end
  end

  test "rejects unsupported map keys" do
    for key <- [{:tuple}, 1.0] do
      assert_raise ArgumentError, ~r/invalid JSON key/, fn ->
        JsonKeys.validate!(%{key => true})
      end
    end
  end

  test "generation rejects ambiguous options and preserves native extension values" do
    for version <- ["3.0", "3.1"] do
      opts = [domains: [AshOaskit.Test.SimpleDomain], version: version]

      assert_raise ArgumentError, ~r/ambiguous JSON key "name"/, fn ->
        AshOaskit.spec(opts ++ [contact: %{:name => "atom", "name" => "string"}])
      end

      value = %{"data" => [nil, true, false, 1, 1.0, "1"]}
      spec = AshOaskit.spec(opts ++ [modify_open_api: &Map.put(&1, "x-values", value)])
      assert spec["x-values"] === value
      assert Jason.decode!(Jason.encode!(spec))["x-values"] === value
    end
  end

  test "modifiers reject ambiguity before Oaskit can erase it" do
    spec = %{openapi: "3.1.0", info: %{:title => "one", "title" => "two"}}

    assert_raise ArgumentError, ~r/ambiguous JSON key "title"/, fn ->
      AshOaskit.SpecModifier.add_server(spec, "/")
    end
  end

  test "defaults cannot hide ambiguous keys" do
    assert_raise ArgumentError, ~r/ambiguous JSON key/, fn ->
      AshOaskit.TypeMapper.to_json_schema_31(%{
        name: :payload,
        type: :map,
        default: %{:key => 1, "key" => 2}
      })
    end
  end
end
