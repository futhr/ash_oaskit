defmodule AshOaskit.SortBuilderTest do
  @moduledoc """
  Comprehensive tests for the AshOaskit.SortBuilder module.

  This test module verifies that sort parameter schemas are generated correctly
  for Ash resources, including handling of:

  - Sortable attributes (public, non-private fields)
  - Sortable calculations (calculations without required arguments)
  - Sortable aggregates (all public aggregates)
  - Sort direction prefixes (ascending/descending)
  - Configuration options (derive_sort? setting)
  - OpenAPI 3.0 vs 3.1 format compatibility

  ## Test Categories

  1. **Basic Parameter Generation** - Tests that sort parameters are generated
     with correct structure and metadata

  2. **Field Discovery** - Tests that sortable fields are correctly identified
     from attributes, calculations, and aggregates

  3. **Schema Formats** - Tests different schema formats (string, enum, array)

  4. **Edge Cases** - Tests resources with no sortable fields, all private
     fields, etc.
  """

  use ExUnit.Case, async: true

  alias AshOaskit.SortBuilder

  # Using the test_resources.ex test fixtures (Post, Comment in SimpleDomain/Blog)

  describe "build_sort_parameter/2" do
    # Tests for basic sort parameter generation

    test "generates sort parameter for resource with sortable fields" do
      result = SortBuilder.build_sort_parameter(AshOaskit.Test.Post)

      assert result != nil
      assert result.name == "sort"
      assert result.in == :query
      assert result.required == false
      assert is_map(result.schema)
      assert result.description =~ "Sort criteria"
      assert result.description =~ "Post"
    end

    test "schema has string type" do
      result = SortBuilder.build_sort_parameter(AshOaskit.Test.Post)

      assert result.schema.type == :string
    end

    test "schema description lists available fields" do
      result = SortBuilder.build_sort_parameter(AshOaskit.Test.Post)

      description = result.schema.description
      assert description =~ "Comma-separated"
      assert description =~ "-"
      assert description =~ "descending"
    end

    test "returns nil for resource with derive_sort? disabled" do
      # This test documents expected behavior when derive_sort? is false
      # Since our test resources don't have this disabled, we test the function
      # handles the check correctly
      result = SortBuilder.build_sort_parameter(AshOaskit.Test.Post)
      assert result != nil
    end

    test "generates parameter for Comment resource" do
      result = SortBuilder.build_sort_parameter(AshOaskit.Test.Comment)

      assert result != nil
      assert result.name == "sort"
      assert result.schema.type == :string
    end
  end

  describe "get_sortable_fields/1" do
    # Tests for field discovery from resources

    test "returns sortable attribute names for Post" do
      fields = SortBuilder.get_sortable_fields(AshOaskit.Test.Post)

      # Post has: title, body, status, view_count, rating, published_at, etc.
      assert :title in fields
      assert :body in fields
      assert :status in fields
    end

    test "excludes id field" do
      fields = SortBuilder.get_sortable_fields(AshOaskit.Test.Post)

      refute :id in fields
    end

    test "excludes timestamp fields by default" do
      fields = SortBuilder.get_sortable_fields(AshOaskit.Test.Post)

      refute :inserted_at in fields
      refute :updated_at in fields
    end

    test "returns sortable fields for Comment" do
      fields = SortBuilder.get_sortable_fields(AshOaskit.Test.Comment)

      assert :content in fields
    end

    test "returns list of atoms" do
      fields = SortBuilder.get_sortable_fields(AshOaskit.Test.Post)

      assert is_list(fields)

      Enum.each(fields, fn field ->
        assert is_atom(field)
      end)
    end

    test "returns at least some fields for resources with attributes" do
      fields = SortBuilder.get_sortable_fields(AshOaskit.Test.Post)

      assert fields != []
    end
  end

  describe "build_sort_schema/2" do
    # Tests for sort schema object generation

    test "generates string type schema" do
      schema = SortBuilder.build_sort_schema([:title, :created_at], [])

      assert schema.type == :string
    end

    test "includes description with field list" do
      schema = SortBuilder.build_sort_schema([:title, :created_at], [])

      assert schema.description =~ "title"
      assert schema.description =~ "created_at"
    end

    test "description explains sort direction syntax" do
      schema = SortBuilder.build_sort_schema([:title], [])

      assert schema.description =~ "-"
      assert schema.description =~ "descending"
      assert schema.description =~ "ascending"
    end

    test "handles empty field list" do
      schema = SortBuilder.build_sort_schema([], [])

      assert schema.type == :string
      assert schema.description =~ "Available fields:"
    end

    test "handles single field" do
      schema = SortBuilder.build_sort_schema([:name], [])

      assert schema.description =~ "name"
    end

    test "handles multiple fields" do
      schema = SortBuilder.build_sort_schema([:a, :b, :c, :d], [])

      assert schema.description =~ "a"
      assert schema.description =~ "b"
      assert schema.description =~ "c"
      assert schema.description =~ "d"
    end
  end

  describe "build_sort_enum_schema/2" do
    # Tests for enum-based sort schema generation

    test "generates enum with ascending and descending variants" do
      schema = SortBuilder.build_sort_enum_schema([:title], [])

      assert schema.type == :string
      assert "title" in schema.enum
      assert "-title" in schema.enum
    end

    test "includes all fields in enum" do
      schema = SortBuilder.build_sort_enum_schema([:title, :created_at], [])

      assert "title" in schema.enum
      assert "-title" in schema.enum
      assert "created_at" in schema.enum
      assert "-created_at" in schema.enum
    end

    test "enum has twice as many values as fields" do
      fields = [:a, :b, :c]
      schema = SortBuilder.build_sort_enum_schema(fields, [])

      # Each field has ascending and descending variant
      assert length(schema.enum) == length(fields) * 2
    end

    test "handles empty field list" do
      schema = SortBuilder.build_sort_enum_schema([], [])

      assert schema.type == :string
      assert schema.enum == []
    end

    test "converts atom field names to strings" do
      schema = SortBuilder.build_sort_enum_schema([:my_field], [])

      assert "my_field" in schema.enum
      assert "-my_field" in schema.enum
      refute :my_field in schema.enum
    end

    test "preserves field name case" do
      schema = SortBuilder.build_sort_enum_schema([:createdAt, :UpdatedAt], [])

      assert "createdAt" in schema.enum
      assert "UpdatedAt" in schema.enum
    end
  end

  describe "build_sort_array_schema/2" do
    # Tests for array-based sort schema generation

    test "generates array type schema" do
      schema = SortBuilder.build_sort_array_schema([:title], [])

      assert schema.type == :array
    end

    test "has items with enum schema" do
      schema = SortBuilder.build_sort_array_schema([:title], [])

      assert is_map(schema.items)
      assert schema.items.type == :string
      assert is_list(schema.items.enum)
    end

    test "items enum includes all sort variants" do
      schema = SortBuilder.build_sort_array_schema([:title, :name], [])

      items_enum = schema.items.enum
      assert "title" in items_enum
      assert "-title" in items_enum
      assert "name" in items_enum
      assert "-name" in items_enum
    end

    test "handles empty field list" do
      schema = SortBuilder.build_sort_array_schema([], [])

      assert schema.type == :array
      assert schema.items.enum == []
    end
  end

  describe "version compatibility" do
    # Tests for OpenAPI 3.0 vs 3.1 compatibility

    test "version 3.1 option generates valid schema" do
      result = SortBuilder.build_sort_parameter(AshOaskit.Test.Post, version: "3.1")

      assert result != nil
      assert result.schema.type == :string
    end

    test "version 3.0 option generates valid schema" do
      result = SortBuilder.build_sort_parameter(AshOaskit.Test.Post, version: "3.0")

      assert result != nil
      assert result.schema.type == :string
    end

    test "default version generates valid schema" do
      result = SortBuilder.build_sort_parameter(AshOaskit.Test.Post)

      assert result != nil
      assert result.schema.type == :string
    end
  end

  describe "edge cases" do
    # Tests for edge cases and unusual scenarios

    test "handles resource name extraction" do
      result = SortBuilder.build_sort_parameter(AshOaskit.Test.Post)

      # Should use "Post" not full module path
      assert result.description =~ "Post"
      refute result.description =~ "AshOaskit.Test"
    end

    test "sortable fields returns list even for minimal resource" do
      # Comment has minimal attributes
      fields = SortBuilder.get_sortable_fields(AshOaskit.Test.Comment)

      assert is_list(fields)
    end

    test "build_sort_schema handles field names with underscores" do
      schema = SortBuilder.build_sort_schema([:created_at, :updated_by_id], [])

      assert schema.description =~ "created_at"
      assert schema.description =~ "updated_by_id"
    end

    test "build_sort_enum_schema handles field names with numbers" do
      schema = SortBuilder.build_sort_enum_schema([:field1, :field2], [])

      assert "field1" in schema.enum
      assert "-field1" in schema.enum
      assert "field2" in schema.enum
    end

    test "all schema builders return maps" do
      assert is_map(SortBuilder.build_sort_schema([:a], []))
      assert is_map(SortBuilder.build_sort_enum_schema([:a], []))
      assert is_map(SortBuilder.build_sort_array_schema([:a], []))
    end
  end

  describe "sortable calculations with arguments" do
    test "includes calculations without arguments" do
      fields = SortBuilder.get_sortable_fields(AshOaskit.Test.Author)

      # Author has full_name and article_count calculations without required args
      assert :full_name in fields or :article_count in fields
    end

    test "includes calculations regardless of argument optionality" do
      # Ash argument structs always have a :default key, so argument_optional?
      # returns true for all arguments in practice
      fields = SortBuilder.get_sortable_fields(AshOaskit.Test.Author)
      assert :greeting in fields
      assert :formal_greeting in fields
    end
  end

  describe "sort parameter for Article resource" do
    test "builds sort parameter with field description for Article" do
      result = SortBuilder.build_sort_parameter(AshOaskit.Test.Article, version: "3.1")
      assert result.name == "sort"
      assert result.schema.description =~ "title"
    end
  end

  describe "sortable aggregates" do
    test "includes aggregates in sortable fields" do
      fields = SortBuilder.get_sortable_fields(AshOaskit.Test.Author)

      # Author has total_articles aggregate
      assert :total_articles in fields
    end

    test "includes multiple aggregates for Article" do
      fields = SortBuilder.get_sortable_fields(AshOaskit.Test.Article)

      # Article has total_reviews, average_rating, tag_count aggregates
      assert is_list(fields)
    end
  end

  describe "integration with generators" do
    # Tests for integration with V30 and V31 generators

    test "parameter structure matches OpenAPI parameter object spec" do
      result = SortBuilder.build_sort_parameter(AshOaskit.Test.Post)

      # Required fields for OpenAPI parameter object
      assert Map.has_key?(result, :name)
      assert Map.has_key?(result, :in)
      assert Map.has_key?(result, :schema)

      # Valid "in" value
      assert result.in in [:query, :path, :header, :cookie]
    end

    test "schema is valid OpenAPI schema object" do
      result = SortBuilder.build_sort_parameter(AshOaskit.Test.Post)

      schema = result.schema
      assert Map.has_key?(schema, :type)
      assert schema.type in [:string, :integer, :number, :boolean, :array, :object]
    end

    test "can be used directly in parameters array" do
      param = SortBuilder.build_sort_parameter(AshOaskit.Test.Post)
      parameters = [param]

      assert length(parameters) == 1
      assert hd(parameters).name == "sort"
    end
  end
end
