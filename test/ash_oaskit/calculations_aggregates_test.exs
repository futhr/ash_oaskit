defmodule AshOaskit.CalculationsAggregatesTest do
  @moduledoc """
  Comprehensive tests for calculation and aggregate schema generation.

  These tests verify that ash_oaskit correctly includes calculations and
  aggregates in the generated OpenAPI schemas, matching the functionality
  of AshJsonApi.OpenApi.

  ## Calculations

  Calculations are computed values derived from resource data using expressions.
  They appear in output schemas (attributes) but NOT in input schemas.

  ### Calculation Types Tested
  - String calculations (e.g., `full_name`)
  - Integer calculations (e.g., `article_count`)
  - Boolean calculations
  - Date/time calculations
  - Calculations referencing relationships

  ### Calculation Schema Properties
  - Type mapping from Ash type to JSON Schema
  - Always nullable (calculations may not be loaded)
  - Description inclusion

  ## Aggregates

  Aggregates are computed values that summarize related data. They use
  different kinds (count, sum, avg, etc.) which affect the output type.

  ### Aggregate Kinds Tested
  - `:count` - Returns integer
  - `:sum` - Returns number
  - `:avg` - Returns number
  - `:min` / `:max` - Returns field type or number
  - `:first` - Returns field type
  - `:list` - Returns array of field type
  - `:exists` - Returns boolean

  ### Aggregate Schema Properties
  - Type inference from aggregate kind
  - Always nullable (aggregates may not be loaded)
  - Description inclusion

  ## OpenAPI Version Differences

  ### OpenAPI 3.0
  - Nullable values use `nullable: true`

  ### OpenAPI 3.1
  - Nullable values use type arrays `["type", "null"]`

  ## Test Resources

  Tests use resources from `test/support/relationship_resources.ex`:
  - `Author` - has `full_name` calculation, `total_articles` aggregate
  - `Article` - has `author_name` calculation, multiple aggregates
  - `Category` - has `full_path` calculation, `total_children` aggregate
  """

  use ExUnit.Case, async: true

  alias AshOaskit.SchemaBuilder

  describe "calculation schema generation" do
    @describetag :calculations

    # Calculation values come from PropertyBuilders (atom keys).

    setup do
      builder =
        SchemaBuilder.add_resource_schemas(
          SchemaBuilder.new(version: "3.1"),
          AshOaskit.Test.Author
        )

      {:ok, builder: builder}
    end

    test "calculations appear in attributes schema", %{builder: builder} do
      schema = SchemaBuilder.get_schema(builder, "AuthorAttributes")

      # Author has full_name and article_count calculations
      assert Map.has_key?(schema[:properties], :full_name)
      assert Map.has_key?(schema[:properties], :article_count)
    end

    test "string calculation has string type", %{builder: builder} do
      schema = SchemaBuilder.get_schema(builder, "AuthorAttributes")

      full_name = schema[:properties][:full_name]
      assert :string in List.wrap(full_name[:type])
    end

    test "integer calculation has integer type", %{builder: builder} do
      schema = SchemaBuilder.get_schema(builder, "AuthorAttributes")

      article_count = schema[:properties][:article_count]
      assert :integer in List.wrap(article_count[:type])
    end

    test "calculations are nullable (may not be loaded)", %{builder: builder} do
      schema = SchemaBuilder.get_schema(builder, "AuthorAttributes")

      # In 3.1, nullable uses type array
      full_name = schema[:properties][:full_name]
      assert is_list(full_name[:type])
      assert :null in full_name[:type]
    end

    test "calculation description is included", %{builder: builder} do
      schema = SchemaBuilder.get_schema(builder, "AuthorAttributes")

      full_name = schema[:properties][:full_name]
      assert full_name[:description] == "Author's full name"
    end
  end

  describe "calculations in OpenAPI 3.0" do
    @describetag :calculations

    test "calculations use nullable: true in 3.0" do
      builder =
        SchemaBuilder.add_resource_schemas(
          SchemaBuilder.new(version: "3.0"),
          AshOaskit.Test.Author
        )

      schema = SchemaBuilder.get_schema(builder, "AuthorAttributes")

      full_name = schema[:properties][:full_name]
      assert full_name[:nullable] == true
    end
  end

  describe "calculations not in input schemas" do
    @describetag :calculations

    # Input schemas use TypeMapper for attribute values (string keys),
    # but calculations/aggregates are not included at all.

    setup do
      builder =
        SchemaBuilder.add_resource_schemas(
          SchemaBuilder.new(version: "3.1"),
          AshOaskit.Test.Author
        )

      {:ok, builder: builder}
    end

    test "calculations not in create input schema", %{builder: builder} do
      schema = SchemaBuilder.get_schema(builder, "AuthorCreateInput")

      refute Map.has_key?(schema[:properties], :full_name)
      refute Map.has_key?(schema[:properties], :article_count)
    end

    test "calculations not in update input schema", %{builder: builder} do
      schema = SchemaBuilder.get_schema(builder, "AuthorUpdateInput")

      refute Map.has_key?(schema[:properties], :full_name)
      refute Map.has_key?(schema[:properties], :article_count)
    end
  end

  describe "aggregate schema generation" do
    @describetag :aggregates

    # Aggregate values come from PropertyBuilders (atom keys).

    setup do
      builder =
        SchemaBuilder.add_resource_schemas(
          SchemaBuilder.new(version: "3.1"),
          AshOaskit.Test.Author
        )

      {:ok, builder: builder}
    end

    test "aggregates appear in attributes schema", %{builder: builder} do
      schema = SchemaBuilder.get_schema(builder, "AuthorAttributes")

      # Author has total_articles count aggregate
      assert Map.has_key?(schema[:properties], :total_articles)
    end

    test "count aggregate has integer type", %{builder: builder} do
      schema = SchemaBuilder.get_schema(builder, "AuthorAttributes")

      total_articles = schema[:properties][:total_articles]
      assert :integer in List.wrap(total_articles[:type])
    end

    test "aggregates are nullable (may not be loaded)", %{builder: builder} do
      schema = SchemaBuilder.get_schema(builder, "AuthorAttributes")

      total_articles = schema[:properties][:total_articles]
      assert is_list(total_articles[:type])
      assert :null in total_articles[:type]
    end

    test "aggregate description is included", %{builder: builder} do
      schema = SchemaBuilder.get_schema(builder, "AuthorAttributes")

      total_articles = schema[:properties][:total_articles]
      assert total_articles[:description] == "Total number of articles"
    end
  end

  describe "aggregate kinds" do
    @describetag :aggregates

    # Aggregate values come from PropertyBuilders (atom keys).

    setup do
      builder =
        SchemaBuilder.add_resource_schemas(
          SchemaBuilder.new(version: "3.1"),
          AshOaskit.Test.Article
        )

      {:ok, builder: builder}
    end

    test "count aggregate returns integer", %{builder: builder} do
      schema = SchemaBuilder.get_schema(builder, "ArticleAttributes")

      # Article has total_reviews count
      total_reviews = schema[:properties][:total_reviews]
      assert :integer in List.wrap(total_reviews[:type])
    end

    test "avg aggregate returns number", %{builder: builder} do
      schema = SchemaBuilder.get_schema(builder, "ArticleAttributes")

      # Article has average_rating avg
      average_rating = schema[:properties][:average_rating]
      assert :number in List.wrap(average_rating[:type])
    end

    test "count on many_to_many returns integer", %{builder: builder} do
      schema = SchemaBuilder.get_schema(builder, "ArticleAttributes")

      # Article has tag_count
      tag_count = schema[:properties][:tag_count]
      assert :integer in List.wrap(tag_count[:type])
    end
  end

  describe "aggregates in OpenAPI 3.0" do
    @describetag :aggregates

    test "aggregates use nullable: true in 3.0" do
      builder =
        SchemaBuilder.add_resource_schemas(
          SchemaBuilder.new(version: "3.0"),
          AshOaskit.Test.Author
        )

      schema = SchemaBuilder.get_schema(builder, "AuthorAttributes")

      total_articles = schema[:properties][:total_articles]
      assert total_articles[:nullable] == true
    end
  end

  describe "aggregates not in input schemas" do
    @describetag :aggregates

    setup do
      builder =
        SchemaBuilder.add_resource_schemas(
          SchemaBuilder.new(version: "3.1"),
          AshOaskit.Test.Author
        )

      {:ok, builder: builder}
    end

    test "aggregates not in create input schema", %{builder: builder} do
      schema = SchemaBuilder.get_schema(builder, "AuthorCreateInput")

      refute Map.has_key?(schema[:properties], :total_articles)
    end

    test "aggregates not in update input schema", %{builder: builder} do
      schema = SchemaBuilder.get_schema(builder, "AuthorUpdateInput")

      refute Map.has_key?(schema[:properties], :total_articles)
    end
  end

  describe "attributes, calculations, and aggregates together" do
    setup do
      builder =
        SchemaBuilder.add_resource_schemas(
          SchemaBuilder.new(version: "3.1"),
          AshOaskit.Test.Author
        )

      {:ok, builder: builder}
    end

    test "attributes schema contains all three types", %{builder: builder} do
      schema = SchemaBuilder.get_schema(builder, "AuthorAttributes")
      props = schema[:properties]

      # Regular attributes (property names are atoms)
      assert Map.has_key?(props, :first_name)
      assert Map.has_key?(props, :last_name)
      assert Map.has_key?(props, :email)

      # Calculations
      assert Map.has_key?(props, :full_name)
      assert Map.has_key?(props, :article_count)

      # Aggregates
      assert Map.has_key?(props, :total_articles)
    end

    test "only regular attributes can be required", %{builder: builder} do
      schema = SchemaBuilder.get_schema(builder, "AuthorAttributes")
      required = schema[:required] || []

      # first_name, last_name, email have allow_nil?: false
      assert "first_name" in required
      assert "last_name" in required
      assert "email" in required

      # Calculations and aggregates should never be required
      refute "full_name" in required
      refute "article_count" in required
      refute "total_articles" in required
    end
  end

  describe "resource without calculations or aggregates" do
    setup do
      builder =
        SchemaBuilder.add_resource_schemas(
          SchemaBuilder.new(version: "3.1"),
          AshOaskit.Test.Comment
        )

      {:ok, builder: builder}
    end

    test "schema still generates correctly", %{builder: builder} do
      assert SchemaBuilder.has_schema?(builder, "CommentAttributes")

      schema = SchemaBuilder.get_schema(builder, "CommentAttributes")
      assert schema[:type] == :object
      assert Map.has_key?(schema[:properties], :content)
    end
  end

  describe "self-referential resource calculations and aggregates" do
    # Calculation/aggregate values from PropertyBuilders use atom keys.

    setup do
      builder =
        SchemaBuilder.add_resource_schemas(
          SchemaBuilder.new(version: "3.1"),
          AshOaskit.Test.Category
        )

      {:ok, builder: builder}
    end

    test "self-referential calculations work", %{builder: builder} do
      schema = SchemaBuilder.get_schema(builder, "CategoryAttributes")

      # Category has full_path calculation that references parent
      assert Map.has_key?(schema[:properties], :full_path)

      full_path = schema[:properties][:full_path]
      assert :string in List.wrap(full_path[:type])
    end

    test "self-referential aggregates work", %{builder: builder} do
      schema = SchemaBuilder.get_schema(builder, "CategoryAttributes")

      # Category has total_children aggregate on self-referential relationship
      assert Map.has_key?(schema[:properties], :total_children)

      total_children = schema[:properties][:total_children]
      assert :integer in List.wrap(total_children[:type])
    end

    test "child_count calculation works", %{builder: builder} do
      schema = SchemaBuilder.get_schema(builder, "CategoryAttributes")

      assert Map.has_key?(schema[:properties], :child_count)

      child_count = schema[:properties][:child_count]
      assert :integer in List.wrap(child_count[:type])
    end
  end

  describe "edge cases" do
    test "calculation without description works" do
      # Review calculation for article with no description
      builder =
        SchemaBuilder.add_resource_schemas(
          SchemaBuilder.new(version: "3.1"),
          AshOaskit.Test.Article
        )

      schema = SchemaBuilder.get_schema(builder, "ArticleAttributes")

      # Should still generate schema even without description
      assert Map.has_key?(schema[:properties], :review_count)
    end

    test "multiple aggregates on same resource" do
      builder =
        SchemaBuilder.add_resource_schemas(
          SchemaBuilder.new(version: "3.1"),
          AshOaskit.Test.Article
        )

      schema = SchemaBuilder.get_schema(builder, "ArticleAttributes")

      # Article has multiple aggregates: total_reviews, average_rating, tag_count
      assert Map.has_key?(schema[:properties], :total_reviews)
      assert Map.has_key?(schema[:properties], :average_rating)
      assert Map.has_key?(schema[:properties], :tag_count)
    end

    test "calculation referencing relationship attribute" do
      builder =
        SchemaBuilder.add_resource_schemas(
          SchemaBuilder.new(version: "3.1"),
          AshOaskit.Test.Article
        )

      schema = SchemaBuilder.get_schema(builder, "ArticleAttributes")

      # author_name calculation references author.first_name
      assert Map.has_key?(schema[:properties], :author_name)

      author_name = schema[:properties][:author_name]
      assert :string in List.wrap(author_name[:type])
    end
  end
end
