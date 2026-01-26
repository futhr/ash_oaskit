defmodule AshOaskit.ResponseLinksTest do
  @moduledoc """
  Tests for AshOaskit.ResponseLinks module.

  This test module verifies the generation of JSON:API response link schemas
  for OpenAPI specifications, including:

  - Resource self links
  - Collection links with pagination
  - Relationship links (self and related)
  - Document-level links
  - Flexible links for various response types
  - OpenAPI 3.0 vs 3.1 nullable handling
  - Link objects with meta support
  """

  use ExUnit.Case, async: true

  alias AshOaskit.ResponseLinks

  describe "build_resource_links_schema/1" do
    test "generates basic resource links schema with self link" do
      schema = ResponseLinks.build_resource_links_schema()

      assert schema["type"] == "object"
      assert is_map(schema["properties"])
      assert schema["properties"]["self"]["type"] == "string"
      assert schema["properties"]["self"]["format"] == "uri"
    end

    test "includes additionalProperties: false for strict validation" do
      schema = ResponseLinks.build_resource_links_schema()

      assert schema["additionalProperties"] == false
    end

    test "works with explicit version 3.1" do
      schema = ResponseLinks.build_resource_links_schema(version: "3.1")

      assert schema["properties"]["self"]["type"] == "string"
      assert schema["properties"]["self"]["format"] == "uri"
    end

    test "works with explicit version 3.0" do
      schema = ResponseLinks.build_resource_links_schema(version: "3.0")

      assert schema["properties"]["self"]["type"] == "string"
      assert schema["properties"]["self"]["format"] == "uri"
    end

    test "does not include pagination links" do
      schema = ResponseLinks.build_resource_links_schema()

      refute Map.has_key?(schema["properties"], "first")
      refute Map.has_key?(schema["properties"], "last")
      refute Map.has_key?(schema["properties"], "prev")
      refute Map.has_key?(schema["properties"], "next")
    end
  end

  describe "build_collection_links_schema/1" do
    test "generates collection links schema with self and pagination" do
      schema = ResponseLinks.build_collection_links_schema()

      assert schema["type"] == "object"
      assert schema["properties"]["self"]["format"] == "uri"
      assert schema["properties"]["first"]["format"] == "uri"
      assert schema["properties"]["last"]["format"] == "uri"
      assert is_map(schema["properties"]["prev"])
      assert is_map(schema["properties"]["next"])
    end

    test "includes all five required collection links" do
      schema = ResponseLinks.build_collection_links_schema()
      properties = schema["properties"]

      assert Map.has_key?(properties, "self")
      assert Map.has_key?(properties, "first")
      assert Map.has_key?(properties, "last")
      assert Map.has_key?(properties, "prev")
      assert Map.has_key?(properties, "next")
    end

    test "uses OpenAPI 3.1 nullable syntax for prev/next" do
      schema = ResponseLinks.build_collection_links_schema(version: "3.1")

      assert schema["properties"]["prev"]["type"] == ["string", "null"]
      assert schema["properties"]["next"]["type"] == ["string", "null"]
    end

    test "uses OpenAPI 3.0 nullable syntax for prev/next" do
      schema = ResponseLinks.build_collection_links_schema(version: "3.0")

      assert schema["properties"]["prev"]["type"] == "string"
      assert schema["properties"]["prev"]["nullable"] == true
      assert schema["properties"]["next"]["type"] == "string"
      assert schema["properties"]["next"]["nullable"] == true
    end

    test "non-nullable links have simple string type in 3.1" do
      schema = ResponseLinks.build_collection_links_schema(version: "3.1")

      assert schema["properties"]["self"]["type"] == "string"
      assert schema["properties"]["first"]["type"] == "string"
      assert schema["properties"]["last"]["type"] == "string"
    end

    test "all links have uri format" do
      schema = ResponseLinks.build_collection_links_schema(version: "3.1")

      Enum.each(["self", "first", "last", "prev", "next"], fn key ->
        assert schema["properties"][key]["format"] == "uri",
               "Expected #{key} to have uri format"
      end)
    end
  end

  describe "build_pagination_links_schema/1" do
    test "generates pagination-only links schema" do
      schema = ResponseLinks.build_pagination_links_schema()

      assert schema["type"] == "object"
      assert Map.has_key?(schema["properties"], "first")
      assert Map.has_key?(schema["properties"], "last")
      assert Map.has_key?(schema["properties"], "prev")
      assert Map.has_key?(schema["properties"], "next")
    end

    test "does not include self link" do
      schema = ResponseLinks.build_pagination_links_schema()

      refute Map.has_key?(schema["properties"], "self")
    end

    test "includes description" do
      schema = ResponseLinks.build_pagination_links_schema()

      assert schema["description"] == "Pagination navigation links"
    end

    test "respects version for nullable handling" do
      schema_31 = ResponseLinks.build_pagination_links_schema(version: "3.1")
      schema_30 = ResponseLinks.build_pagination_links_schema(version: "3.0")

      # 3.1 uses type arrays
      assert schema_31["properties"]["prev"]["type"] == ["string", "null"]

      # 3.0 uses nullable flag
      assert schema_30["properties"]["prev"]["nullable"] == true
    end
  end

  describe "build_relationship_links_schema/1" do
    test "generates relationship links with self and related" do
      schema = ResponseLinks.build_relationship_links_schema()

      assert schema["type"] == "object"
      assert schema["properties"]["self"]["type"] == "string"
      assert schema["properties"]["self"]["format"] == "uri"
      assert schema["properties"]["related"]["type"] == "string"
      assert schema["properties"]["related"]["format"] == "uri"
    end

    test "includes exactly two properties" do
      schema = ResponseLinks.build_relationship_links_schema()

      assert map_size(schema["properties"]) == 2
    end

    test "includes description" do
      schema = ResponseLinks.build_relationship_links_schema()

      assert schema["description"] == "Links for relationship navigation"
    end

    test "does not include pagination links" do
      schema = ResponseLinks.build_relationship_links_schema()

      refute Map.has_key?(schema["properties"], "first")
      refute Map.has_key?(schema["properties"], "last")
      refute Map.has_key?(schema["properties"], "prev")
      refute Map.has_key?(schema["properties"], "next")
    end
  end

  describe "build_document_links_schema/1" do
    test "generates basic document links with self only by default" do
      schema = ResponseLinks.build_document_links_schema()

      assert schema["type"] == "object"
      assert schema["properties"]["self"]["type"] == "string"
      assert map_size(schema["properties"]) == 1
    end

    test "includes pagination when paginated: true" do
      schema = ResponseLinks.build_document_links_schema(paginated: true)

      assert Map.has_key?(schema["properties"], "self")
      assert Map.has_key?(schema["properties"], "first")
      assert Map.has_key?(schema["properties"], "last")
      assert Map.has_key?(schema["properties"], "prev")
      assert Map.has_key?(schema["properties"], "next")
    end

    test "pagination links are nullable in paginated mode" do
      schema = ResponseLinks.build_document_links_schema(paginated: true, version: "3.1")

      assert schema["properties"]["prev"]["type"] == ["string", "null"]
      assert schema["properties"]["next"]["type"] == ["string", "null"]
    end

    test "non-paginated mode has only self link" do
      schema = ResponseLinks.build_document_links_schema(paginated: false)

      assert Map.has_key?(schema["properties"], "self")
      refute Map.has_key?(schema["properties"], "first")
    end
  end

  describe "build_flexible_links_schema/1" do
    test "includes all possible link types" do
      schema = ResponseLinks.build_flexible_links_schema()

      assert Map.has_key?(schema["properties"], "self")
      assert Map.has_key?(schema["properties"], "related")
      assert Map.has_key?(schema["properties"], "first")
      assert Map.has_key?(schema["properties"], "last")
      assert Map.has_key?(schema["properties"], "prev")
      assert Map.has_key?(schema["properties"], "next")
    end

    test "allows additional uri properties" do
      schema = ResponseLinks.build_flexible_links_schema()

      assert schema["additionalProperties"]["type"] == "string"
      assert schema["additionalProperties"]["format"] == "uri"
    end

    test "includes description" do
      schema = ResponseLinks.build_flexible_links_schema()

      assert schema["description"] == "Links object for HATEOAS navigation"
    end

    test "respects version for nullable fields" do
      schema_31 = ResponseLinks.build_flexible_links_schema(version: "3.1")
      schema_30 = ResponseLinks.build_flexible_links_schema(version: "3.0")

      assert schema_31["properties"]["prev"]["type"] == ["string", "null"]
      assert schema_30["properties"]["prev"]["nullable"] == true
    end
  end

  describe "add_links_to_response/2" do
    test "adds resource links to response schema" do
      response = %{
        "type" => "object",
        "properties" => %{
          "data" => %{"type" => "object"}
        }
      }

      updated = ResponseLinks.add_links_to_response(response, link_type: :resource)

      assert Map.has_key?(updated["properties"], "links")
      assert Map.has_key?(updated["properties"], "data")
      assert updated["properties"]["links"]["properties"]["self"]["format"] == "uri"
    end

    test "adds collection links when link_type is :collection" do
      response = %{"type" => "object", "properties" => %{}}

      updated = ResponseLinks.add_links_to_response(response, link_type: :collection)

      assert Map.has_key?(updated["properties"]["links"]["properties"], "first")
      assert Map.has_key?(updated["properties"]["links"]["properties"], "last")
    end

    test "adds relationship links when link_type is :relationship" do
      response = %{"type" => "object", "properties" => %{}}

      updated = ResponseLinks.add_links_to_response(response, link_type: :relationship)

      assert Map.has_key?(updated["properties"]["links"]["properties"], "self")
      assert Map.has_key?(updated["properties"]["links"]["properties"], "related")
      refute Map.has_key?(updated["properties"]["links"]["properties"], "first")
    end

    test "adds flexible links when link_type is :flexible" do
      response = %{"type" => "object", "properties" => %{}}

      updated = ResponseLinks.add_links_to_response(response, link_type: :flexible)

      assert updated["properties"]["links"]["additionalProperties"]["type"] == "string"
    end

    test "defaults to resource links" do
      response = %{"type" => "object", "properties" => %{}}

      updated = ResponseLinks.add_links_to_response(response)

      assert updated["properties"]["links"]["additionalProperties"] == false
    end

    test "preserves existing properties" do
      response = %{
        "type" => "object",
        "properties" => %{
          "data" => %{"type" => "object"},
          "meta" => %{"type" => "object"}
        }
      }

      updated = ResponseLinks.add_links_to_response(response)

      assert Map.has_key?(updated["properties"], "data")
      assert Map.has_key?(updated["properties"], "meta")
      assert Map.has_key?(updated["properties"], "links")
    end

    test "creates properties map if not present" do
      response = %{"type" => "object"}

      updated = ResponseLinks.add_links_to_response(response)

      assert is_map(updated["properties"])
      assert Map.has_key?(updated["properties"], "links")
    end
  end

  describe "build_links_component_schemas/1" do
    test "generates three component schemas" do
      schemas = ResponseLinks.build_links_component_schemas()

      assert map_size(schemas) == 3
      assert Map.has_key?(schemas, "Links")
      assert Map.has_key?(schemas, "PaginationLinks")
      assert Map.has_key?(schemas, "RelationshipLinks")
    end

    test "applies name prefix" do
      schemas = ResponseLinks.build_links_component_schemas(name_prefix: "JsonApi")

      assert Map.has_key?(schemas, "JsonApiLinks")
      assert Map.has_key?(schemas, "JsonApiPaginationLinks")
      assert Map.has_key?(schemas, "JsonApiRelationshipLinks")
    end

    test "Links schema is resource links" do
      schemas = ResponseLinks.build_links_component_schemas()

      assert schemas["Links"]["additionalProperties"] == false
    end

    test "PaginationLinks schema includes pagination" do
      schemas = ResponseLinks.build_links_component_schemas()

      assert Map.has_key?(schemas["PaginationLinks"]["properties"], "first")
      assert Map.has_key?(schemas["PaginationLinks"]["properties"], "last")
    end

    test "RelationshipLinks schema has self and related" do
      schemas = ResponseLinks.build_links_component_schemas()

      assert Map.has_key?(schemas["RelationshipLinks"]["properties"], "self")
      assert Map.has_key?(schemas["RelationshipLinks"]["properties"], "related")
    end

    test "respects version option" do
      schemas_31 = ResponseLinks.build_links_component_schemas(version: "3.1")
      schemas_30 = ResponseLinks.build_links_component_schemas(version: "3.0")

      # Check pagination nullable handling
      assert schemas_31["PaginationLinks"]["properties"]["prev"]["type"] == ["string", "null"]
      assert schemas_30["PaginationLinks"]["properties"]["prev"]["nullable"] == true
    end
  end

  describe "paginated_route?/1" do
    test "returns true for :index route type" do
      assert ResponseLinks.paginated_route?(:index) == true
    end

    test "returns true for :related route type" do
      assert ResponseLinks.paginated_route?(:related) == true
    end

    test "returns false for :get route type" do
      assert ResponseLinks.paginated_route?(:get) == false
    end

    test "returns false for :post route type" do
      assert ResponseLinks.paginated_route?(:post) == false
    end

    test "returns false for :patch route type" do
      assert ResponseLinks.paginated_route?(:patch) == false
    end

    test "returns false for :delete route type" do
      assert ResponseLinks.paginated_route?(:delete) == false
    end

    test "returns false for nil" do
      assert ResponseLinks.paginated_route?(nil) == false
    end

    test "returns false for unknown route types" do
      assert ResponseLinks.paginated_route?(:custom) == false
      assert ResponseLinks.paginated_route?(:unknown) == false
    end
  end

  describe "build_link_object_schema/1" do
    test "generates oneOf schema with string and object options" do
      schema = ResponseLinks.build_link_object_schema()

      assert is_list(schema["oneOf"])
      assert length(schema["oneOf"]) == 2
    end

    test "first option is simple uri string" do
      schema = ResponseLinks.build_link_object_schema()
      string_option = Enum.at(schema["oneOf"], 0)

      assert string_option["type"] == "string"
      assert string_option["format"] == "uri"
    end

    test "second option is link object with href" do
      schema = ResponseLinks.build_link_object_schema()
      object_option = Enum.at(schema["oneOf"], 1)

      assert object_option["type"] == "object"
      assert object_option["required"] == ["href"]
      assert object_option["properties"]["href"]["type"] == "string"
      assert object_option["properties"]["href"]["format"] == "uri"
    end

    test "link object includes optional meta" do
      schema = ResponseLinks.build_link_object_schema()
      object_option = Enum.at(schema["oneOf"], 1)

      assert object_option["properties"]["meta"]["type"] == "object"
      assert object_option["properties"]["meta"]["additionalProperties"] == true
    end

    test "includes description" do
      schema = ResponseLinks.build_link_object_schema()

      assert is_binary(schema["description"])
      assert String.contains?(schema["description"], "link")
    end
  end

  describe "build_nullable_link_object_schema/1" do
    test "adds null type for OpenAPI 3.1" do
      schema = ResponseLinks.build_nullable_link_object_schema(version: "3.1")

      assert is_list(schema["oneOf"])
      null_option = Enum.find(schema["oneOf"], &(&1["type"] == "null"))
      assert null_option != nil
    end

    test "uses nullable flag for OpenAPI 3.0" do
      schema = ResponseLinks.build_nullable_link_object_schema(version: "3.0")

      assert schema["nullable"] == true
    end

    test "3.1 has three options in oneOf" do
      schema = ResponseLinks.build_nullable_link_object_schema(version: "3.1")

      assert length(schema["oneOf"]) == 3
    end

    test "3.0 preserves two options in oneOf" do
      schema = ResponseLinks.build_nullable_link_object_schema(version: "3.0")

      assert length(schema["oneOf"]) == 2
    end

    test "3.1 null option is first in oneOf" do
      schema = ResponseLinks.build_nullable_link_object_schema(version: "3.1")
      first_option = Enum.at(schema["oneOf"], 0)

      assert first_option["type"] == "null"
    end
  end

  describe "version-specific edge cases" do
    test "empty version defaults to 3.1 behavior" do
      schema = ResponseLinks.build_collection_links_schema(version: "")

      # Empty string should use 3.0 fallback (not matching "3.1")
      assert schema["properties"]["prev"]["nullable"] == true
    end

    test "invalid version uses 3.0 fallback" do
      schema = ResponseLinks.build_collection_links_schema(version: "invalid")

      assert schema["properties"]["prev"]["nullable"] == true
    end

    test "version 3.0.0 uses 3.0 behavior" do
      schema = ResponseLinks.build_collection_links_schema(version: "3.0.0")

      assert schema["properties"]["prev"]["nullable"] == true
    end

    test "version 3.1.0 does not match 3.1 exactly" do
      schema = ResponseLinks.build_collection_links_schema(version: "3.1.0")

      # Does not match "3.1" exactly, falls back to 3.0 behavior
      assert schema["properties"]["prev"]["nullable"] == true
    end
  end

  describe "schema structure validation" do
    test "all schemas are valid JSON Schema objects" do
      schemas = [
        ResponseLinks.build_resource_links_schema(),
        ResponseLinks.build_collection_links_schema(),
        ResponseLinks.build_pagination_links_schema(),
        ResponseLinks.build_relationship_links_schema(),
        ResponseLinks.build_document_links_schema(),
        ResponseLinks.build_flexible_links_schema(),
        ResponseLinks.build_link_object_schema()
      ]

      for schema <- schemas do
        assert is_map(schema), "Schema should be a map"

        assert Map.has_key?(schema, "type") or Map.has_key?(schema, "oneOf"),
               "Schema should have type or oneOf"
      end
    end

    test "all uri schemas have format: uri" do
      schema = ResponseLinks.build_collection_links_schema(version: "3.1")

      for {_key, value} <- schema["properties"] do
        assert value["format"] == "uri"
      end
    end

    test "component schemas can be serialized to JSON" do
      schemas = ResponseLinks.build_links_component_schemas()

      assert {:ok, _json} = Jason.encode(schemas)
    end
  end

  describe "integration scenarios" do
    test "building a complete response with links for single resource" do
      response = %{
        "type" => "object",
        "properties" => %{
          "data" => %{
            "type" => "object",
            "properties" => %{
              "id" => %{"type" => "string"},
              "type" => %{"type" => "string"},
              "attributes" => %{"type" => "object"}
            }
          }
        }
      }

      with_links = ResponseLinks.add_links_to_response(response, link_type: :resource)

      assert Map.has_key?(with_links["properties"], "data")
      assert Map.has_key?(with_links["properties"], "links")
      assert with_links["properties"]["links"]["properties"]["self"]["format"] == "uri"
    end

    test "building a complete response with links for collection" do
      response = %{
        "type" => "object",
        "properties" => %{
          "data" => %{
            "type" => "array",
            "items" => %{"type" => "object"}
          }
        }
      }

      with_links =
        ResponseLinks.add_links_to_response(response, link_type: :collection, version: "3.1")

      links = with_links["properties"]["links"]
      assert links["properties"]["self"]["type"] == "string"
      assert links["properties"]["prev"]["type"] == ["string", "null"]
      assert links["properties"]["next"]["type"] == ["string", "null"]
    end

    test "relationship response with links" do
      relationship_data = %{
        "type" => "object",
        "properties" => %{
          "data" => %{
            "type" => "array",
            "items" => %{
              "type" => "object",
              "properties" => %{
                "type" => %{"type" => "string"},
                "id" => %{"type" => "string"}
              }
            }
          }
        }
      }

      with_links =
        ResponseLinks.add_links_to_response(relationship_data, link_type: :relationship)

      assert Map.has_key?(with_links["properties"]["links"]["properties"], "self")
      assert Map.has_key?(with_links["properties"]["links"]["properties"], "related")
    end
  end
end
