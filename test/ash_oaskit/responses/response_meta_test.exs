defmodule AshOaskit.ResponseMetaTest do
  @moduledoc """
  Tests for AshOaskit.ResponseMeta module.

  This test module verifies the generation of JSON:API response meta schemas
  for OpenAPI specifications, including:

  - Pagination meta (count, page info)
  - Resource meta (application-specific)
  - Document-level meta
  - JSON:API version object
  - OpenAPI 3.0 vs 3.1 nullable handling
  - Different pagination strategies (offset, keyset, both)
  """

  use ExUnit.Case, async: true

  alias AshOaskit.ResponseMeta

  describe "build_pagination_meta_schema/1" do
    test "generates pagination meta schema with count and page" do
      schema = ResponseMeta.build_pagination_meta_schema()

      assert schema[:type] == :object
      assert is_map(schema[:properties])
      assert Map.has_key?(schema[:properties], :count)
      assert Map.has_key?(schema[:properties], :page)
    end

    test "count property has integer type with minimum 0" do
      schema = ResponseMeta.build_pagination_meta_schema()

      assert schema[:properties][:count][:type] == :integer
      assert schema[:properties][:count][:minimum] == 0
    end

    test "includes description" do
      schema = ResponseMeta.build_pagination_meta_schema()

      assert schema[:description] == "Pagination and count metadata"
    end

    test "page property is an object" do
      schema = ResponseMeta.build_pagination_meta_schema()

      assert schema[:properties][:page][:type] == :object
    end

    test "respects pagination_strategy option" do
      offset_schema = ResponseMeta.build_pagination_meta_schema(pagination_strategy: :offset)
      keyset_schema = ResponseMeta.build_pagination_meta_schema(pagination_strategy: :keyset)

      # Offset has offset property
      assert Map.has_key?(offset_schema[:properties][:page][:properties], :offset)
      refute Map.has_key?(offset_schema[:properties][:page][:properties], :after)

      # Keyset has after property
      assert Map.has_key?(keyset_schema[:properties][:page][:properties], :after)
      refute Map.has_key?(keyset_schema[:properties][:page][:properties], :offset)
    end
  end

  describe "build_page_info_schema/2" do
    test "offset strategy includes offset, limit, total, has_more" do
      schema = ResponseMeta.build_page_info_schema(:offset)

      assert schema[:type] == :object
      assert Map.has_key?(schema[:properties], :offset)
      assert Map.has_key?(schema[:properties], :limit)
      assert Map.has_key?(schema[:properties], :total)
      assert Map.has_key?(schema[:properties], :has_more)
    end

    test "keyset strategy includes after, before, limit, has_next_page, has_previous_page" do
      schema = ResponseMeta.build_page_info_schema(:keyset)

      assert Map.has_key?(schema[:properties], :after)
      assert Map.has_key?(schema[:properties], :before)
      assert Map.has_key?(schema[:properties], :limit)
      assert Map.has_key?(schema[:properties], :has_next_page)
      assert Map.has_key?(schema[:properties], :has_previous_page)
    end

    test "both strategy includes all properties from offset and keyset" do
      schema = ResponseMeta.build_page_info_schema(:both)

      # From offset
      assert Map.has_key?(schema[:properties], :offset)
      assert Map.has_key?(schema[:properties], :total)

      # From keyset
      assert Map.has_key?(schema[:properties], :after)
      assert Map.has_key?(schema[:properties], :has_next_page)
    end

    test "offset property has minimum 0" do
      schema = ResponseMeta.build_page_info_schema(:offset)

      assert schema[:properties][:offset][:minimum] == 0
    end

    test "limit property has minimum 1" do
      schema = ResponseMeta.build_page_info_schema(:offset)

      assert schema[:properties][:limit][:minimum] == 1
    end

    test "keyset cursors are nullable in 3.1" do
      schema = ResponseMeta.build_page_info_schema(:keyset, "3.1")

      assert schema[:properties][:after][:type] == [:string, :null]
      assert schema[:properties][:before][:type] == [:string, :null]
    end

    test "keyset cursors are nullable in 3.0" do
      schema = ResponseMeta.build_page_info_schema(:keyset, "3.0")

      assert schema[:properties][:after][:nullable] == true
      assert schema[:properties][:before][:nullable] == true
    end

    test "unknown strategy defaults to both" do
      schema = ResponseMeta.build_page_info_schema(:unknown)

      assert Map.has_key?(schema[:properties], :offset)
      assert Map.has_key?(schema[:properties], :after)
    end

    test "includes descriptions for each property" do
      schema = ResponseMeta.build_page_info_schema(:offset)

      assert is_binary(schema[:properties][:offset][:description])
      assert is_binary(schema[:properties][:limit][:description])
    end
  end

  describe "build_resource_meta_schema/1" do
    test "generates generic resource meta schema" do
      schema = ResponseMeta.build_resource_meta_schema()

      assert schema[:type] == :object
      assert schema[:additionalProperties] == true
    end

    test "includes description" do
      schema = ResponseMeta.build_resource_meta_schema()

      assert String.contains?(schema[:description], "meta")
    end

    test "does not have specific properties" do
      schema = ResponseMeta.build_resource_meta_schema()

      refute Map.has_key?(schema, :properties)
    end
  end

  describe "build_jsonapi_object_schema/1" do
    test "generates JSON:API version object schema" do
      schema = ResponseMeta.build_jsonapi_object_schema()

      assert schema[:type] == :object
      assert Map.has_key?(schema[:properties], :version)
    end

    test "version property has enum with default versions" do
      schema = ResponseMeta.build_jsonapi_object_schema()

      assert schema[:properties][:version][:type] == :string
      assert "1.0" in schema[:properties][:version][:enum]
      assert "1.1" in schema[:properties][:version][:enum]
    end

    test "respects custom supported_versions" do
      schema = ResponseMeta.build_jsonapi_object_schema(supported_versions: ["1.1"])

      assert schema[:properties][:version][:enum] == ["1.1"]
    end

    test "includes ext array property" do
      schema = ResponseMeta.build_jsonapi_object_schema()

      assert schema[:properties][:ext][:type] == :array
      assert schema[:properties][:ext][:items][:type] == :string
      assert schema[:properties][:ext][:items][:format] == :uri
    end

    test "includes profile array property" do
      schema = ResponseMeta.build_jsonapi_object_schema()

      assert schema[:properties][:profile][:type] == :array
      assert schema[:properties][:profile][:items][:format] == :uri
    end

    test "includes description" do
      schema = ResponseMeta.build_jsonapi_object_schema()

      assert String.contains?(schema[:description], "JSON:API")
    end
  end

  describe "build_document_meta_schema/1" do
    test "generates document-level meta schema" do
      schema = ResponseMeta.build_document_meta_schema()

      assert schema[:type] == :object
      assert schema[:additionalProperties] == true
    end

    test "includes count by default" do
      schema = ResponseMeta.build_document_meta_schema()

      assert Map.has_key?(schema[:properties], :count)
      assert schema[:properties][:count][:type] == :integer
    end

    test "can exclude count" do
      schema = ResponseMeta.build_document_meta_schema(include_count: false)

      refute Map.has_key?(schema[:properties] || %{}, :count)
    end

    test "does not include page by default" do
      schema = ResponseMeta.build_document_meta_schema()

      refute Map.has_key?(schema[:properties], :page)
    end

    test "can include page info" do
      schema = ResponseMeta.build_document_meta_schema(include_page: true)

      assert Map.has_key?(schema[:properties], :page)
      assert schema[:properties][:page][:type] == :object
    end

    test "respects pagination_strategy when including page" do
      schema =
        ResponseMeta.build_document_meta_schema(include_page: true, pagination_strategy: :offset)

      assert Map.has_key?(schema[:properties][:page][:properties], :offset)
      refute Map.has_key?(schema[:properties][:page][:properties], :after)
    end

    test "includes description" do
      schema = ResponseMeta.build_document_meta_schema()

      assert is_binary(schema[:description])
    end
  end

  describe "build_response_meta_schema/1" do
    test "returns pagination meta for collection response type" do
      schema = ResponseMeta.build_response_meta_schema(response_type: :collection)

      assert Map.has_key?(schema[:properties], :count)
      assert Map.has_key?(schema[:properties], :page)
    end

    test "returns resource meta for single response type" do
      schema = ResponseMeta.build_response_meta_schema(response_type: :single)

      assert schema[:additionalProperties] == true
    end

    test "returns resource meta for relationship response type" do
      schema = ResponseMeta.build_response_meta_schema(response_type: :relationship)

      assert schema[:additionalProperties] == true
    end

    test "defaults to single/resource meta" do
      schema = ResponseMeta.build_response_meta_schema()

      assert schema[:additionalProperties] == true
      refute Map.has_key?(schema, :properties)
    end
  end

  describe "add_meta_to_response/2" do
    test "adds resource meta to response schema" do
      response = %{
        type: :object,
        properties: %{
          data: %{type: :object}
        }
      }

      updated = ResponseMeta.add_meta_to_response(response, meta_type: :resource)

      assert Map.has_key?(updated[:properties], :meta)
      assert Map.has_key?(updated[:properties], :data)
      assert updated[:properties][:meta][:additionalProperties] == true
    end

    test "adds pagination meta when meta_type is :pagination" do
      response = %{type: :object, properties: %{}}

      updated = ResponseMeta.add_meta_to_response(response, meta_type: :pagination)

      assert Map.has_key?(updated[:properties][:meta][:properties], :count)
      assert Map.has_key?(updated[:properties][:meta][:properties], :page)
    end

    test "adds document meta when meta_type is :document" do
      response = %{type: :object, properties: %{}}

      updated = ResponseMeta.add_meta_to_response(response, meta_type: :document)

      assert updated[:properties][:meta][:additionalProperties] == true
    end

    test "defaults to resource meta" do
      response = %{type: :object, properties: %{}}

      updated = ResponseMeta.add_meta_to_response(response)

      assert updated[:properties][:meta][:additionalProperties] == true
    end

    test "preserves existing properties" do
      response = %{
        type: :object,
        properties: %{
          data: %{type: :object},
          links: %{type: :object}
        }
      }

      updated = ResponseMeta.add_meta_to_response(response)

      assert Map.has_key?(updated[:properties], :data)
      assert Map.has_key?(updated[:properties], :links)
      assert Map.has_key?(updated[:properties], :meta)
    end

    test "creates properties map if not present" do
      response = %{type: :object}

      updated = ResponseMeta.add_meta_to_response(response)

      assert is_map(updated[:properties])
      assert Map.has_key?(updated[:properties], :meta)
    end
  end

  describe "add_jsonapi_object_to_response/2" do
    test "adds jsonapi object to response schema" do
      response = %{
        type: :object,
        properties: %{
          data: %{type: :object}
        }
      }

      updated = ResponseMeta.add_jsonapi_object_to_response(response)

      assert Map.has_key?(updated[:properties], :jsonapi)
      assert Map.has_key?(updated[:properties][:jsonapi][:properties], :version)
    end

    test "respects supported_versions option" do
      response = %{type: :object, properties: %{}}

      updated = ResponseMeta.add_jsonapi_object_to_response(response, supported_versions: ["1.1"])

      assert updated[:properties][:jsonapi][:properties][:version][:enum] == ["1.1"]
    end

    test "preserves existing properties" do
      response = %{
        type: :object,
        properties: %{
          data: %{},
          meta: %{}
        }
      }

      updated = ResponseMeta.add_jsonapi_object_to_response(response)

      assert Map.has_key?(updated[:properties], :data)
      assert Map.has_key?(updated[:properties], :meta)
      assert Map.has_key?(updated[:properties], :jsonapi)
    end

    test "creates properties map if not present" do
      response = %{type: :object}

      updated = ResponseMeta.add_jsonapi_object_to_response(response)

      assert is_map(updated[:properties])
      assert Map.has_key?(updated[:properties], :jsonapi)
    end
  end

  describe "build_meta_component_schemas/1" do
    test "generates five component schemas" do
      schemas = ResponseMeta.build_meta_component_schemas()

      assert map_size(schemas) == 5
      assert Map.has_key?(schemas, "Meta")
      assert Map.has_key?(schemas, "PaginationMeta")
      assert Map.has_key?(schemas, "DocumentMeta")
      assert Map.has_key?(schemas, "JsonApi")
      assert Map.has_key?(schemas, "PageInfo")
    end

    test "applies name prefix" do
      schemas = ResponseMeta.build_meta_component_schemas(name_prefix: "JsonApi")

      assert Map.has_key?(schemas, "JsonApiMeta")
      assert Map.has_key?(schemas, "JsonApiPaginationMeta")
      assert Map.has_key?(schemas, "JsonApiDocumentMeta")
      assert Map.has_key?(schemas, "JsonApiJsonApi")
      assert Map.has_key?(schemas, "JsonApiPageInfo")
    end

    test "Meta schema is resource meta" do
      schemas = ResponseMeta.build_meta_component_schemas()

      assert schemas["Meta"][:additionalProperties] == true
    end

    test "PaginationMeta schema includes count and page" do
      schemas = ResponseMeta.build_meta_component_schemas()

      assert Map.has_key?(schemas["PaginationMeta"][:properties], :count)
      assert Map.has_key?(schemas["PaginationMeta"][:properties], :page)
    end

    test "DocumentMeta schema includes page info" do
      schemas = ResponseMeta.build_meta_component_schemas()

      assert Map.has_key?(schemas["DocumentMeta"][:properties], :page)
    end

    test "JsonApi schema has version property" do
      schemas = ResponseMeta.build_meta_component_schemas()

      assert Map.has_key?(schemas["JsonApi"][:properties], :version)
    end

    test "PageInfo schema has pagination properties" do
      schemas = ResponseMeta.build_meta_component_schemas()

      # Should have both offset and keyset properties
      assert Map.has_key?(schemas["PageInfo"][:properties], :offset)
      assert Map.has_key?(schemas["PageInfo"][:properties], :after)
    end

    test "respects version option" do
      schemas_31 = ResponseMeta.build_meta_component_schemas(version: "3.1")
      schemas_30 = ResponseMeta.build_meta_component_schemas(version: "3.0")

      # Check keyset nullable handling in PageInfo
      assert schemas_31["PageInfo"][:properties][:after][:type] == [:string, :null]
      assert schemas_30["PageInfo"][:properties][:after][:nullable] == true
    end
  end

  describe "paginated_route?/1" do
    test "returns true for :index route type" do
      assert ResponseMeta.paginated_route?(:index) == true
    end

    test "returns true for :related route type" do
      assert ResponseMeta.paginated_route?(:related) == true
    end

    test "returns false for :get route type" do
      assert ResponseMeta.paginated_route?(:get) == false
    end

    test "returns false for :post route type" do
      assert ResponseMeta.paginated_route?(:post) == false
    end

    test "returns false for :patch route type" do
      assert ResponseMeta.paginated_route?(:patch) == false
    end

    test "returns false for :delete route type" do
      assert ResponseMeta.paginated_route?(:delete) == false
    end

    test "returns false for nil" do
      assert ResponseMeta.paginated_route?(nil) == false
    end

    test "returns false for unknown route types" do
      assert ResponseMeta.paginated_route?(:custom) == false
      assert ResponseMeta.paginated_route?(:unknown) == false
    end
  end

  describe "build_complete_meta_schema/1" do
    test "includes count and page by default" do
      schema = ResponseMeta.build_complete_meta_schema()

      assert Map.has_key?(schema[:properties], :count)
      assert Map.has_key?(schema[:properties], :page)
    end

    test "can exclude count" do
      schema = ResponseMeta.build_complete_meta_schema(include_count: false)

      refute Map.has_key?(schema[:properties], :count)
      assert Map.has_key?(schema[:properties], :page)
    end

    test "can exclude page" do
      schema = ResponseMeta.build_complete_meta_schema(include_page: false)

      assert Map.has_key?(schema[:properties], :count)
      refute Map.has_key?(schema[:properties], :page)
    end

    test "allows additional properties" do
      schema = ResponseMeta.build_complete_meta_schema()

      assert schema[:additionalProperties] == true
    end

    test "includes description" do
      schema = ResponseMeta.build_complete_meta_schema()

      assert is_binary(schema[:description])
    end

    test "respects pagination_strategy" do
      offset_schema = ResponseMeta.build_complete_meta_schema(pagination_strategy: :offset)
      keyset_schema = ResponseMeta.build_complete_meta_schema(pagination_strategy: :keyset)

      assert Map.has_key?(offset_schema[:properties][:page][:properties], :offset)
      assert Map.has_key?(keyset_schema[:properties][:page][:properties], :after)
    end
  end

  describe "version-specific edge cases" do
    test "empty version defaults to 3.0 behavior for keyset" do
      schema = ResponseMeta.build_page_info_schema(:keyset, "")

      # Empty string doesn't match "3.1", uses fallback
      assert schema[:properties][:after][:nullable] == true
    end

    test "invalid version uses 3.0 fallback for keyset" do
      schema = ResponseMeta.build_page_info_schema(:keyset, "invalid")

      assert schema[:properties][:after][:nullable] == true
    end
  end

  describe "schema structure validation" do
    test "all schemas are valid JSON Schema objects" do
      schemas = [
        ResponseMeta.build_pagination_meta_schema(),
        ResponseMeta.build_resource_meta_schema(),
        ResponseMeta.build_jsonapi_object_schema(),
        ResponseMeta.build_document_meta_schema(),
        ResponseMeta.build_page_info_schema(:offset),
        ResponseMeta.build_page_info_schema(:keyset),
        ResponseMeta.build_page_info_schema(:both),
        ResponseMeta.build_complete_meta_schema()
      ]

      for schema <- schemas do
        assert is_map(schema), "Schema should be a map"
        assert schema[:type] == :object, "Schema should have type: :object"
      end
    end

    test "component schemas can be serialized to JSON" do
      schemas = ResponseMeta.build_meta_component_schemas()

      assert {:ok, _json} = Jason.encode(schemas)
    end

    test "integer properties have correct type" do
      schema = ResponseMeta.build_pagination_meta_schema()

      assert schema[:properties][:count][:type] == :integer
    end

    test "boolean properties have correct type" do
      schema = ResponseMeta.build_page_info_schema(:offset)

      assert schema[:properties][:has_more][:type] == :boolean
    end
  end

  describe "integration scenarios" do
    test "building a complete collection response with meta" do
      response = %{
        type: :object,
        properties: %{
          data: %{
            type: :array,
            items: %{type: :object}
          }
        }
      }

      with_meta = ResponseMeta.add_meta_to_response(response, meta_type: :pagination)

      assert Map.has_key?(with_meta[:properties], :data)
      assert Map.has_key?(with_meta[:properties], :meta)
      assert Map.has_key?(with_meta[:properties][:meta][:properties], :count)
    end

    test "building a complete response with jsonapi object" do
      response = %{
        type: :object,
        properties: %{
          data: %{type: :object}
        }
      }

      with_jsonapi = ResponseMeta.add_jsonapi_object_to_response(response)

      assert Map.has_key?(with_jsonapi[:properties], :jsonapi)
      assert "1.0" in with_jsonapi[:properties][:jsonapi][:properties][:version][:enum]
    end

    test "combining meta and jsonapi in a response" do
      response = %{
        type: :object,
        properties: %{
          data: %{type: :object}
        }
      }

      complete =
        response
        |> ResponseMeta.add_meta_to_response(meta_type: :pagination)
        |> ResponseMeta.add_jsonapi_object_to_response()

      assert Map.has_key?(complete[:properties], :data)
      assert Map.has_key?(complete[:properties], :meta)
      assert Map.has_key?(complete[:properties], :jsonapi)
    end
  end
end
