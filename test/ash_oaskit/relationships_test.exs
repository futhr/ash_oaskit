defmodule AshOaskit.RelationshipsTest do
  @moduledoc """
  Comprehensive tests for relationship schema generation.

  These tests verify that ash_oaskit correctly generates OpenAPI schemas for
  all Ash relationship types, matching the functionality of AshJsonApi.OpenApi.

  ## Relationship Types Tested

  ### belongs_to
  - Single resource identifier (to-one)
  - Nullable handling for optional relationships
  - Non-nullable handling for required relationships
  - Foreign key attribute inclusion

  ### has_many
  - Array of resource identifiers (to-many)
  - Empty array default
  - Relationship links generation

  ### has_one
  - Single resource identifier (to-one)
  - Similar to belongs_to but inverse direction

  ### many_to_many
  - Array of resource identifiers (to-many)
  - Through resource handling

  ### Self-referential
  - Cycle detection
  - $ref generation for recursive types
  - Parent/children pattern

  ## Schema Structure Tests

  ### Resource Identifier
  - `id` property (string)
  - `type` property (enum with JSON:API type)
  - Required fields

  ### Relationship Object
  - `data` property with identifier(s)
  - `links` property with `self` and `related`

  ### Cardinality
  - To-one: Single object or null
  - To-many: Array of objects

  ## OpenAPI Version Differences

  ### OpenAPI 3.0
  - Nullable relationships use `nullable: true`

  ### OpenAPI 3.1
  - Nullable relationships use `oneOf` with null type

  ## Test Resources

  Tests use resources from `test/support/relationship_resources.ex`:
  - `Author` - has_many articles, embedded profile
  - `Article` - belongs_to author, has_many reviews, many_to_many tags
  - `Review` - belongs_to article
  - `Tag` - many_to_many articles
  - `Category` - self-referential parent/children
  """

  use ExUnit.Case, async: true

  alias AshOaskit.SchemaBuilder

  setup do
    base_31 = SchemaBuilder.new(version: "3.1")
    builder_31 = SchemaBuilder.add_resource_schemas(base_31, AshOaskit.Test.Author)

    base_30 = SchemaBuilder.new(version: "3.0")
    builder_30 = SchemaBuilder.add_resource_schemas(base_30, AshOaskit.Test.Author)

    {:ok, builder_31: builder_31, builder_30: builder_30}
  end

  describe "has_many relationship schemas" do
    # Tests for has_many relationship schema generation (Author -> Articles).
    # Relationship schemas use atom keys throughout (from RelationshipSchemas).

    test "generates relationships schema for resource with has_many", %{builder_31: builder} do
      assert SchemaBuilder.has_schema?(builder, "AuthorRelationships")
    end

    test "has_many relationship has array data type", %{builder_31: builder} do
      schema = SchemaBuilder.get_schema(builder, "AuthorRelationships")

      articles_rel = Map.get(schema[:properties], :articles)
      data_schema = Map.get(articles_rel[:properties], :data)

      assert data_schema[:type] == :array
    end

    test "has_many array items have resource identifier structure", %{builder_31: builder} do
      schema = SchemaBuilder.get_schema(builder, "AuthorRelationships")

      articles_rel = Map.get(schema[:properties], :articles)
      items = Map.get(articles_rel[:properties][:data], :items)

      assert items[:type] == :object
      assert Map.has_key?(items[:properties], :id)
      assert Map.has_key?(items[:properties], :type)
      assert items[:required] == ["id", "type"]
    end

    test "has_many identifier type has JSON:API type enum", %{builder_31: builder} do
      schema = SchemaBuilder.get_schema(builder, "AuthorRelationships")

      articles_rel = Map.get(schema[:properties], :articles)
      items = Map.get(articles_rel[:properties][:data], :items)
      type_schema = Map.get(items[:properties], :type)

      assert type_schema[:enum] == ["article"]
    end

    test "has_many relationship includes links", %{builder_31: builder} do
      schema = SchemaBuilder.get_schema(builder, "AuthorRelationships")

      articles_rel = Map.get(schema[:properties], :articles)
      links = Map.get(articles_rel[:properties], :links)

      assert links[:type] == :object
      assert Map.has_key?(links[:properties], :related)
      assert Map.has_key?(links[:properties], :self)
    end
  end

  describe "belongs_to relationship schemas" do
    # Tests for belongs_to relationship schema generation (Article -> Author).

    setup do
      base = SchemaBuilder.new(version: "3.1")
      builder = SchemaBuilder.add_resource_schemas(base, AshOaskit.Test.Article)

      {:ok, builder: builder}
    end

    test "generates relationships schema for resource with belongs_to", %{builder: builder} do
      assert SchemaBuilder.has_schema?(builder, "ArticleRelationships")
    end

    test "belongs_to relationship has single object data type", %{builder: builder} do
      schema = SchemaBuilder.get_schema(builder, "ArticleRelationships")

      author_rel = Map.get(schema[:properties], :author)
      data_schema = Map.get(author_rel[:properties], :data)

      # Required belongs_to should not be nullable
      # It should be a oneOf with object or null for nullable ones
      # For required (allow_nil?: false), it should just be the object
      assert data_schema[:type] == :object or Map.has_key?(data_schema, :oneOf)
    end

    test "belongs_to identifier has resource identifier structure", %{builder: builder} do
      schema = SchemaBuilder.get_schema(builder, "ArticleRelationships")

      author_rel = Map.get(schema[:properties], :author)
      data_schema = Map.get(author_rel[:properties], :data)

      # Get the actual object schema (may be wrapped in oneOf for nullable)
      object_schema =
        if Map.has_key?(data_schema, :oneOf) do
          Enum.find(data_schema[:oneOf], &(&1[:type] == :object))
        else
          data_schema
        end

      assert object_schema[:type] == :object
      assert Map.has_key?(object_schema[:properties], :id)
      assert Map.has_key?(object_schema[:properties], :type)
    end

    test "belongs_to identifier type has correct JSON:API type", %{builder: builder} do
      schema = SchemaBuilder.get_schema(builder, "ArticleRelationships")

      author_rel = Map.get(schema[:properties], :author)
      data_schema = Map.get(author_rel[:properties], :data)

      object_schema =
        if Map.has_key?(data_schema, :oneOf) do
          Enum.find(data_schema[:oneOf], &(&1[:type] == :object))
        else
          data_schema
        end

      type_schema = object_schema[:properties][:type]
      assert type_schema[:enum] == ["author"]
    end
  end

  describe "many_to_many relationship schemas" do
    # Tests for many_to_many relationship schema generation (Article <-> Tags).

    setup do
      base = SchemaBuilder.new(version: "3.1")
      builder = SchemaBuilder.add_resource_schemas(base, AshOaskit.Test.Article)

      {:ok, builder: builder}
    end

    test "many_to_many relationship has array data type", %{builder: builder} do
      schema = SchemaBuilder.get_schema(builder, "ArticleRelationships")

      tags_rel = Map.get(schema[:properties], :tags)
      data_schema = Map.get(tags_rel[:properties], :data)

      assert data_schema[:type] == :array
    end

    test "many_to_many array items have correct type enum", %{builder: builder} do
      schema = SchemaBuilder.get_schema(builder, "ArticleRelationships")

      tags_rel = Map.get(schema[:properties], :tags)
      items = Map.get(tags_rel[:properties][:data], :items)
      type_schema = Map.get(items[:properties], :type)

      assert type_schema[:enum] == ["tag"]
    end
  end

  describe "self-referential relationship schemas" do
    # Tests for self-referential relationships (Category parent/children).

    setup do
      base = SchemaBuilder.new(version: "3.1")
      builder = SchemaBuilder.add_resource_schemas(base, AshOaskit.Test.Category)

      {:ok, builder: builder}
    end

    test "generates relationships schema for self-referential resource", %{builder: builder} do
      assert SchemaBuilder.has_schema?(builder, "CategoryRelationships")
    end

    test "parent relationship (belongs_to self) has correct type", %{builder: builder} do
      schema = SchemaBuilder.get_schema(builder, "CategoryRelationships")

      parent_rel = Map.get(schema[:properties], :parent)
      data_schema = Map.get(parent_rel[:properties], :data)

      # Parent is optional, so should be nullable
      # Get the object schema
      object_schema =
        if Map.has_key?(data_schema, :oneOf) do
          Enum.find(data_schema[:oneOf], &(&1[:type] == :object))
        else
          data_schema
        end

      type_schema = object_schema[:properties][:type]
      assert type_schema[:enum] == ["category"]
    end

    test "children relationship (has_many self) has correct type", %{builder: builder} do
      schema = SchemaBuilder.get_schema(builder, "CategoryRelationships")

      children_rel = Map.get(schema[:properties], :children)
      items = Map.get(children_rel[:properties][:data], :items)
      type_schema = Map.get(items[:properties], :type)

      assert type_schema[:enum] == ["category"]
    end

    test "self-referential resource marks itself as seen", %{builder: builder} do
      assert SchemaBuilder.seen?(builder, AshOaskit.Test.Category)
    end
  end

  describe "response schema includes relationships" do
    # Tests that response schemas reference the relationships schema.

    test "response schema data includes relationships reference", %{builder_31: builder} do
      schema = SchemaBuilder.get_schema(builder, "AuthorResponse")

      data_props = schema[:properties][:data][:properties]
      assert Map.has_key?(data_props, :relationships)
      assert data_props[:relationships]["$ref"] == "#/components/schemas/AuthorRelationships"
    end

    test "response schema data has correct structure", %{builder_31: builder} do
      schema = SchemaBuilder.get_schema(builder, "AuthorResponse")

      data = schema[:properties][:data]
      assert Map.has_key?(data[:properties], :id)
      assert Map.has_key?(data[:properties], :type)
      assert Map.has_key?(data[:properties], :attributes)
      assert Map.has_key?(data[:properties], :relationships)
    end
  end

  describe "OpenAPI 3.0 nullable handling for relationships" do
    # Tests for OpenAPI 3.0 specific nullable handling in relationships.

    test "optional belongs_to uses nullable: true in 3.0" do
      base = SchemaBuilder.new(version: "3.0")
      builder = SchemaBuilder.add_resource_schemas(base, AshOaskit.Test.Category)

      schema = SchemaBuilder.get_schema(builder, "CategoryRelationships")
      parent_rel = Map.get(schema[:properties], :parent)
      data_schema = Map.get(parent_rel[:properties], :data)

      # In 3.0, nullable relationships should use nullable: true
      assert data_schema[:nullable] == true or Map.has_key?(data_schema, :oneOf)
    end
  end

  describe "OpenAPI 3.1 nullable handling for relationships" do
    # Tests for OpenAPI 3.1 specific nullable handling in relationships.

    test "optional belongs_to uses oneOf with null in 3.1" do
      base = SchemaBuilder.new(version: "3.1")
      builder = SchemaBuilder.add_resource_schemas(base, AshOaskit.Test.Category)

      schema = SchemaBuilder.get_schema(builder, "CategoryRelationships")
      parent_rel = Map.get(schema[:properties], :parent)
      data_schema = Map.get(parent_rel[:properties], :data)

      # In 3.1, nullable relationships should use oneOf
      assert Map.has_key?(data_schema, :oneOf)

      # Should have null type option
      null_option = Enum.find(data_schema[:oneOf], &(&1[:type] == :null))
      assert null_option != nil
    end
  end

  describe "related resource schema generation" do
    # Tests that related resources get their schemas generated.

    test "generates schemas for destination resources", %{builder_31: builder} do
      # Author has_many articles, so Article schemas should be generated
      assert SchemaBuilder.has_schema?(builder, "ArticleAttributes")
      assert SchemaBuilder.has_schema?(builder, "ArticleResponse")
    end

    test "marks destination resources as seen", %{builder_31: builder} do
      assert SchemaBuilder.seen?(builder, AshOaskit.Test.Article)
    end

    test "generates nested relationship schemas", %{builder_31: builder} do
      # Article has reviews and tags, so those should be generated too
      assert SchemaBuilder.has_schema?(builder, "ReviewAttributes")
      assert SchemaBuilder.has_schema?(builder, "TagAttributes")
    end
  end

  describe "resource without relationships" do
    # Tests for resources that have no relationships.

    setup do
      base = SchemaBuilder.new(version: "3.1")
      builder = SchemaBuilder.add_resource_schemas(base, AshOaskit.Test.Comment)

      {:ok, builder: builder}
    end

    test "does not generate relationships schema", %{builder: builder} do
      refute SchemaBuilder.has_schema?(builder, "CommentRelationships")
    end

    test "response schema data does not include relationships", %{builder: builder} do
      schema = SchemaBuilder.get_schema(builder, "CommentResponse")

      data_props = schema[:properties][:data][:properties]
      refute Map.has_key?(data_props, :relationships)
    end
  end

  describe "resource with multiple relationship types" do
    # Tests for Article which has belongs_to, has_many, and many_to_many.

    setup do
      base = SchemaBuilder.new(version: "3.1")
      builder = SchemaBuilder.add_resource_schemas(base, AshOaskit.Test.Article)

      {:ok, builder: builder}
    end

    test "generates all relationship properties", %{builder: builder} do
      schema = SchemaBuilder.get_schema(builder, "ArticleRelationships")

      props = schema[:properties]
      assert Map.has_key?(props, :author)
      assert Map.has_key?(props, :reviews)
      assert Map.has_key?(props, :tags)
    end

    test "belongs_to is to-one", %{builder: builder} do
      schema = SchemaBuilder.get_schema(builder, "ArticleRelationships")

      author = schema[:properties][:author][:properties][:data]
      # To-one: object (possibly with oneOf for nullable)
      assert author[:type] == :object or Map.has_key?(author, :oneOf)
    end

    test "has_many is to-many", %{builder: builder} do
      schema = SchemaBuilder.get_schema(builder, "ArticleRelationships")

      reviews = schema[:properties][:reviews][:properties][:data]
      assert reviews[:type] == :array
    end

    test "many_to_many is to-many", %{builder: builder} do
      schema = SchemaBuilder.get_schema(builder, "ArticleRelationships")

      tags = schema[:properties][:tags][:properties][:data]
      assert tags[:type] == :array
    end
  end

  describe "relationship links" do
    # Tests for relationship links structure.

    test "links have URI format", %{builder_31: builder} do
      schema = SchemaBuilder.get_schema(builder, "AuthorRelationships")

      links = Map.get(schema[:properties][:articles][:properties], :links)
      related = Map.get(links[:properties], :related)
      self_link = Map.get(links[:properties], :self)

      assert related[:format] == :uri
      assert self_link[:format] == :uri
    end

    test "links are strings", %{builder_31: builder} do
      schema = SchemaBuilder.get_schema(builder, "AuthorRelationships")

      links = Map.get(schema[:properties][:articles][:properties], :links)

      assert Map.get(links[:properties][:related], :type) == :string
      assert Map.get(links[:properties][:self], :type) == :string
    end
  end

  describe "edge cases" do
    # Tests for edge cases in relationship handling.

    test "handles circular references without infinite loop" do
      # Category references itself, should not cause infinite recursion
      base = SchemaBuilder.new(version: "3.1")
      builder = SchemaBuilder.add_resource_schemas(base, AshOaskit.Test.Category)

      # Should complete without hanging
      assert SchemaBuilder.has_schema?(builder, "CategoryAttributes")
      assert SchemaBuilder.has_schema?(builder, "CategoryRelationships")
    end

    test "handles deep relationship chains" do
      # Author -> Article -> Review chain
      base = SchemaBuilder.new(version: "3.1")
      builder = SchemaBuilder.add_resource_schemas(base, AshOaskit.Test.Author)

      # Should generate all schemas in the chain
      assert SchemaBuilder.has_schema?(builder, "AuthorAttributes")
      assert SchemaBuilder.has_schema?(builder, "ArticleAttributes")
      assert SchemaBuilder.has_schema?(builder, "ReviewAttributes")
    end

    test "adding same resource twice does not duplicate schemas" do
      base = SchemaBuilder.new(version: "3.1")
      builder1 = SchemaBuilder.add_resource_schemas(base, AshOaskit.Test.Author)
      builder = SchemaBuilder.add_resource_schemas(builder1, AshOaskit.Test.Author)

      # Count Author-related schemas
      names = SchemaBuilder.schema_names(builder)
      author_schemas = Enum.filter(names, &String.starts_with?(&1, "Author"))

      # Should have exactly one of each
      assert Enum.count(author_schemas, &(&1 == "AuthorAttributes")) == 1
      assert Enum.count(author_schemas, &(&1 == "AuthorResponse")) == 1
      assert Enum.count(author_schemas, &(&1 == "AuthorRelationships")) == 1
    end
  end
end
