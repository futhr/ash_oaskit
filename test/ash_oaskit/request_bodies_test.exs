defmodule AshOaskit.RequestBodiesTest do
  @moduledoc false

  use ExUnit.Case, async: true

  test "required inputs cannot be bypassed by omitting their parent object" do
    spec = AshOaskit.spec(domains: [AshOaskit.Test.Blog])
    validator = request_validator(spec, "/posts")
    assert {:error, _} = JSV.validate(%{"data" => %{}}, validator)
    assert {:error, _} = JSV.validate(%{"data" => %{"attributes" => %{}}}, validator)

    assert {:ok, _} =
             JSV.validate(%{"data" => %{"attributes" => %{"title" => "Valid"}}}, validator)
  end

  test "defaults make non-null arguments optional, including the generic body itself" do
    spec = AshOaskit.spec(domains: [AshOaskit.Test.SchemaAuditDomain])
    input = spec["components"]["schemas"]["SchemaAuditCreateInput"]
    refute "mode" in input["required"]
    assert input["properties"]["mode"]["default"] == "standard"

    spec = AshOaskit.spec(domains: [AshOaskit.Test.Workshop])
    assert {:ok, _} = JSV.validate(%{}, request_validator(spec, "/gadgets/{id}/activate"))
    refute spec["paths"]["/gadgets/{id}/activate"]["post"]["requestBody"]["required"]
  end

  test "relationship arguments have linkage schemas and required parent members" do
    spec = AshOaskit.spec(domains: [AshOaskit.Test.SchemaAuditDomain])
    validator = request_validator(spec, "/schema-audit/relate")
    valid = %{"data" => %{"relationships" => %{"author" => %{"data" => %{"id" => "author-id"}}}}}
    assert {:ok, _} = JSV.validate(valid, validator)
    assert {:error, _} = JSV.validate(%{"data" => %{}}, validator)
    assert {:error, _} = JSV.validate(%{"data" => %{"relationships" => %{}}}, validator)

    assert {:error, _} =
             JSV.validate(put_in(valid, ["data", "relationships", "author"], %{}), validator)
  end

  defp request_validator(spec, path) do
    spec["paths"][path]["post"]["requestBody"]["content"]["application/vnd.api+json"]["schema"]
    |> Map.put("components", spec["components"])
    |> JSV.build!()
  end

  setup_all do
    {:ok,
     blog: AshOaskit.spec_31(domains: [AshOaskit.Test.Blog]),
     workshop: AshOaskit.spec_31(domains: [AshOaskit.Test.Workshop])}
  end

  describe "POST request bodies" do
    test "reference the action input schema, not the response attributes", %{blog: spec} do
      schema =
        spec["paths"]["/posts"]["post"]["requestBody"]["content"]["application/vnd.api+json"][
          "schema"
        ]

      attributes = schema["properties"]["data"]["properties"]["attributes"]

      assert attributes["$ref"] == "#/components/schemas/PostCreateInput"
    end

    test "require the data member", %{blog: spec} do
      schema =
        spec["paths"]["/posts"]["post"]["requestBody"]["content"]["application/vnd.api+json"][
          "schema"
        ]

      assert schema["required"] == ["data"]
    end

    test "document the JSON:API type as an enum", %{blog: spec} do
      schema =
        spec["paths"]["/posts"]["post"]["requestBody"]["content"]["application/vnd.api+json"][
          "schema"
        ]

      type_member = schema["properties"]["data"]["properties"]["type"]

      assert type_member["enum"] == ["post"]
    end
  end

  describe "PATCH request bodies" do
    test "require the id member in data", %{blog: spec} do
      schema =
        spec["paths"]["/posts/{id}"]["patch"]["requestBody"]["content"][
          "application/vnd.api+json"
        ]["schema"]

      data = schema["properties"]["data"]

      assert data["required"] == ["id"]
      assert data["properties"]["id"]["type"] == "string"
    end

    test "reference the update action input schema", %{blog: spec} do
      schema =
        spec["paths"]["/posts/{id}"]["patch"]["requestBody"]["content"][
          "application/vnd.api+json"
        ]["schema"]

      attributes = schema["properties"]["data"]["properties"]["attributes"]

      assert attributes["$ref"] == "#/components/schemas/PostUpdateInput"
    end
  end

  describe "generic route request bodies" do
    test "post-method generic routes wrap the input in data", %{workshop: spec} do
      schema =
        spec["paths"]["/gadgets/{id}/activate"]["post"]["requestBody"]["content"][
          "application/vnd.api+json"
        ]["schema"]

      refute Map.has_key?(schema, "required")
      assert schema["properties"]["data"]["$ref"] == "#/components/schemas/GadgetActivateInput"
    end

    test "get-method generic routes have no request body", %{workshop: spec} do
      refute Map.has_key?(spec["paths"]["/gadgets/search"]["get"], "requestBody")
    end
  end

  describe "input schema components" do
    test "input properties match the action accept list", %{blog: spec} do
      properties = spec["components"]["schemas"]["PostCreateInput"]["properties"]

      assert properties |> Map.keys() |> Enum.sort() ==
               ~w(body is_featured status tags title)

      # email is public and writable but not accepted by :create
      refute Map.has_key?(properties, "email")
    end

    test "create input requires non-nil attributes without defaults", %{blog: spec} do
      assert spec["components"]["schemas"]["PostCreateInput"]["required"] == ["title"]
    end

    test "update input has no required fields", %{blog: spec} do
      refute Map.has_key?(spec["components"]["schemas"]["PostUpdateInput"], "required")
    end

    test "every input component is referenced by an operation (no orphans)", %{blog: spec} do
      input_components =
        spec["components"]["schemas"]
        |> Map.keys()
        |> Enum.filter(&String.ends_with?(&1, "Input"))
        |> MapSet.new()

      referenced =
        spec["paths"]
        |> inspect(limit: :infinity, printable_limit: :infinity)
        |> then(&Regex.scan(~r{#/components/schemas/(\w+Input)}, &1))
        |> Enum.map(fn [_, name] -> name end)
        |> MapSet.new()

      orphans = MapSet.to_list(MapSet.difference(input_components, referenced))

      assert MapSet.equal?(input_components, referenced),
             "orphaned inputs: #{inspect(orphans)}"
    end

    test "generic action inputs document public arguments", %{workshop: spec} do
      properties = spec["components"]["schemas"]["GadgetActivateInput"]["properties"]

      # nullable argument: type array in 3.1
      assert properties["force"]["type"] == ["boolean", "null"]
    end
  end

  describe "spec validity" do
    test "3.1 specs with action inputs pass Oaskit validation", %{blog: spec} do
      assert {:ok, %Oaskit.Spec.OpenAPI{}} = AshOaskit.validate(spec)
    end

    test "3.0 specs with action inputs pass Oaskit validation" do
      spec = AshOaskit.spec_30(domains: [AshOaskit.Test.Blog])

      assert {:ok, %Oaskit.Spec.OpenAPI{}} = AshOaskit.validate(spec)
    end
  end
end
