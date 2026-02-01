defmodule AshOaskit.ResourceIdentifierTest do
  @moduledoc """
  Tests for AshOaskit.ResourceIdentifier module.

  This test module verifies the generation of JSON:API resource identifier
  schemas for OpenAPI specifications, including:

  - Basic resource identifier objects
  - Nullable identifiers for to-one relationships
  - To-many relationship arrays
  - Complete relationship objects with links and meta
  - Polymorphic identifiers
  - OpenAPI 3.0 vs 3.1 nullable handling
  """

  use ExUnit.Case, async: true

  alias AshOaskit.ResourceIdentifier

  describe "build_identifier_schema/2" do
    test "generates basic identifier schema with type and id" do
      schema = ResourceIdentifier.build_identifier_schema("posts")

      assert schema[:type] == :object
      assert schema[:required] == ["type", "id"]
      assert schema[:properties][:type][:type] == :string
      assert schema[:properties][:type][:enum] == ["posts"]
      assert schema[:properties][:id][:type] == :string
    end

    test "includes meta field by default" do
      schema = ResourceIdentifier.build_identifier_schema("posts")

      assert Map.has_key?(schema[:properties], :meta)
      assert schema[:properties][:meta][:type] == :object
      assert schema[:properties][:meta][:additionalProperties] == true
    end

    test "can exclude meta field" do
      schema = ResourceIdentifier.build_identifier_schema("posts", include_meta: false)

      refute Map.has_key?(schema[:properties], :meta)
    end

    test "includes description" do
      schema = ResourceIdentifier.build_identifier_schema("posts")

      assert String.contains?(schema[:description], "posts")
    end

    test "works with various resource types" do
      for type <- ["users", "comments", "blog-posts", "api_keys"] do
        schema = ResourceIdentifier.build_identifier_schema(type)
        assert schema[:properties][:type][:enum] == [type]
      end
    end
  end

  describe "build_nullable_identifier_schema/2" do
    test "uses oneOf with null for OpenAPI 3.1" do
      schema = ResourceIdentifier.build_nullable_identifier_schema("author", version: "3.1")

      assert is_list(schema[:oneOf])
      assert length(schema[:oneOf]) == 2

      null_option = Enum.find(schema[:oneOf], &(&1[:type] == :null))
      assert null_option != nil

      object_option = Enum.find(schema[:oneOf], &(&1[:type] == :object))
      assert object_option != nil
    end

    test "uses nullable flag for OpenAPI 3.0" do
      schema = ResourceIdentifier.build_nullable_identifier_schema("author", version: "3.0")

      assert schema[:nullable] == true
      assert schema[:type] == :object
    end

    test "includes description mentioning nullable" do
      schema = ResourceIdentifier.build_nullable_identifier_schema("author", version: "3.1")

      assert String.contains?(schema[:description], "nullable")
    end

    test "preserves identifier properties in 3.0 mode" do
      schema = ResourceIdentifier.build_nullable_identifier_schema("author", version: "3.0")

      assert schema[:required] == ["type", "id"]
      assert schema[:properties][:type][:enum] == ["author"]
    end
  end

  describe "build_to_one_linkage_schema/2" do
    test "returns nullable schema when not required" do
      schema = ResourceIdentifier.build_to_one_linkage_schema("author", required: false)

      # Should be nullable (oneOf with null in 3.1)
      assert Map.has_key?(schema, :oneOf) or Map.has_key?(schema, :nullable)
    end

    test "returns non-nullable schema when required" do
      schema = ResourceIdentifier.build_to_one_linkage_schema("author", required: true)

      # Should not have nullable indicators
      refute Map.has_key?(schema, :oneOf)
      refute Map.has_key?(schema, :nullable)
      assert schema[:type] == :object
    end

    test "defaults to not required (nullable)" do
      schema = ResourceIdentifier.build_to_one_linkage_schema("author")

      assert Map.has_key?(schema, :oneOf) or Map.has_key?(schema, :nullable)
    end
  end

  describe "build_to_many_linkage_schema/2" do
    test "generates array schema" do
      schema = ResourceIdentifier.build_to_many_linkage_schema("comments")

      assert schema[:type] == :array
      assert is_map(schema[:items])
    end

    test "array items are resource identifiers" do
      schema = ResourceIdentifier.build_to_many_linkage_schema("comments")

      items = schema[:items]
      assert items[:type] == :object
      assert items[:required] == ["type", "id"]
      assert items[:properties][:type][:enum] == ["comments"]
    end

    test "includes description" do
      schema = ResourceIdentifier.build_to_many_linkage_schema("comments")

      assert String.contains?(schema[:description], "comments")
      assert String.contains?(schema[:description], "Array")
    end

    test "respects include_meta option" do
      with_meta = ResourceIdentifier.build_to_many_linkage_schema("comments", include_meta: true)

      without_meta =
        ResourceIdentifier.build_to_many_linkage_schema("comments", include_meta: false)

      assert Map.has_key?(with_meta[:items][:properties], :meta)
      refute Map.has_key?(without_meta[:items][:properties], :meta)
    end
  end

  describe "build_relationship_object_schema/2" do
    test "includes data property" do
      schema = ResourceIdentifier.build_relationship_object_schema("author")

      assert schema[:type] == :object
      assert Map.has_key?(schema[:properties], :data)
    end

    test "includes links by default" do
      schema = ResourceIdentifier.build_relationship_object_schema("author")

      assert Map.has_key?(schema[:properties], :links)
      assert Map.has_key?(schema[:properties][:links][:properties], :self)
      assert Map.has_key?(schema[:properties][:links][:properties], :related)
    end

    test "can exclude links" do
      schema = ResourceIdentifier.build_relationship_object_schema("author", include_links: false)

      refute Map.has_key?(schema[:properties], :links)
    end

    test "includes meta by default" do
      schema = ResourceIdentifier.build_relationship_object_schema("author")

      assert Map.has_key?(schema[:properties], :meta)
    end

    test "can exclude meta" do
      schema = ResourceIdentifier.build_relationship_object_schema("author", include_meta: false)

      refute Map.has_key?(schema[:properties], :meta)
    end

    test "respects to_one cardinality" do
      schema = ResourceIdentifier.build_relationship_object_schema("author", cardinality: :to_one)

      data = schema[:properties][:data]
      # To-one is nullable by default
      assert Map.has_key?(data, :oneOf) or Map.has_key?(data, :nullable) or
               data[:type] == :object
    end

    test "respects to_many cardinality" do
      schema =
        ResourceIdentifier.build_relationship_object_schema("comments", cardinality: :to_many)

      data = schema[:properties][:data]
      assert data[:type] == :array
    end

    test "defaults to to_one cardinality" do
      schema = ResourceIdentifier.build_relationship_object_schema("author")

      data = schema[:properties][:data]
      refute data[:type] == :array
    end
  end

  describe "build_relationships_object_schema/2" do
    test "generates schema for multiple relationships" do
      relationships = [
        {"author", :to_one},
        {"comments", :to_many}
      ]

      schema = ResourceIdentifier.build_relationships_object_schema(relationships)

      assert schema[:type] == :object
      assert Map.has_key?(schema[:properties], "author")
      assert Map.has_key?(schema[:properties], "comments")
    end

    test "respects cardinality for each relationship" do
      relationships = [
        {"author", :to_one},
        {"tags", :to_many}
      ]

      schema = ResourceIdentifier.build_relationships_object_schema(relationships)

      author_data = schema[:properties]["author"][:properties][:data]
      tags_data = schema[:properties]["tags"][:properties][:data]

      # Author should be nullable object (to_one)
      refute author_data[:type] == :array

      # Tags should be array (to_many)
      assert tags_data[:type] == :array
    end

    test "handles empty relationships list" do
      schema = ResourceIdentifier.build_relationships_object_schema([])

      assert schema[:type] == :object
      assert schema[:properties] == %{}
    end
  end

  describe "build_linkage_data_schema/2" do
    test "wraps data in required object" do
      schema = ResourceIdentifier.build_linkage_data_schema("comments", cardinality: :to_many)

      assert schema[:type] == :object
      assert schema[:required] == ["data"]
      assert Map.has_key?(schema[:properties], :data)
    end

    test "uses to_many linkage for to_many cardinality" do
      schema = ResourceIdentifier.build_linkage_data_schema("comments", cardinality: :to_many)

      assert schema[:properties][:data][:type] == :array
    end

    test "uses to_one linkage for to_one cardinality" do
      schema = ResourceIdentifier.build_linkage_data_schema("author", cardinality: :to_one)

      data = schema[:properties][:data]
      refute data[:type] == :array
    end

    test "defaults to to_one cardinality" do
      schema = ResourceIdentifier.build_linkage_data_schema("author")

      data = schema[:properties][:data]
      refute data[:type] == :array
    end
  end

  describe "build_identifier_component_schemas/2" do
    test "generates multiple schemas for resource" do
      schemas = ResourceIdentifier.build_identifier_component_schemas("Post")

      assert Map.has_key?(schemas, "PostIdentifier")
      assert Map.has_key?(schemas, "PostIdentifierArray")
      assert Map.has_key?(schemas, "RelationshipLinks")
    end

    test "respects name prefix" do
      schemas =
        ResourceIdentifier.build_identifier_component_schemas("Post", name_prefix: "JsonApi")

      assert Map.has_key?(schemas, "JsonApiPostIdentifier")
      assert Map.has_key?(schemas, "JsonApiPostIdentifierArray")
      assert Map.has_key?(schemas, "JsonApiRelationshipLinks")
    end

    test "uses lowercase resource type in schemas" do
      schemas = ResourceIdentifier.build_identifier_component_schemas("Post")

      identifier = schemas["PostIdentifier"]
      assert identifier[:properties][:type][:enum] == ["post"]
    end
  end

  describe "build_generic_identifier_schema/1" do
    test "generates identifier without specific type enum" do
      schema = ResourceIdentifier.build_generic_identifier_schema()

      assert schema[:type] == :object
      assert schema[:required] == ["type", "id"]
      assert schema[:properties][:type][:type] == :string
      refute Map.has_key?(schema[:properties][:type], :enum)
    end

    test "includes meta field" do
      schema = ResourceIdentifier.build_generic_identifier_schema()

      assert Map.has_key?(schema[:properties], :meta)
    end

    test "has generic description" do
      schema = ResourceIdentifier.build_generic_identifier_schema()

      assert schema[:description] == "Generic resource identifier"
    end
  end

  describe "build_polymorphic_identifier_schema/2" do
    test "generates identifier with multiple types" do
      schema = ResourceIdentifier.build_polymorphic_identifier_schema(["posts", "comments"])

      assert schema[:type] == :object
      assert schema[:properties][:type][:enum] == ["posts", "comments"]
    end

    test "includes all types in description" do
      schema =
        ResourceIdentifier.build_polymorphic_identifier_schema(["posts", "comments", "users"])

      description = schema[:properties][:type][:description]
      assert String.contains?(description, "posts")
      assert String.contains?(description, "comments")
      assert String.contains?(description, "users")
    end

    test "includes meta field" do
      schema = ResourceIdentifier.build_polymorphic_identifier_schema(["posts"])

      assert Map.has_key?(schema[:properties], :meta)
    end

    test "handles single type list" do
      schema = ResourceIdentifier.build_polymorphic_identifier_schema(["posts"])

      assert schema[:properties][:type][:enum] == ["posts"]
    end

    test "handles empty type list" do
      schema = ResourceIdentifier.build_polymorphic_identifier_schema([])

      assert schema[:properties][:type][:enum] == []
    end
  end

  describe "relationship object version-specific behavior" do
    test "relationship object with 3.0 version has URI format links" do
      schema =
        ResourceIdentifier.build_relationship_object_schema("author",
          version: "3.0",
          cardinality: :to_one
        )

      links = schema[:properties][:links]
      assert links[:properties][:self][:format] == :uri
    end
  end

  describe "schema structure validation" do
    test "all schemas are valid JSON Schema objects" do
      schemas = [
        ResourceIdentifier.build_identifier_schema("posts"),
        ResourceIdentifier.build_nullable_identifier_schema("author"),
        ResourceIdentifier.build_to_one_linkage_schema("author"),
        ResourceIdentifier.build_to_many_linkage_schema("comments"),
        ResourceIdentifier.build_relationship_object_schema("author"),
        ResourceIdentifier.build_linkage_data_schema("comments"),
        ResourceIdentifier.build_generic_identifier_schema(),
        ResourceIdentifier.build_polymorphic_identifier_schema(["posts", "comments"])
      ]

      for schema <- schemas do
        assert is_map(schema)
        assert Map.has_key?(schema, :type) or Map.has_key?(schema, :oneOf)
      end
    end

    test "all schemas can be serialized to JSON" do
      schemas = ResourceIdentifier.build_identifier_component_schemas("Post")

      assert {:ok, _json} = Jason.encode(schemas)
    end

    test "identifier schemas have proper required fields" do
      schema = ResourceIdentifier.build_identifier_schema("posts")

      assert "type" in schema[:required]
      assert "id" in schema[:required]
    end
  end

  describe "integration scenarios" do
    test "building a complete resource with relationships" do
      # Build relationships schema
      relationships = [
        {"author", :to_one},
        {"comments", :to_many},
        {"tags", :to_many}
      ]

      rel_schema = ResourceIdentifier.build_relationships_object_schema(relationships)

      # Should have all three relationships
      assert map_size(rel_schema[:properties]) == 3

      # Author is to-one (nullable by default)
      author = rel_schema[:properties]["author"]
      assert is_map(author[:properties][:data])

      # Comments is to-many (array)
      comments = rel_schema[:properties]["comments"]
      assert comments[:properties][:data][:type] == :array
    end

    test "building relationship request body for POST to relationship" do
      # POST /posts/1/relationships/tags
      schema = ResourceIdentifier.build_linkage_data_schema("tags", cardinality: :to_many)

      assert schema[:required] == ["data"]
      assert schema[:properties][:data][:type] == :array
    end

    test "building relationship request body for PATCH to relationship" do
      # PATCH /posts/1/relationships/author
      schema = ResourceIdentifier.build_linkage_data_schema("author", cardinality: :to_one)

      assert schema[:required] == ["data"]
      # To-one can be null to unset the relationship
      data = schema[:properties][:data]

      assert Map.has_key?(data, :oneOf) or Map.has_key?(data, :nullable) or
               data[:type] == :object
    end

    test "building polymorphic relationship (e.g., commentable)" do
      # A comment can belong to either a post or a page
      schema = ResourceIdentifier.build_polymorphic_identifier_schema(["posts", "pages"])

      # Should accept either type
      assert "posts" in schema[:properties][:type][:enum]
      assert "pages" in schema[:properties][:type][:enum]
    end
  end
end
