defmodule AshOaskit.SchemaBuilder.EmbeddedInputSchemasTest do
  use ExUnit.Case, async: true

  alias AshOaskit.SchemaBuilder
  alias AshOaskit.SchemaBuilder.EmbeddedInputSchemas
  alias AshOaskit.Test.RequestContract.{Address, InputNode, Item, KeyedAddress}
  alias AshOaskit.TypeMapper

  test "nested embedded inputs terminate and retain separate output definitions" do
    for version <- ["3.0", "3.1"] do
      builder = SchemaBuilder.add_resource_schemas(SchemaBuilder.new(version: version), InputNode)
      components = builder |> SchemaBuilder.to_components() |> Jason.encode!() |> Jason.decode!()
      schemas = components["schemas"]
      assert schemas["InputNodeCreateInput"]["required"] == ["name"]
      refute Map.has_key?(schemas["InputNodeUpdateInput"], "required")
      assert schemas["Address"]["required"] == ["street", "city"]

      assert schemas["InputNodeCreateInput"]["properties"]["children"]["items"]["$ref"] ==
               "#/components/schemas/AddressCreateInput"

      validator =
        schemas["InputNodeCreateInput"]
        |> Map.put("components", components)
        |> AshOaskit.Test.SchemaValidation.json_schema(version)
        |> JSV.build!()

      assert {:ok, _} =
               JSV.validate(
                 %{"name" => "root", "children" => [%{"street" => "s", "city" => "c"}]},
                 validator
               )

      assert {:error, _} =
               JSV.validate(%{"name" => "root", "children" => [%{"unknown" => 1}]}, validator)
    end
  end

  test "input traversal deduplicates definitions and rejects ownership collisions" do
    field = %{type: Address, constraints: []}
    builder = EmbeddedInputSchemas.add_field(SchemaBuilder.new(), field, action_type: :update)
    assert EmbeddedInputSchemas.add_field(builder, field, action_type: :update) == builder

    assert_raise ArgumentError, ~r/shared by/, fn ->
      EmbeddedInputSchemas.add_field(builder, %{type: AshOaskit.Test.Address}, [])
    end
  end

  test "type mapping selects input actions and preserves output references in both versions" do
    for mapper <- [&TypeMapper.to_json_schema_30/2, &TypeMapper.to_json_schema_31/2] do
      field = %{type: Address, allow_nil?: false, constraints: [create_action: :from_city]}
      assert mapper.(field, []) == %{"$ref" => "#/components/schemas/Address"}

      assert mapper.(field, direction: :input) == %{
               "$ref" => "#/components/schemas/AddressFromCityInput"
             }

      assert %{"anyOf" => [_, %{"$ref" => "#/components/schemas/AddressUpdateInput"}]} =
               mapper.(field, direction: :input, action_type: :update)
    end
  end

  test "public embedded identities are accepted without duplicate JSON keys" do
    field = %{type: {:array, KeyedAddress}, constraints: []}
    builder = EmbeddedInputSchemas.add_field(SchemaBuilder.new(), field, action_type: :update)
    schemas = builder |> SchemaBuilder.to_components() |> AshOaskit.Core.JsonKeys.validate!()
    assert schemas.schemas["KeyedAddressUpdateInput"].properties["id"] == %{}
    refute "id" in Map.get(schemas.schemas["KeyedAddressUpdateInput"], :required, [])
  end

  test "required update attributes are unique, non-null and independent of response nullability" do
    for version <- ["3.0", "3.1"] do
      builder = SchemaBuilder.add_resource_schemas(SchemaBuilder.new(version: version), Item)
      input = builder.schemas["ItemRequireNoteInput"] |> Jason.encode!() |> Jason.decode!()
      assert input["required"] == ["note"]
      assert input["properties"]["note"]["type"] == "string"
      refute input["properties"]["note"]["nullable"]
      validator = JSV.build!(input)
      assert {:ok, _} = JSV.validate(%{"note" => "present"}, validator)
      assert {:error, _} = JSV.validate(%{"note" => nil}, validator)
      assert {:error, _} = JSV.validate(%{}, validator)

      output = builder.schemas["ItemAttributes"].properties.note
      assert output["nullable"] || "null" in output["type"]
    end
  end
end
