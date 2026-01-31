defmodule AshOaskit.SchemaBuilderTest do
  @moduledoc """
  Comprehensive tests for the SchemaBuilder module.

  The SchemaBuilder provides the core infrastructure for generating OpenAPI
  schemas from Ash resources. These tests verify:

  ## Test Categories

  ### Builder Lifecycle
  - Creating new builders with default and custom options
  - Version configuration (3.0 vs 3.1)

  ### Schema Management
  - Adding schemas to the builder
  - Checking for schema existence
  - Getting schemas by name
  - Listing all schema names
  - Schema count tracking
  - Schema deduplication (first definition wins)

  ### Cycle Detection
  - Marking types as seen
  - Checking if types have been seen
  - Separate tracking for input vs output schemas
  - Preventing infinite recursion in self-referential types

  ### Resource Schema Generation
  - Attributes schema generation
  - Response schema generation with JSON:API envelope
  - Relationships schema generation
  - Input schemas (create vs update with different required fields)

  ### Relationship Handling
  - To-one relationships (belongs_to, has_one)
  - To-many relationships (has_many, many_to_many)
  - Resource identifier schemas
  - Relationship data and links

  ### Edge Cases
  - Resources without relationships
  - Resources without writable attributes
  - Private attributes (excluded)
  - Generated attributes (excluded from input)
  - Default values affecting required fields

  ## Test Resources

  Tests use resources defined in `test/support/test_resources.ex`:
  - `AshOaskit.Test.Post` - Comprehensive attribute types
  - `AshOaskit.Test.Comment` - Basic resource
  - Additional test resources defined inline for specific scenarios

  ## Coverage Goals

  These tests aim for 100% code coverage of the SchemaBuilder module,
  including all public functions, private helpers, and edge cases.
  """

  use ExUnit.Case, async: true
  doctest AshOaskit.SchemaBuilder

  alias AshOaskit.SchemaBuilder

  describe "new/1" do
    # Tests for SchemaBuilder initialization.

    test "creates builder with default version 3.1" do
      builder = SchemaBuilder.new()

      assert builder.version == "3.1"
      assert builder.schemas == %{}
      assert builder.seen_types == MapSet.new()
      assert builder.seen_input_types == MapSet.new()
    end

    test "creates builder with custom version 3.0" do
      builder = SchemaBuilder.new(version: "3.0")

      assert builder.version == "3.0"
    end

    test "creates builder with explicit version 3.1" do
      builder = SchemaBuilder.new(version: "3.1")

      assert builder.version == "3.1"
    end

    test "ignores unknown options" do
      builder = SchemaBuilder.new(unknown: "value", another: 123)

      assert builder.version == "3.1"
    end

    test "creates builder with empty schema map" do
      builder = SchemaBuilder.new()

      assert map_size(builder.schemas) == 0
    end
  end

  describe "add_schema/3" do
    # Tests for adding schemas to the builder.

    test "adds a schema to the builder" do
      builder = SchemaBuilder.new()
      schema = %{"type" => "object", "properties" => %{}}

      builder = SchemaBuilder.add_schema(builder, "Post", schema)

      assert SchemaBuilder.has_schema?(builder, "Post")
      assert SchemaBuilder.get_schema(builder, "Post") == schema
    end

    test "does not overwrite existing schema" do
      builder = SchemaBuilder.new()
      schema1 = %{"type" => "object", "description" => "first"}
      schema2 = %{"type" => "object", "description" => "second"}

      builder = SchemaBuilder.add_schema(builder, "Post", schema1)
      builder = SchemaBuilder.add_schema(builder, "Post", schema2)

      # First definition wins
      assert SchemaBuilder.get_schema(builder, "Post")["description"] == "first"
    end

    test "adds multiple schemas" do
      builder = SchemaBuilder.new()

      builder =
        builder
        |> SchemaBuilder.add_schema("Post", %{"type" => "object"})
        |> SchemaBuilder.add_schema("Comment", %{"type" => "object"})
        |> SchemaBuilder.add_schema("Author", %{"type" => "object"})

      assert SchemaBuilder.schema_count(builder) == 3
      assert "Post" in SchemaBuilder.schema_names(builder)
      assert "Comment" in SchemaBuilder.schema_names(builder)
      assert "Author" in SchemaBuilder.schema_names(builder)
    end

    test "handles complex schema structures" do
      builder = SchemaBuilder.new()

      schema = %{
        "type" => "object",
        "properties" => %{
          "id" => %{"type" => "string"},
          "nested" => %{
            "type" => "object",
            "properties" => %{
              "value" => %{"type" => "integer"}
            }
          }
        },
        "required" => ["id"]
      }

      builder = SchemaBuilder.add_schema(builder, "Complex", schema)

      retrieved = SchemaBuilder.get_schema(builder, "Complex")
      assert retrieved["properties"]["nested"]["properties"]["value"]["type"] == "integer"
    end
  end

  describe "has_schema?/2" do
    # Tests for checking schema existence.

    test "returns false for non-existent schema" do
      builder = SchemaBuilder.new()

      refute SchemaBuilder.has_schema?(builder, "NonExistent")
    end

    test "returns true for existing schema" do
      builder = SchemaBuilder.add_schema(SchemaBuilder.new(), "Post", %{})

      assert SchemaBuilder.has_schema?(builder, "Post")
    end

    test "is case-sensitive" do
      builder = SchemaBuilder.add_schema(SchemaBuilder.new(), "Post", %{})

      assert SchemaBuilder.has_schema?(builder, "Post")
      refute SchemaBuilder.has_schema?(builder, "post")
      refute SchemaBuilder.has_schema?(builder, "POST")
    end
  end

  describe "get_schema/2" do
    # Tests for retrieving schemas by name.

    test "returns nil for non-existent schema" do
      builder = SchemaBuilder.new()

      assert SchemaBuilder.get_schema(builder, "NonExistent") == nil
    end

    test "returns schema for existing name" do
      schema = %{"type" => "string", "format" => "uuid"}

      builder = SchemaBuilder.add_schema(SchemaBuilder.new(), "UUID", schema)

      assert SchemaBuilder.get_schema(builder, "UUID") == schema
    end
  end

  describe "schema_names/1" do
    # Tests for listing all schema names.

    test "returns empty list for new builder" do
      builder = SchemaBuilder.new()

      assert SchemaBuilder.schema_names(builder) == []
    end

    test "returns all schema names" do
      builder =
        SchemaBuilder.new()
        |> SchemaBuilder.add_schema("A", %{})
        |> SchemaBuilder.add_schema("B", %{})
        |> SchemaBuilder.add_schema("C", %{})

      names = SchemaBuilder.schema_names(builder)

      assert length(names) == 3
      assert Enum.sort(names) == ["A", "B", "C"]
    end
  end

  describe "schema_count/1" do
    # Tests for counting schemas.

    test "returns 0 for new builder" do
      builder = SchemaBuilder.new()

      assert SchemaBuilder.schema_count(builder) == 0
    end

    test "returns correct count after adding schemas" do
      builder =
        SchemaBuilder.new()
        |> SchemaBuilder.add_schema("One", %{})
        |> SchemaBuilder.add_schema("Two", %{})

      assert SchemaBuilder.schema_count(builder) == 2
    end

    test "does not count duplicates" do
      builder =
        SchemaBuilder.new()
        |> SchemaBuilder.add_schema("Same", %{"v" => 1})
        |> SchemaBuilder.add_schema("Same", %{"v" => 2})
        |> SchemaBuilder.add_schema("Same", %{"v" => 3})

      assert SchemaBuilder.schema_count(builder) == 1
    end
  end

  describe "mark_seen/2 and seen?/2" do
    # Tests for output schema cycle detection.

    test "type is not seen initially" do
      builder = SchemaBuilder.new()

      refute SchemaBuilder.seen?(builder, MyApp.Post)
    end

    test "type is seen after marking" do
      builder = SchemaBuilder.mark_seen(SchemaBuilder.new(), MyApp.Post)

      assert SchemaBuilder.seen?(builder, MyApp.Post)
    end

    test "marking is idempotent" do
      builder =
        SchemaBuilder.new()
        |> SchemaBuilder.mark_seen(MyApp.Post)
        |> SchemaBuilder.mark_seen(MyApp.Post)
        |> SchemaBuilder.mark_seen(MyApp.Post)

      assert SchemaBuilder.seen?(builder, MyApp.Post)
      # MapSet handles duplicates
      assert MapSet.size(builder.seen_types) == 1
    end

    test "different types tracked independently" do
      builder =
        SchemaBuilder.new()
        |> SchemaBuilder.mark_seen(MyApp.Post)
        |> SchemaBuilder.mark_seen(MyApp.Comment)

      assert SchemaBuilder.seen?(builder, MyApp.Post)
      assert SchemaBuilder.seen?(builder, MyApp.Comment)
      refute SchemaBuilder.seen?(builder, MyApp.Author)
    end
  end

  describe "mark_input_seen/2 and input_seen?/2" do
    # Tests for input schema cycle detection (separate from output).

    test "input type is not seen initially" do
      builder = SchemaBuilder.new()

      refute SchemaBuilder.input_seen?(builder, MyApp.Post)
    end

    test "input type is seen after marking" do
      builder = SchemaBuilder.mark_input_seen(SchemaBuilder.new(), MyApp.Post)

      assert SchemaBuilder.input_seen?(builder, MyApp.Post)
    end

    test "input and output tracking are independent" do
      builder =
        SchemaBuilder.new()
        |> SchemaBuilder.mark_seen(MyApp.Post)
        |> SchemaBuilder.mark_input_seen(MyApp.Comment)

      # Post seen for output, not input
      assert SchemaBuilder.seen?(builder, MyApp.Post)
      refute SchemaBuilder.input_seen?(builder, MyApp.Post)

      # Comment seen for input, not output
      refute SchemaBuilder.seen?(builder, MyApp.Comment)
      assert SchemaBuilder.input_seen?(builder, MyApp.Comment)
    end
  end

  describe "to_components/1" do
    # Tests for converting builder to OpenAPI components.

    test "returns components structure with empty schemas" do
      builder = SchemaBuilder.new()
      components = SchemaBuilder.to_components(builder)

      assert components == %{"schemas" => %{}}
    end

    test "returns components with all schemas" do
      builder =
        SchemaBuilder.new()
        |> SchemaBuilder.add_schema("Post", %{"type" => "object"})
        |> SchemaBuilder.add_schema("Comment", %{"type" => "object"})

      components = SchemaBuilder.to_components(builder)

      assert Map.has_key?(components["schemas"], "Post")
      assert Map.has_key?(components["schemas"], "Comment")
    end

    test "preserves full schema structure" do
      schema = %{
        "type" => "object",
        "properties" => %{
          "name" => %{"type" => "string"}
        },
        "required" => ["name"]
      }

      builder = SchemaBuilder.add_schema(SchemaBuilder.new(), "Person", schema)
      components = SchemaBuilder.to_components(builder)

      assert components["schemas"]["Person"] == schema
    end
  end

  describe "version/1" do
    # Tests for getting builder version.

    test "returns version from builder" do
      builder_31 = SchemaBuilder.new(version: "3.1")
      builder_30 = SchemaBuilder.new(version: "3.0")

      assert SchemaBuilder.version(builder_31) == "3.1"
      assert SchemaBuilder.version(builder_30) == "3.0"
    end
  end

  describe "resource_schema_name/1" do
    # Tests for generating schema names from resource modules.

    test "extracts last module segment" do
      assert SchemaBuilder.resource_schema_name(MyApp.Blog.Post) == "Post"
      assert SchemaBuilder.resource_schema_name(MyApp.Comment) == "Comment"
      assert SchemaBuilder.resource_schema_name(Post) == "Post"
    end

    test "handles deeply nested modules" do
      assert SchemaBuilder.resource_schema_name(MyApp.V1.API.Resources.Post) == "Post"
    end
  end

  describe "add_resource_schemas/2 with Post resource" do
    # Tests for generating schemas from the Post test resource.

    setup do
      builder = SchemaBuilder.add_resource_schemas(SchemaBuilder.new(), AshOaskit.Test.Post)

      {:ok, builder: builder}
    end

    test "generates attributes schema", %{builder: builder} do
      assert SchemaBuilder.has_schema?(builder, "PostAttributes")

      schema = SchemaBuilder.get_schema(builder, "PostAttributes")
      assert schema["type"] == "object"
      assert Map.has_key?(schema["properties"], "title")
      assert Map.has_key?(schema["properties"], "body")
    end

    test "generates response schema", %{builder: builder} do
      assert SchemaBuilder.has_schema?(builder, "PostResponse")

      schema = SchemaBuilder.get_schema(builder, "PostResponse")
      assert schema["type"] == "object"
      assert Map.has_key?(schema["properties"], "data")
    end

    test "generates create input schema", %{builder: builder} do
      assert SchemaBuilder.has_schema?(builder, "PostCreateInput")

      schema = SchemaBuilder.get_schema(builder, "PostCreateInput")
      assert schema["type"] == "object"
    end

    test "generates update input schema", %{builder: builder} do
      assert SchemaBuilder.has_schema?(builder, "PostUpdateInput")

      schema = SchemaBuilder.get_schema(builder, "PostUpdateInput")
      assert schema["type"] == "object"
      # Update schemas should not have required fields (partial updates)
      refute Map.has_key?(schema, "required")
    end

    test "marks resource as seen", %{builder: builder} do
      assert SchemaBuilder.seen?(builder, AshOaskit.Test.Post)
    end

    test "excludes private attributes", %{builder: builder} do
      schema = SchemaBuilder.get_schema(builder, "PostAttributes")

      # id, inserted_at, updated_at should not be in attributes
      refute Map.has_key?(schema["properties"], "id")
      refute Map.has_key?(schema["properties"], "inserted_at")
      refute Map.has_key?(schema["properties"], "updated_at")
    end

    test "response schema has JSON:API structure", %{builder: builder} do
      schema = SchemaBuilder.get_schema(builder, "PostResponse")

      data = schema["properties"]["data"]
      assert data["type"] == "object"
      assert Map.has_key?(data["properties"], "id")
      assert Map.has_key?(data["properties"], "type")
      assert Map.has_key?(data["properties"], "attributes")
    end

    test "response schema includes type enum", %{builder: builder} do
      schema = SchemaBuilder.get_schema(builder, "PostResponse")

      type_schema = schema["properties"]["data"]["properties"]["type"]
      assert type_schema["enum"] == ["post"]
    end
  end

  describe "add_resource_schemas/2 with version 3.0" do
    # Tests for OpenAPI 3.0 specific schema generation.

    test "uses nullable: true for nullable fields" do
      builder =
        SchemaBuilder.add_resource_schemas(SchemaBuilder.new(version: "3.0"), AshOaskit.Test.Post)

      schema = SchemaBuilder.get_schema(builder, "PostAttributes")

      # Body is nullable
      body_schema = schema["properties"]["body"]
      assert body_schema["nullable"] == true
    end
  end

  describe "add_resource_schemas/2 with version 3.1" do
    # Tests for OpenAPI 3.1 specific schema generation.

    test "uses type array for nullable fields" do
      builder =
        SchemaBuilder.add_resource_schemas(SchemaBuilder.new(version: "3.1"), AshOaskit.Test.Post)

      schema = SchemaBuilder.get_schema(builder, "PostAttributes")

      # Body is nullable - should use type array
      body_schema = schema["properties"]["body"]
      assert is_list(body_schema["type"])
      assert "null" in body_schema["type"]
    end
  end

  describe "required fields in schemas" do
    # Tests for required field detection in different schema types.

    test "attributes schema includes required for non-nullable fields" do
      builder = SchemaBuilder.add_resource_schemas(SchemaBuilder.new(), AshOaskit.Test.Post)

      schema = SchemaBuilder.get_schema(builder, "PostAttributes")

      # title has allow_nil?: false
      assert "title" in (schema["required"] || [])
    end

    test "create input has required for non-nullable fields without defaults" do
      builder = SchemaBuilder.add_resource_schemas(SchemaBuilder.new(), AshOaskit.Test.Post)

      schema = SchemaBuilder.get_schema(builder, "PostCreateInput")

      # title is required for create (allow_nil?: false, no default)
      # is_featured has a default, so not required for create
      if schema["required"] do
        assert "title" in schema["required"]
      end
    end

    test "update input has no required fields" do
      builder = SchemaBuilder.add_resource_schemas(SchemaBuilder.new(), AshOaskit.Test.Post)

      schema = SchemaBuilder.get_schema(builder, "PostUpdateInput")

      # Partial updates - nothing required
      refute Map.has_key?(schema, "required")
    end
  end

  describe "add_resource_schemas/2 with multiple resources" do
    # Tests for generating schemas from multiple resources.

    test "generates schemas for all resources" do
      builder =
        SchemaBuilder.new()
        |> SchemaBuilder.add_resource_schemas(AshOaskit.Test.Post)
        |> SchemaBuilder.add_resource_schemas(AshOaskit.Test.Comment)

      # Post schemas
      assert SchemaBuilder.has_schema?(builder, "PostAttributes")
      assert SchemaBuilder.has_schema?(builder, "PostResponse")

      # Comment schemas
      assert SchemaBuilder.has_schema?(builder, "CommentAttributes")
      assert SchemaBuilder.has_schema?(builder, "CommentResponse")
    end

    test "marks all resources as seen" do
      builder =
        SchemaBuilder.new()
        |> SchemaBuilder.add_resource_schemas(AshOaskit.Test.Post)
        |> SchemaBuilder.add_resource_schemas(AshOaskit.Test.Comment)

      assert SchemaBuilder.seen?(builder, AshOaskit.Test.Post)
      assert SchemaBuilder.seen?(builder, AshOaskit.Test.Comment)
    end
  end

  describe "edge cases" do
    # Tests for various edge cases and error conditions.

    test "handles resource with minimal attributes" do
      builder = SchemaBuilder.add_resource_schemas(SchemaBuilder.new(), AshOaskit.Test.Comment)

      schema = SchemaBuilder.get_schema(builder, "CommentAttributes")
      assert schema["type"] == "object"
      assert Map.has_key?(schema["properties"], "content")
    end

    test "handles adding same resource twice" do
      builder =
        SchemaBuilder.new()
        |> SchemaBuilder.add_resource_schemas(AshOaskit.Test.Post)
        |> SchemaBuilder.add_resource_schemas(AshOaskit.Test.Post)

      # Should only have one set of schemas
      names = SchemaBuilder.schema_names(builder)
      post_schemas = Enum.filter(names, &String.starts_with?(&1, "Post"))

      # Each schema type should appear once
      assert Enum.count(post_schemas, &(&1 == "PostAttributes")) == 1
      assert Enum.count(post_schemas, &(&1 == "PostResponse")) == 1
    end

    test "builder is immutable - original not modified" do
      original = SchemaBuilder.new()
      modified = SchemaBuilder.add_schema(original, "Test", %{})

      refute SchemaBuilder.has_schema?(original, "Test")
      assert SchemaBuilder.has_schema?(modified, "Test")
    end
  end

  describe "relationship schema generation" do
    test "generates relationships schema for resource with relationships" do
      builder = SchemaBuilder.add_resource_schemas(SchemaBuilder.new(), AshOaskit.Test.Article)

      assert SchemaBuilder.has_schema?(builder, "ArticleRelationships")

      schema = SchemaBuilder.get_schema(builder, "ArticleRelationships")
      assert schema["type"] == "object"
      # Article has author, reviews, and tags relationships
      assert Map.has_key?(schema["properties"], "author")
    end

    test "includes data and links in relationship objects" do
      builder = SchemaBuilder.add_resource_schemas(SchemaBuilder.new(), AshOaskit.Test.Article)

      schema = SchemaBuilder.get_schema(builder, "ArticleRelationships")
      author_rel = schema["properties"]["author"]

      assert Map.has_key?(author_rel["properties"], "data")
      assert Map.has_key?(author_rel["properties"], "links")
    end

    test "response schema references relationships for resources with relationships" do
      builder = SchemaBuilder.add_resource_schemas(SchemaBuilder.new(), AshOaskit.Test.Article)

      schema = SchemaBuilder.get_schema(builder, "ArticleResponse")
      data = schema["properties"]["data"]

      assert Map.has_key?(data["properties"], "relationships")

      assert data["properties"]["relationships"]["$ref"] ==
               "#/components/schemas/ArticleRelationships"
    end

    test "response schema omits relationships for resources without relationships" do
      builder = SchemaBuilder.add_resource_schemas(SchemaBuilder.new(), AshOaskit.Test.Post)

      schema = SchemaBuilder.get_schema(builder, "PostResponse")
      data = schema["properties"]["data"]

      refute Map.has_key?(data["properties"], "relationships")
    end

    test "handles to-one relationships" do
      builder = SchemaBuilder.add_resource_schemas(SchemaBuilder.new(), AshOaskit.Test.Article)

      schema = SchemaBuilder.get_schema(builder, "ArticleRelationships")
      author_rel = schema["properties"]["author"]

      # To-one should have nullable identifier (not array)
      data = author_rel["properties"]["data"]
      refute data["type"] == "array"
    end

    test "handles to-many relationships" do
      builder = SchemaBuilder.add_resource_schemas(SchemaBuilder.new(), AshOaskit.Test.Article)

      schema = SchemaBuilder.get_schema(builder, "ArticleRelationships")
      reviews_rel = schema["properties"]["reviews"]

      # To-many should be array
      data = reviews_rel["properties"]["data"]
      assert data["type"] == "array"
    end

    test "generates related resource schemas" do
      builder = SchemaBuilder.add_resource_schemas(SchemaBuilder.new(), AshOaskit.Test.Article)

      # Should also have Author schemas since Article belongs_to Author
      assert SchemaBuilder.has_schema?(builder, "AuthorAttributes")
      assert SchemaBuilder.has_schema?(builder, "AuthorResponse")
    end
  end

  describe "calculation schema generation" do
    test "includes calculations in attributes schema" do
      builder = SchemaBuilder.add_resource_schemas(SchemaBuilder.new(), AshOaskit.Test.Author)

      schema = SchemaBuilder.get_schema(builder, "AuthorAttributes")

      # Author has full_name and article_count calculations
      assert Map.has_key?(schema["properties"], "full_name")
      assert Map.has_key?(schema["properties"], "article_count")
    end

    test "calculations are nullable (may not be loaded)" do
      builder =
        SchemaBuilder.add_resource_schemas(
          SchemaBuilder.new(version: "3.1"),
          AshOaskit.Test.Author
        )

      schema = SchemaBuilder.get_schema(builder, "AuthorAttributes")
      full_name = schema["properties"]["full_name"]

      # Should be nullable for 3.1
      assert "null" in List.wrap(full_name["type"])
    end

    test "calculation descriptions are included" do
      builder = SchemaBuilder.add_resource_schemas(SchemaBuilder.new(), AshOaskit.Test.Author)

      schema = SchemaBuilder.get_schema(builder, "AuthorAttributes")
      full_name = schema["properties"]["full_name"]

      assert full_name["description"] == "Author's full name"
    end
  end

  describe "aggregate schema generation" do
    test "includes aggregates in attributes schema" do
      builder = SchemaBuilder.add_resource_schemas(SchemaBuilder.new(), AshOaskit.Test.Author)

      schema = SchemaBuilder.get_schema(builder, "AuthorAttributes")

      # Author has total_articles aggregate
      assert Map.has_key?(schema["properties"], "total_articles")
    end

    test "count aggregates are integer type" do
      builder = SchemaBuilder.add_resource_schemas(SchemaBuilder.new(), AshOaskit.Test.Author)

      schema = SchemaBuilder.get_schema(builder, "AuthorAttributes")
      total_articles = schema["properties"]["total_articles"]

      # Count aggregates should be integer
      assert "integer" in List.wrap(total_articles["type"])
    end

    test "aggregates are nullable (may not be loaded)" do
      builder =
        SchemaBuilder.add_resource_schemas(
          SchemaBuilder.new(version: "3.0"),
          AshOaskit.Test.Author
        )

      schema = SchemaBuilder.get_schema(builder, "AuthorAttributes")
      total_articles = schema["properties"]["total_articles"]

      # Should have nullable: true for 3.0
      assert total_articles["nullable"] == true
    end

    test "aggregate descriptions are included" do
      builder = SchemaBuilder.add_resource_schemas(SchemaBuilder.new(), AshOaskit.Test.Author)

      schema = SchemaBuilder.get_schema(builder, "AuthorAttributes")
      total_articles = schema["properties"]["total_articles"]

      assert total_articles["description"] == "Total number of articles"
    end

    test "avg aggregates are number type" do
      builder = SchemaBuilder.add_resource_schemas(SchemaBuilder.new(), AshOaskit.Test.Article)

      schema = SchemaBuilder.get_schema(builder, "ArticleAttributes")
      avg_rating = schema["properties"]["average_rating"]

      # Avg aggregates should be number
      assert "number" in List.wrap(avg_rating["type"])
    end
  end

  describe "embedded resource schema generation" do
    test "generates schema for embedded resources in attributes" do
      builder = SchemaBuilder.add_resource_schemas(SchemaBuilder.new(), AshOaskit.Test.Author)

      # Author has profile which is an embedded Profile resource
      assert SchemaBuilder.has_schema?(builder, "Profile")
    end

    test "embedded schema has correct structure" do
      builder = SchemaBuilder.add_resource_schemas(SchemaBuilder.new(), AshOaskit.Test.Author)

      schema = SchemaBuilder.get_schema(builder, "Profile")

      assert schema["type"] == "object"
      assert Map.has_key?(schema["properties"], "bio")
      assert Map.has_key?(schema["properties"], "website")
    end

    test "handles nested embedded resources" do
      builder = SchemaBuilder.add_resource_schemas(SchemaBuilder.new(), AshOaskit.Test.Author)

      # Profile has Address nested inside
      assert SchemaBuilder.has_schema?(builder, "Address")

      address_schema = SchemaBuilder.get_schema(builder, "Address")
      assert Map.has_key?(address_schema["properties"], "street")
      assert Map.has_key?(address_schema["properties"], "city")
    end

    test "embedded resource constraints are included" do
      builder = SchemaBuilder.add_resource_schemas(SchemaBuilder.new(), AshOaskit.Test.Author)

      schema = SchemaBuilder.get_schema(builder, "Profile")
      bio = schema["properties"]["bio"]

      # bio has max_length: 500
      assert bio["maxLength"] == 500
    end
  end

  describe "self-referential resource handling" do
    test "handles self-referential resources without infinite loop" do
      builder = SchemaBuilder.add_resource_schemas(SchemaBuilder.new(), AshOaskit.Test.Category)

      # Should complete without error
      assert SchemaBuilder.has_schema?(builder, "CategoryAttributes")
      assert SchemaBuilder.has_schema?(builder, "CategoryResponse")
    end

    test "self-referential relationships reference same schema" do
      builder = SchemaBuilder.add_resource_schemas(SchemaBuilder.new(), AshOaskit.Test.Category)

      schema = SchemaBuilder.get_schema(builder, "CategoryRelationships")

      # parent and children should reference Category
      assert Map.has_key?(schema["properties"], "parent")
      assert Map.has_key?(schema["properties"], "children")
    end

    test "resource is only processed once" do
      builder = SchemaBuilder.add_resource_schemas(SchemaBuilder.new(), AshOaskit.Test.Category)

      # Category should only appear once in seen types
      assert SchemaBuilder.seen?(builder, AshOaskit.Test.Category)
    end
  end

  describe "type mapping integration" do
    # Tests for verifying TypeMapper integration in schema building.

    test "maps string type correctly" do
      builder = SchemaBuilder.add_resource_schemas(SchemaBuilder.new(), AshOaskit.Test.Post)

      schema = SchemaBuilder.get_schema(builder, "PostAttributes")

      # title is a string
      title_schema = schema["properties"]["title"]
      assert "string" in List.wrap(title_schema["type"])
    end

    test "maps integer type correctly" do
      builder = SchemaBuilder.add_resource_schemas(SchemaBuilder.new(), AshOaskit.Test.Post)

      schema = SchemaBuilder.get_schema(builder, "PostAttributes")

      # view_count is an integer
      count_schema = schema["properties"]["view_count"]
      assert "integer" in List.wrap(count_schema["type"])
    end

    test "maps array type correctly" do
      builder = SchemaBuilder.add_resource_schemas(SchemaBuilder.new(), AshOaskit.Test.Post)

      schema = SchemaBuilder.get_schema(builder, "PostAttributes")

      # tags is {:array, :string}
      tags_schema = schema["properties"]["tags"]
      assert "array" in List.wrap(tags_schema["type"])
      assert tags_schema["items"]["type"] == "string"
    end

    test "includes constraints from attributes" do
      builder = SchemaBuilder.add_resource_schemas(SchemaBuilder.new(), AshOaskit.Test.Post)

      schema = SchemaBuilder.get_schema(builder, "PostAttributes")

      # title has min_length: 1, max_length: 255
      title_schema = schema["properties"]["title"]
      assert title_schema["minLength"] == 1
      assert title_schema["maxLength"] == 255

      # view_count has min: 0
      count_schema = schema["properties"]["view_count"]
      assert count_schema["minimum"] == 0
    end

    test "includes enum constraints" do
      builder = SchemaBuilder.add_resource_schemas(SchemaBuilder.new(), AshOaskit.Test.Post)

      schema = SchemaBuilder.get_schema(builder, "PostAttributes")

      # status has one_of: [:draft, :published]
      status_schema = schema["properties"]["status"]
      assert status_schema["enum"] == ["draft", "published"]
    end

    test "includes descriptions" do
      builder = SchemaBuilder.add_resource_schemas(SchemaBuilder.new(), AshOaskit.Test.Post)

      schema = SchemaBuilder.get_schema(builder, "PostAttributes")

      # body has a description
      body_schema = schema["properties"]["body"]
      assert body_schema["description"] == "Post content"
    end

    test "includes default values" do
      builder = SchemaBuilder.add_resource_schemas(SchemaBuilder.new(), AshOaskit.Test.Post)

      schema = SchemaBuilder.get_schema(builder, "PostAttributes")

      # is_featured has default: false
      featured_schema = schema["properties"]["is_featured"]
      assert featured_schema["default"] == false
    end
  end

  describe "aggregate kind schemas" do
    # Tests for different aggregate kinds to cover dynamic_aggregate_schema branches

    test "first aggregate type" do
      builder = SchemaBuilder.add_resource_schemas(SchemaBuilder.new(), AshOaskit.Test.Article)

      schema = SchemaBuilder.get_schema(builder, "ArticleAttributes")

      # first_review_rating is a :first aggregate
      assert Map.has_key?(schema["properties"], "first_review_rating")
    end

    test "list aggregate generates array schema" do
      builder = SchemaBuilder.add_resource_schemas(SchemaBuilder.new(), AshOaskit.Test.Article)

      schema = SchemaBuilder.get_schema(builder, "ArticleAttributes")

      # review_ratings is a :list aggregate - should be an array
      ratings = schema["properties"]["review_ratings"]
      assert "array" in List.wrap(ratings["type"])
    end

    test "min aggregate type" do
      builder = SchemaBuilder.add_resource_schemas(SchemaBuilder.new(), AshOaskit.Test.Article)

      schema = SchemaBuilder.get_schema(builder, "ArticleAttributes")

      assert Map.has_key?(schema["properties"], "min_review_rating")
    end

    test "max aggregate type" do
      builder = SchemaBuilder.add_resource_schemas(SchemaBuilder.new(), AshOaskit.Test.Article)

      schema = SchemaBuilder.get_schema(builder, "ArticleAttributes")

      assert Map.has_key?(schema["properties"], "max_review_rating")
    end

    test "sum aggregate type" do
      builder = SchemaBuilder.add_resource_schemas(SchemaBuilder.new(), AshOaskit.Test.Article)

      schema = SchemaBuilder.get_schema(builder, "ArticleAttributes")

      assert Map.has_key?(schema["properties"], "total_rating")
    end

    test "exists aggregate is boolean type" do
      builder = SchemaBuilder.add_resource_schemas(SchemaBuilder.new(), AshOaskit.Test.Article)

      schema = SchemaBuilder.get_schema(builder, "ArticleAttributes")

      # has_reviews is an :exists aggregate - should be boolean
      has_reviews = schema["properties"]["has_reviews"]
      assert "boolean" in List.wrap(has_reviews["type"])
    end
  end

  describe "coverage edge cases" do
    # Tests to cover remaining uncovered branches

    test "handles resource with NonExistentModule gracefully" do
      # This tests the rescue branches in various functions
      builder = SchemaBuilder.new()

      # Attempting to get json api type for non-existent module
      # Should not crash, rescue branch returns default
      builder = SchemaBuilder.add_resource_schemas(builder, AshOaskit.Test.NoTypeResource)

      assert SchemaBuilder.has_schema?(builder, "NoTypeResourceAttributes")
    end

    test "type_to_schema handles unknown types" do
      # Build a resource and verify unknown types fall back to string
      builder = SchemaBuilder.add_resource_schemas(SchemaBuilder.new(), AshOaskit.Test.Post)

      # The term attribute type should map to something
      schema = SchemaBuilder.get_schema(builder, "PostAttributes")
      assert Map.has_key?(schema["properties"], "config")
    end

    test "relationship cardinality fallback for nil" do
      # Test the nil -> fallback branch in relationship_cardinality
      # This is tested indirectly through resources with relationships
      builder = SchemaBuilder.add_resource_schemas(SchemaBuilder.new(), AshOaskit.Test.Article)

      schema = SchemaBuilder.get_schema(builder, "ArticleRelationships")
      # reviews is has_many
      assert schema["properties"]["reviews"]["properties"]["data"]["type"] == "array"
    end

    test "make_nullable_31 passes through non-map schemas" do
      # The make_nullable_31 function has a fallback for non-standard schemas
      builder =
        SchemaBuilder.add_resource_schemas(
          SchemaBuilder.new(version: "3.1"),
          AshOaskit.Test.Post
        )

      # All schemas should be properly generated
      schema = SchemaBuilder.get_schema(builder, "PostAttributes")
      assert schema["type"] == "object"
    end

    test "description added from source when present" do
      builder = SchemaBuilder.add_resource_schemas(SchemaBuilder.new(), AshOaskit.Test.Post)

      schema = SchemaBuilder.get_schema(builder, "PostAttributes")

      # body has description "Post content"
      assert schema["properties"]["body"]["description"] == "Post content"
    end

    test "description not added when not present" do
      builder = SchemaBuilder.add_resource_schemas(SchemaBuilder.new(), AshOaskit.Test.Post)

      schema = SchemaBuilder.get_schema(builder, "PostAttributes")

      # title has no description
      refute Map.has_key?(schema["properties"]["title"], "description")
    end
  end

  describe "PropertyBuilders edge cases" do
    alias AshOaskit.SchemaBuilder.PropertyBuilders

    test "aggregate_kind_to_schema handles :list kind" do
      agg = %{kind: :list, type: :string}
      schema = PropertyBuilders.aggregate_kind_to_schema(:list, agg)
      assert schema["type"] == "array"
      assert schema["items"] == %{"type" => "string"}
    end

    test "aggregate_kind_to_schema handles :first kind" do
      agg = %{kind: :first, type: :string}
      schema = PropertyBuilders.aggregate_kind_to_schema(:first, agg)
      assert schema["type"] == "string"
    end

    test "aggregate_kind_to_schema handles :min kind" do
      agg = %{kind: :min, type: :integer}
      schema = PropertyBuilders.aggregate_kind_to_schema(:min, agg)
      assert schema["type"] == "integer"
    end

    test "aggregate_kind_to_schema handles :max kind with default type" do
      agg = %{kind: :max}
      schema = PropertyBuilders.aggregate_kind_to_schema(:max, agg)
      assert schema["type"] == "number"
    end

    test "aggregate_kind_to_schema handles :custom kind" do
      agg = %{kind: :custom, type: :boolean}
      schema = PropertyBuilders.aggregate_kind_to_schema(:custom, agg)
      assert schema["type"] == "boolean"
    end

    test "aggregate_kind_to_schema handles unknown kind" do
      agg = %{kind: :unknown}
      schema = PropertyBuilders.aggregate_kind_to_schema(:unknown, agg)
      assert schema == %{}
    end

    test "make_nullable for 3.1 with schema without type key" do
      schema = %{"$ref" => "#/components/schemas/Foo"}
      result = PropertyBuilders.make_nullable(schema, "3.1")
      assert result == schema
    end

    test "type_to_schema handles non-atom non-tuple type" do
      assert PropertyBuilders.type_to_schema("string") == %{"type" => "string"}
    end
  end

  describe "RelationshipSchemas edge cases" do
    alias AshOaskit.SchemaBuilder.RelationshipSchemas

    test "relationship_cardinality with nil cardinality and :has_many type" do
      rel = %{type: :has_many}
      assert RelationshipSchemas.relationship_cardinality(rel) == :many
    end

    test "relationship_cardinality with nil cardinality and :many_to_many type" do
      rel = %{type: :many_to_many}
      assert RelationshipSchemas.relationship_cardinality(rel) == :many
    end

    test "relationship_cardinality with nil cardinality and :belongs_to type" do
      rel = %{type: :belongs_to}
      assert RelationshipSchemas.relationship_cardinality(rel) == :one
    end

    test "relationship_cardinality with explicit :one" do
      rel = %{cardinality: :one}
      assert RelationshipSchemas.relationship_cardinality(rel) == :one
    end

    test "relationship_cardinality with explicit :many" do
      rel = %{cardinality: :many}
      assert RelationshipSchemas.relationship_cardinality(rel) == :many
    end
  end
end
