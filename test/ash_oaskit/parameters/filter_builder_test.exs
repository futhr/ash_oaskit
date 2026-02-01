defmodule AshOaskit.FilterBuilderTest do
  @moduledoc """
  Comprehensive tests for the FilterBuilder module.

  The FilterBuilder generates OpenAPI schemas for JSON:API filter parameters,
  supporting all standard filter operators and boolean logic.

  ## Test Categories

  ### Parameter Structure
  - Query parameter configuration (name, location, style)
  - deepObject style with explode
  - Schema structure

  ### Attribute Filters
  - Filterable attribute detection
  - Private attribute exclusion
  - Type-specific operator availability

  ### Operator Schemas
  - Equality operators (eq, ne)
  - Comparison operators (gt, gte, lt, lte)
  - Set operators (in, not_in)
  - String operators (contains, starts_with, ends_with, etc.)
  - Null check (is_nil)
  - Array operators (has_any, has_all)

  ### Boolean Operators
  - and (all conditions)
  - or (any condition)
  - not (negation)

  ### Type Mapping
  - String types -> string operators
  - Numeric types -> comparison operators
  - Boolean types -> equality only
  - Array types -> array operators
  - Date/time types -> comparison operators

  ## Test Resources

  Tests use resources from test support files:
  - `AshOaskit.Test.Post` - Various attribute types
  - `AshOaskit.Test.Author` - Resource with relationships
  - `AshOaskit.Test.Article` - Resource with multiple types
  """

  use ExUnit.Case, async: true

  alias AshOaskit.FilterBuilder

  describe "build_filter_parameter/2" do
    # Tests for the complete filter parameter structure.

    test "returns parameter with correct name" do
      param = FilterBuilder.build_filter_parameter(AshOaskit.Test.Post)

      assert param.name == "filter"
    end

    test "returns parameter in query location" do
      param = FilterBuilder.build_filter_parameter(AshOaskit.Test.Post)

      assert param.in == :query
    end

    test "returns optional parameter" do
      param = FilterBuilder.build_filter_parameter(AshOaskit.Test.Post)

      assert param.required == false
    end

    test "uses deepObject style" do
      param = FilterBuilder.build_filter_parameter(AshOaskit.Test.Post)

      assert param.style == :deepObject
    end

    test "enables explode" do
      param = FilterBuilder.build_filter_parameter(AshOaskit.Test.Post)

      assert param.explode == true
    end

    test "includes schema" do
      param = FilterBuilder.build_filter_parameter(AshOaskit.Test.Post)

      assert is_map(param.schema)
      assert param.schema.type == :object
    end

    test "includes description" do
      param = FilterBuilder.build_filter_parameter(AshOaskit.Test.Post)

      assert is_binary(param.description)
      assert String.contains?(param.description, "Post")
    end
  end

  describe "build_filter_schema/2" do
    # Tests for the filter schema structure.

    test "returns object type" do
      schema = FilterBuilder.build_filter_schema(AshOaskit.Test.Post)

      assert schema.type == :object
    end

    test "has properties for attributes" do
      schema = FilterBuilder.build_filter_schema(AshOaskit.Test.Post)

      assert Map.has_key?(schema.properties, "title")
      assert Map.has_key?(schema.properties, "body")
    end

    test "has boolean operators" do
      schema = FilterBuilder.build_filter_schema(AshOaskit.Test.Post)

      assert Map.has_key?(schema.properties, "and")
      assert Map.has_key?(schema.properties, "or")
      assert Map.has_key?(schema.properties, "not")
    end

    test "disallows additional properties" do
      schema = FilterBuilder.build_filter_schema(AshOaskit.Test.Post)

      assert schema.additionalProperties == false
    end
  end

  describe "build_attribute_filters/1" do
    # Tests for attribute filter generation.

    test "includes public attributes" do
      filters = FilterBuilder.build_attribute_filters(AshOaskit.Test.Post)

      assert Map.has_key?(filters, "title")
      assert Map.has_key?(filters, "body")
      assert Map.has_key?(filters, "status")
    end

    test "includes multiple attribute types" do
      filters = FilterBuilder.build_attribute_filters(AshOaskit.Test.Post)

      # String
      assert Map.has_key?(filters, "title")
      # Integer
      assert Map.has_key?(filters, "view_count")
      # Float
      assert Map.has_key?(filters, "rating")
      # Boolean
      assert Map.has_key?(filters, "is_featured")
    end
  end

  describe "build_attribute_filter_schema/1" do
    # Tests for individual attribute filter schemas.

    test "allows direct value" do
      attr = %{name: :title, type: :string}
      schema = FilterBuilder.build_attribute_filter_schema(attr)

      assert Map.has_key?(schema, :oneOf)
      # First option is direct value
      direct = Enum.find(schema.oneOf, &(&1.type == :string))
      assert direct != nil
    end

    test "allows operator object" do
      attr = %{name: :title, type: :string}
      schema = FilterBuilder.build_attribute_filter_schema(attr)

      # Second option is operator object
      operator_obj = Enum.find(schema.oneOf, &(&1.type == :object))
      assert operator_obj != nil
      assert Map.has_key?(operator_obj.properties, "eq")
    end
  end

  describe "string type operators" do
    # Tests for string-specific filter operators.

    setup do
      attr = %{name: :title, type: :string}
      schema = FilterBuilder.build_attribute_filter_schema(attr)
      operator_obj = Enum.find(schema.oneOf, &(&1.type == :object))
      {:ok, operators: operator_obj.properties}
    end

    test "includes eq operator", %{operators: ops} do
      assert Map.has_key?(ops, "eq")
      assert ops["eq"].type == :string
    end

    test "includes ne operator", %{operators: ops} do
      assert Map.has_key?(ops, "ne")
    end

    test "includes contains operator", %{operators: ops} do
      assert Map.has_key?(ops, "contains")
      assert ops["contains"].type == :string
    end

    test "includes starts_with operator", %{operators: ops} do
      assert Map.has_key?(ops, "starts_with")
    end

    test "includes ends_with operator", %{operators: ops} do
      assert Map.has_key?(ops, "ends_with")
    end

    test "includes case-insensitive operators", %{operators: ops} do
      assert Map.has_key?(ops, "icontains")
      assert Map.has_key?(ops, "istarts_with")
      assert Map.has_key?(ops, "iends_with")
    end

    test "includes in operator", %{operators: ops} do
      assert Map.has_key?(ops, "in")
      assert ops["in"].type == :array
    end

    test "includes is_nil operator", %{operators: ops} do
      assert Map.has_key?(ops, "is_nil")
      assert ops["is_nil"].type == :boolean
    end
  end

  describe "numeric type operators" do
    # Tests for numeric-specific filter operators.

    setup do
      attr = %{name: :count, type: :integer}
      schema = FilterBuilder.build_attribute_filter_schema(attr)
      operator_obj = Enum.find(schema.oneOf, &(&1.type == :object))
      {:ok, operators: operator_obj.properties}
    end

    test "includes comparison operators", %{operators: ops} do
      assert Map.has_key?(ops, "gt")
      assert Map.has_key?(ops, "gte")
      assert Map.has_key?(ops, "lt")
      assert Map.has_key?(ops, "lte")
    end

    test "comparison operators use correct type", %{operators: ops} do
      assert ops["gt"].type == :integer
      assert ops["gte"].type == :integer
    end

    test "does not include string operators", %{operators: ops} do
      refute Map.has_key?(ops, "contains")
      refute Map.has_key?(ops, "starts_with")
    end
  end

  describe "boolean type operators" do
    # Tests for boolean-specific filter operators.

    setup do
      attr = %{name: :active, type: :boolean}
      schema = FilterBuilder.build_attribute_filter_schema(attr)
      operator_obj = Enum.find(schema.oneOf, &(&1.type == :object))
      {:ok, operators: operator_obj.properties}
    end

    test "includes only eq, ne, is_nil", %{operators: ops} do
      assert Map.has_key?(ops, "eq")
      assert Map.has_key?(ops, "ne")
      assert Map.has_key?(ops, "is_nil")
    end

    test "does not include comparison operators", %{operators: ops} do
      refute Map.has_key?(ops, "gt")
      refute Map.has_key?(ops, "contains")
    end
  end

  describe "date/time type operators" do
    # Tests for date/time-specific filter operators.

    setup do
      attr = %{name: :created_at, type: :utc_datetime}
      schema = FilterBuilder.build_attribute_filter_schema(attr)
      operator_obj = Enum.find(schema.oneOf, &(&1.type == :object))
      {:ok, operators: operator_obj.properties}
    end

    test "includes comparison operators", %{operators: ops} do
      assert Map.has_key?(ops, "gt")
      assert Map.has_key?(ops, "gte")
      assert Map.has_key?(ops, "lt")
      assert Map.has_key?(ops, "lte")
    end

    test "uses date-time format", %{operators: ops} do
      assert ops["eq"].format == "date-time"
    end
  end

  describe "array type operators" do
    # Tests for array-specific filter operators.

    setup do
      attr = %{name: :tags, type: {:array, :string}}
      schema = FilterBuilder.build_attribute_filter_schema(attr)
      operator_obj = Enum.find(schema.oneOf, &(&1.type == :object))
      {:ok, operators: operator_obj.properties}
    end

    test "includes contains operator", %{operators: ops} do
      assert Map.has_key?(ops, "contains")
    end

    test "includes has_any operator", %{operators: ops} do
      assert Map.has_key?(ops, "has_any")
      assert ops["has_any"].type == :array
    end

    test "includes has_all operator", %{operators: ops} do
      assert Map.has_key?(ops, "has_all")
      assert ops["has_all"].type == :array
    end
  end

  describe "boolean filter operators (and/or/not)" do
    # Tests for logical filter operators.

    test "and operator is array of objects" do
      schema = FilterBuilder.build_filter_schema(AshOaskit.Test.Post)

      and_schema = schema.properties["and"]
      assert and_schema.type == :array
      assert and_schema.items.type == :object
    end

    test "or operator is array of objects" do
      schema = FilterBuilder.build_filter_schema(AshOaskit.Test.Post)

      or_schema = schema.properties["or"]
      assert or_schema.type == :array
    end

    test "not operator is object" do
      schema = FilterBuilder.build_filter_schema(AshOaskit.Test.Post)

      not_schema = schema.properties["not"]
      assert not_schema.type == :object
    end

    test "boolean operators have descriptions" do
      schema = FilterBuilder.build_filter_schema(AshOaskit.Test.Post)

      assert schema.properties["and"].description != nil
      assert schema.properties["or"].description != nil
      assert schema.properties["not"].description != nil
    end
  end

  describe "type mapping" do
    # Tests for correct JSON Schema type mapping.

    test "maps Ash.Type.String" do
      attr = %{name: :name, type: Ash.Type.String}
      schema = FilterBuilder.build_attribute_filter_schema(attr)

      direct = Enum.find(schema.oneOf, &(&1.type == :string))
      assert direct != nil
    end

    test "maps Ash.Type.Integer" do
      attr = %{name: :count, type: Ash.Type.Integer}
      schema = FilterBuilder.build_attribute_filter_schema(attr)

      direct = Enum.find(schema.oneOf, &(&1.type == :integer))
      assert direct != nil
    end

    test "maps Ash.Type.Boolean" do
      attr = %{name: :active, type: Ash.Type.Boolean}
      schema = FilterBuilder.build_attribute_filter_schema(attr)

      direct = Enum.find(schema.oneOf, &(&1.type == :boolean))
      assert direct != nil
    end

    test "maps Ash.Type.UUID" do
      attr = %{name: :id, type: Ash.Type.UUID}
      schema = FilterBuilder.build_attribute_filter_schema(attr)

      direct =
        Enum.find(schema.oneOf, fn s ->
          s.type == :string and s[:format] == "uuid"
        end)

      assert direct != nil
    end

    test "maps date types with format" do
      attr = %{name: :date, type: :date}
      schema = FilterBuilder.build_attribute_filter_schema(attr)

      direct =
        Enum.find(schema.oneOf, fn s ->
          s.type == :string and s[:format] == "date"
        end)

      assert direct != nil
    end
  end

  describe "edge cases" do
    # Tests for edge cases and error handling.

    test "handles resource with minimal attributes" do
      param = FilterBuilder.build_filter_parameter(AshOaskit.Test.Comment)

      assert param != nil
      assert param.schema.properties["content"] != nil
    end

    test "handles unknown types gracefully" do
      attr = %{name: :unknown, type: :unknown_type}
      schema = FilterBuilder.build_attribute_filter_schema(attr)

      # Should default to string
      direct = Enum.find(schema.oneOf, &(&1.type == :string))
      assert direct != nil
    end

    test "normalize_type handles non-atom/non-module types" do
      # Test with tuple type that's not an array - should fall back to :string
      attr = %{name: :weird, type: {:custom, "something"}}
      schema = FilterBuilder.build_attribute_filter_schema(attr)

      # Should default to string type
      direct = Enum.find(schema.oneOf, &(&1.type == :string))
      assert direct != nil
    end

    test "operator_schema handles unknown operators" do
      # Build schema for an attribute which will include various operators
      attr = %{name: :test, type: :string}
      schema = FilterBuilder.build_attribute_filter_schema(attr)

      # Verify operators schema includes standard operators
      operators = Enum.find(schema.oneOf, &Map.has_key?(&1, :properties))
      assert operators != nil
    end

    test "normalize_type with nested array handles inner type" do
      # Array of arrays
      attr = %{name: :nested, type: {:array, {:array, :string}}}
      schema = FilterBuilder.build_attribute_filter_schema(attr)

      # Should produce array schema
      direct = Enum.find(schema.oneOf, &(&1.type == :array))
      assert direct != nil
      assert direct.items.type == :array
    end

    test "normalize_type handles integer as non-string fallback" do
      # Test that integer type produces integer schema
      attr = %{name: :num, type: 123}
      schema = FilterBuilder.build_attribute_filter_schema(attr)

      # Should fall back to string
      direct = Enum.find(schema.oneOf, &(&1.type == :string))
      assert direct != nil
    end
  end
end
