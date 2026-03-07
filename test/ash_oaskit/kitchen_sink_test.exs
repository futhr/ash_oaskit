defmodule AshOaskit.KitchenSinkTest do
  @moduledoc """
  Integration tests for edge-case types and features using the KitchenSink resource.

  Validates full pipeline output (AshOaskit.spec/1) for both OpenAPI 3.0 and 3.1,
  covering:

  - Union types (Ash.Type.NewType subtype of Ash.Type.Union)
  - Custom types with json_schema/1 callback
  - Deeply nested embedded resources (3 levels: Venue → Location → GeoPoint)
  - Array of embedded resources
  - Read-only attributes (writable?: false)
  - DurationName type
  - Input schema generation (create/update)
  - Embedded schema $ref generation
  """

  use ExUnit.Case, async: true

  @domains [AshOaskit.Test.Lab]

  setup_all do
    spec_31 = AshOaskit.spec(domains: @domains, version: "3.1")
    spec_30 = AshOaskit.spec(domains: @domains, version: "3.0")
    %{spec_31: spec_31, spec_30: spec_30}
  end

  describe "schema generation" do
    test "generates all expected component schemas", %{spec_31: spec} do
      schema_names = spec["components"]["schemas"] |> Map.keys() |> Enum.sort()

      assert "KitchenSinkAttributes" in schema_names
      assert "KitchenSinkResponse" in schema_names
      assert "KitchenSinkCreateInput" in schema_names
      assert "KitchenSinkUpdateInput" in schema_names
      assert "Venue" in schema_names
      assert "Location" in schema_names
      assert "GeoPoint" in schema_names
    end

    test "generates same schema names for both versions", %{spec_31: s31, spec_30: s30} do
      names_31 = s31["components"]["schemas"] |> Map.keys() |> Enum.sort()
      names_30 = s30["components"]["schemas"] |> Map.keys() |> Enum.sort()
      assert names_31 == names_30
    end
  end

  describe "union type attribute (content)" do
    test "3.1 uses anyOf with null and typed variants", %{spec_31: spec} do
      content = get_attr(spec, "content")
      assert %{"anyOf" => variants} = content
      assert length(variants) == 4, "Expected 4 variants (null + 3 union types)"

      titles = variants |> Enum.map(&Map.get(&1, "title")) |> Enum.reject(&is_nil/1)
      assert "text" in titles
      assert "image" in titles
      assert "code" in titles

      null_variant = Enum.find(variants, &(&1["type"] == "null"))
      assert null_variant, "Expected null variant for nullable union"
    end

    test "3.0 uses anyOf with nullable flag", %{spec_30: spec} do
      content = get_attr(spec, "content")
      assert %{"anyOf" => _} = content
      assert content["nullable"] == true
    end
  end

  describe "custom type with json_schema/1 (coordinates)" do
    test "3.1 uses custom schema with lat/lng properties", %{spec_31: spec} do
      coords = get_attr(spec, "coordinates")
      assert coords["properties"]["lat"]["type"] == "number"
      assert coords["properties"]["lng"]["type"] == "number"
      assert coords["required"] == ["lat", "lng"]
    end

    test "3.1 nullable wraps type in array", %{spec_31: spec} do
      coords = get_attr(spec, "coordinates")
      assert coords["type"] == ["object", "null"]
    end

    test "3.0 nullable uses flag", %{spec_30: spec} do
      coords = get_attr(spec, "coordinates")
      assert coords["nullable"] == true
      assert coords["type"] == "object"
    end
  end

  describe "deeply nested embedded resources" do
    test "venue references Venue via $ref (3.1)", %{spec_31: spec} do
      venue_attr = get_attr(spec, "venue")
      assert %{"oneOf" => [%{"type" => "null"}, %{"$ref" => ref}]} = venue_attr
      assert ref == "#/components/schemas/Venue"
    end

    test "venue references Venue via $ref (3.0)", %{spec_30: spec} do
      venue_attr = get_attr(spec, "venue")
      assert venue_attr["nullable"] == true
    end

    test "Venue schema references Location", %{spec_31: spec} do
      venue = spec["components"]["schemas"]["Venue"]
      assert venue["properties"]["location"]["$ref"] == "#/components/schemas/Location"
      assert "location" in venue["required"]
    end

    test "Location schema references GeoPoint", %{spec_31: spec} do
      location = spec["components"]["schemas"]["Location"]
      assert location["properties"]["geo"]["$ref"] == "#/components/schemas/GeoPoint"
      assert "geo" in location["required"]
    end

    test "GeoPoint has lat/lng with constraints", %{spec_31: spec} do
      geo = spec["components"]["schemas"]["GeoPoint"]
      assert geo["type"] == "object"

      lat = geo["properties"]["lat"]
      assert lat["type"] == "number"
      assert lat["minimum"] == -90.0
      assert lat["maximum"] == 90.0

      lng = geo["properties"]["lng"]
      assert lng["type"] == "number"
      assert lng["minimum"] == -180.0
      assert lng["maximum"] == 180.0

      assert "lat" in geo["required"]
      assert "lng" in geo["required"]
    end
  end

  describe "array of embedded resources (locations)" do
    test "3.1 generates array with $ref items", %{spec_31: spec} do
      locations = get_attr(spec, "locations")
      assert locations["items"]["$ref"] == "#/components/schemas/Location"
    end

    test "3.1 nullable array uses type array", %{spec_31: spec} do
      locations = get_attr(spec, "locations")
      assert locations["type"] == ["array", "null"]
    end

    test "3.0 generates array with $ref items and nullable flag", %{spec_30: spec} do
      locations = get_attr(spec, "locations")
      assert locations["items"]["$ref"] == "#/components/schemas/Location"
      assert locations["type"] == "array"
      assert locations["nullable"] == true
    end
  end

  describe "duration_name type (billing_unit)" do
    test "generates string with enum of all duration units", %{spec_31: spec} do
      billing = get_attr(spec, "billing_unit")

      expected_units =
        ~w(year month week day hour minute second millisecond microsecond nanosecond)

      for unit <- expected_units do
        assert unit in billing["enum"], "Expected #{unit} in billing_unit enum"
      end
    end

    test "3.1 nullable uses type array", %{spec_31: spec} do
      billing = get_attr(spec, "billing_unit")
      assert billing["type"] == ["string", "null"]
    end

    test "3.0 uses nullable flag", %{spec_30: spec} do
      billing = get_attr(spec, "billing_unit")
      assert billing["type"] == "string"
      assert billing["nullable"] == true
    end
  end

  describe "read-only attribute (slug)" do
    test "appears in attributes schema", %{spec_31: spec} do
      slug = get_attr(spec, "slug")
      assert slug, "slug should appear in output attributes"
    end

    test "excluded from create input", %{spec_31: spec} do
      create = spec["components"]["schemas"]["KitchenSinkCreateInput"]
      refute Map.has_key?(create["properties"], "slug")
    end

    test "excluded from update input", %{spec_31: spec} do
      update = spec["components"]["schemas"]["KitchenSinkUpdateInput"]
      refute Map.has_key?(update["properties"], "slug")
    end
  end

  describe "input schemas" do
    test "create input has writable attributes", %{spec_31: spec} do
      create = spec["components"]["schemas"]["KitchenSinkCreateInput"]
      props = Map.keys(create["properties"])

      assert "name" in props
      assert "content" in props
      assert "coordinates" in props
      assert "venue" in props
      assert "locations" in props
      assert "billing_unit" in props
    end

    test "update input has writable attributes", %{spec_31: spec} do
      update = spec["components"]["schemas"]["KitchenSinkUpdateInput"]
      props = Map.keys(update["properties"])

      assert "name" in props
      assert "content" in props
      assert "venue" in props
    end

    test "name is required in create input", %{spec_31: spec} do
      create = spec["components"]["schemas"]["KitchenSinkCreateInput"]
      assert "name" in (create["required"] || [])
    end
  end

  describe "cross-version consistency" do
    test "both versions have same attributes", %{spec_31: s31, spec_30: s30} do
      attrs_31 = Map.keys(s31["components"]["schemas"]["KitchenSinkAttributes"]["properties"])
      attrs_30 = Map.keys(s30["components"]["schemas"]["KitchenSinkAttributes"]["properties"])
      assert Enum.sort(attrs_31) == Enum.sort(attrs_30)
    end

    test "3.0 never uses type arrays", %{spec_30: spec} do
      walk_schemas(spec, fn _, schema ->
        if is_map(schema) and Map.has_key?(schema, "type") do
          refute is_list(schema["type"]),
                 "3.0 must not use type arrays, found: #{inspect(schema["type"])}"
        end
      end)
    end

    test "3.1 never uses nullable flag", %{spec_31: spec} do
      walk_schemas(spec, fn _, schema ->
        if is_map(schema) do
          refute Map.has_key?(schema, "nullable"),
                 "3.1 must not use nullable flag, found in: #{inspect(schema)}"
        end
      end)
    end
  end

  # --- Helpers ---

  defp get_attr(spec, name) do
    spec["components"]["schemas"]["KitchenSinkAttributes"]["properties"][name]
  end

  defp walk_schemas(spec, fun) do
    schemas = spec["components"]["schemas"]

    Enum.each(schemas, fn {name, schema} ->
      walk_value(name, schema, fun)
    end)
  end

  defp walk_value(path, value, fun) when is_map(value) do
    fun.(path, value)

    Enum.each(value, fn {k, v} ->
      walk_value("#{path}.#{k}", v, fun)
    end)
  end

  defp walk_value(path, value, fun) when is_list(value) do
    Enum.with_index(value, fn v, i ->
      walk_value("#{path}[#{i}]", v, fun)
    end)
  end

  defp walk_value(_, _, _), do: :ok
end
