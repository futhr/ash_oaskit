defmodule AshOaskit.SchemaBuilder.PropertyBuildersTest do
  @moduledoc """
  Tests for the `AshOaskit.SchemaBuilder.PropertyBuilders` module.

  Verifies the conversion of Ash resource properties (attributes, calculations,
  aggregates) into OpenAPI JSON Schema property definitions.

  ## Test categories

    - `type_to_schema/1` — Ash type to JSON Schema mapping
    - `normalize_type/1` — Ash.Type.* module to atom normalization
    - `build_attribute_properties/2` — Attribute property generation
    - `build_calculation_properties/2` — Calculation property generation (always nullable)
    - `build_aggregate_properties/2` — Aggregate property generation by kind
    - `aggregate_kind_to_schema/2` — Aggregate kind to schema mapping
    - `maybe_add_description/2` — Optional description merging
  """
  use ExUnit.Case, async: true

  alias AshOaskit.SchemaBuilder.PropertyBuilders

  doctest AshOaskit.SchemaBuilder.PropertyBuilders

  describe "type_to_schema/1" do
    test "maps basic atom types" do
      assert PropertyBuilders.type_to_schema(:string) == %{type: :string}
      assert PropertyBuilders.type_to_schema(:integer) == %{type: :integer}
      assert PropertyBuilders.type_to_schema(:boolean) == %{type: :boolean}
    end

    test "maps types with formats" do
      assert PropertyBuilders.type_to_schema(:float) == %{type: :number, format: :float}
      assert PropertyBuilders.type_to_schema(:decimal) == %{type: :number, format: :double}
      assert PropertyBuilders.type_to_schema(:uuid) == %{type: :string, format: :uuid}

      assert PropertyBuilders.type_to_schema(:datetime) == %{
               type: :string,
               format: :"date-time"
             }
    end

    test "maps array types" do
      assert PropertyBuilders.type_to_schema({:array, :string}) == %{
               type: :array,
               items: %{type: :string}
             }
    end

    test "maps nested array types" do
      assert PropertyBuilders.type_to_schema({:array, {:array, :integer}}) == %{
               type: :array,
               items: %{type: :array, items: %{type: :integer}}
             }
    end

    test "maps term to empty schema" do
      assert PropertyBuilders.type_to_schema(:term) == %{}
    end

    test "maps map to object" do
      assert PropertyBuilders.type_to_schema(:map) == %{type: :object}
    end

    test "defaults unknown types to string" do
      assert PropertyBuilders.type_to_schema(:unknown_type) == %{type: :string}
    end
  end

  describe "normalize_type/1" do
    test "normalizes Ash.Type modules to atoms" do
      assert PropertyBuilders.normalize_type(Ash.Type.String) == :string
      assert PropertyBuilders.normalize_type(Ash.Type.Integer) == :integer
      assert PropertyBuilders.normalize_type(Ash.Type.Boolean) == :boolean
      assert PropertyBuilders.normalize_type(Ash.Type.UUID) == :uuid
    end

    test "passes through atom types unchanged" do
      assert PropertyBuilders.normalize_type(:string) == :string
      assert PropertyBuilders.normalize_type(:integer) == :integer
    end
  end

  describe "build_attribute_properties/2" do
    test "builds properties from attributes using 3.1 type mapper" do
      builder = %{version: "3.1"}

      attrs = [
        %{name: :title, type: :string, allow_nil?: false, constraints: []},
        %{name: :count, type: :integer, allow_nil?: true, constraints: []}
      ]

      props = PropertyBuilders.build_attribute_properties(builder, attrs)

      assert Map.has_key?(props, :title)
      assert Map.has_key?(props, :count)
    end

    test "builds properties using 3.0 type mapper" do
      builder = %{version: "3.0"}

      attrs = [
        %{name: :name, type: :string, allow_nil?: true, constraints: []}
      ]

      props = PropertyBuilders.build_attribute_properties(builder, attrs)

      assert Map.has_key?(props, :name)
    end
  end

  describe "build_calculation_properties/2" do
    test "builds nullable calculation properties" do
      builder = %{version: "3.1"}

      calcs = [
        %{name: :full_name, type: :string}
      ]

      props = PropertyBuilders.build_calculation_properties(builder, calcs)

      assert Map.has_key?(props, :full_name)
      # Calculations are always nullable
      schema = props[:full_name]
      assert schema.type == [:string, :null] or Map.has_key?(schema, :nullable)
    end
  end

  describe "build_aggregate_properties/2" do
    test "builds aggregate properties with correct kind schemas" do
      builder = %{version: "3.1"}

      aggs = [
        %{name: :post_count, kind: :count, type: :integer}
      ]

      props = PropertyBuilders.build_aggregate_properties(builder, aggs)

      assert Map.has_key?(props, :post_count)
    end
  end

  describe "aggregate_kind_to_schema/2" do
    test "count produces integer schema" do
      assert PropertyBuilders.aggregate_kind_to_schema(:count, %{}) == %{type: :integer}
    end

    test "exists produces boolean schema" do
      assert PropertyBuilders.aggregate_kind_to_schema(:exists, %{}) == %{type: :boolean}
    end

    test "sum produces number schema" do
      assert PropertyBuilders.aggregate_kind_to_schema(:sum, %{}) == %{type: :number}
    end

    test "avg produces number schema" do
      assert PropertyBuilders.aggregate_kind_to_schema(:avg, %{}) == %{type: :number}
    end

    test "list produces array schema" do
      schema = PropertyBuilders.aggregate_kind_to_schema(:list, %{type: :string})
      assert schema.type == :array
      assert schema.items == %{type: :string}
    end

    test "first uses aggregate type" do
      schema = PropertyBuilders.aggregate_kind_to_schema(:first, %{type: :integer})
      assert schema == %{type: :integer}
    end

    test "min/max default to number" do
      assert PropertyBuilders.aggregate_kind_to_schema(:min, %{}) == %{type: :number}
      assert PropertyBuilders.aggregate_kind_to_schema(:max, %{}) == %{type: :number}
    end
  end

  describe "maybe_add_description/2" do
    test "adds description when present" do
      schema = %{type: :string}
      result = PropertyBuilders.maybe_add_description(schema, %{description: "A name"})

      assert result.description == "A name"
    end

    test "skips nil description" do
      schema = %{type: :string}
      result = PropertyBuilders.maybe_add_description(schema, %{description: nil})

      refute Map.has_key?(result, :description)
    end

    test "skips when no description key" do
      schema = %{type: :string}
      result = PropertyBuilders.maybe_add_description(schema, %{})

      refute Map.has_key?(result, :description)
    end
  end
end
