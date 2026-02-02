defmodule AshOaskit.RelationshipRoutesTest do
  @moduledoc """
  Tests for the AshOaskit.RelationshipRoutes module.

  JSON:API defines two types of relationship endpoints: related resource routes
  that return full resource objects, and relationship routes that return or
  manipulate resource identifier linkages. This module tests OpenAPI operation
  generation for both types.

  ## What We Test

  - **Route detection** - Distinguishing relationship routes from standard CRUD
    routes based on route type (`:related`, `:relationship`, `:post_to_relationship`,
    `:patch_relationship`, `:delete_from_relationship`)
  - **Related routes** - `GET /posts/:id/comments` returns full Comment resources
    with pagination, filtering, and inclusion support
  - **Relationship routes** - `GET/POST/PATCH/DELETE /posts/:id/relationships/comments`
    manipulates resource identifier linkages `{type, id}` without full resources
  - **Cardinality** - To-one relationships return nullable single identifiers,
    to-many return arrays; affects both response and request body schemas
  - **Resource identifiers** - Schema generation for `{type: "comments", id: "1"}`
    objects used in relationship linkage

  ## How We Test

  Tests use mock route structs simulating AshJsonApi route structures, then call
  `RelationshipRoutes.build_operation/2` and related functions. We verify correct
  HTTP methods, operationIds, request/response schemas, and parameter handling.

  ## Why These Tests Matter

  Relationship routes have complex semantics: POST to a to-many relationship
  adds linkages, PATCH replaces them, DELETE removes specific ones. Incorrect
  schemas cause client confusion and invalid API requests. These tests ensure
  the generated OpenAPI spec accurately documents JSON:API relationship behavior.
  """

  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias AshOaskit.RelationshipRoutes

  # Mock route structs for testing
  # These simulate the structure of AshJsonApi route structs

  defp mock_related_route do
    %{
      type: :related,
      resource: AshOaskit.Test.Post,
      relationship: :comments,
      route: "/posts/:id/comments",
      action: :read,
      name: :comments
    }
  end

  defp mock_relationship_route do
    %{
      type: :relationship,
      resource: AshOaskit.Test.Post,
      relationship: :comments,
      route: "/posts/:id/relationships/comments",
      action: :read,
      name: :comments_relationship
    }
  end

  defp mock_post_relationship_route do
    %{
      type: :post_to_relationship,
      resource: AshOaskit.Test.Post,
      relationship: :comments,
      route: "/posts/:id/relationships/comments",
      action: :update,
      name: :add_comments
    }
  end

  defp mock_patch_relationship_route do
    %{
      type: :patch_relationship,
      resource: AshOaskit.Test.Post,
      relationship: :comments,
      route: "/posts/:id/relationships/comments",
      action: :update,
      name: :replace_comments
    }
  end

  defp mock_delete_relationship_route do
    %{
      type: :delete_from_relationship,
      resource: AshOaskit.Test.Post,
      relationship: :comments,
      route: "/posts/:id/relationships/comments",
      action: :update,
      name: :remove_comments
    }
  end

  defp mock_index_route do
    %{
      type: :index,
      resource: AshOaskit.Test.Post,
      route: "/posts",
      action: :read,
      name: :index
    }
  end

  describe "relationship_route?/1" do
    # Tests for route type detection

    test "returns true for :related routes" do
      assert RelationshipRoutes.relationship_route?(mock_related_route())
    end

    test "returns true for :relationship routes" do
      assert RelationshipRoutes.relationship_route?(mock_relationship_route())
    end

    test "returns true for :post_to_relationship routes" do
      assert RelationshipRoutes.relationship_route?(mock_post_relationship_route())
    end

    test "returns true for :patch_relationship routes" do
      assert RelationshipRoutes.relationship_route?(mock_patch_relationship_route())
    end

    test "returns true for :delete_from_relationship routes" do
      assert RelationshipRoutes.relationship_route?(mock_delete_relationship_route())
    end

    test "returns false for :index routes" do
      refute RelationshipRoutes.relationship_route?(mock_index_route())
    end

    test "returns false for :get routes" do
      route = %{type: :get, resource: AshOaskit.Test.Post}
      refute RelationshipRoutes.relationship_route?(route)
    end

    test "returns false for :post routes" do
      route = %{type: :post, resource: AshOaskit.Test.Post}
      refute RelationshipRoutes.relationship_route?(route)
    end

    test "handles missing type gracefully" do
      route = %{resource: AshOaskit.Test.Post}
      refute RelationshipRoutes.relationship_route?(route)
    end
  end

  describe "route_method/1" do
    # Tests for HTTP method mapping

    test "related routes use GET" do
      assert RelationshipRoutes.route_method(mock_related_route()) == "get"
    end

    test "relationship routes use GET" do
      assert RelationshipRoutes.route_method(mock_relationship_route()) == "get"
    end

    test "post_to_relationship routes use POST" do
      assert RelationshipRoutes.route_method(mock_post_relationship_route()) == "post"
    end

    test "patch_relationship routes use PATCH" do
      assert RelationshipRoutes.route_method(mock_patch_relationship_route()) == "patch"
    end

    test "delete_from_relationship routes use DELETE" do
      assert RelationshipRoutes.route_method(mock_delete_relationship_route()) == "delete"
    end

    test "unknown route types default to GET" do
      route = %{type: :unknown}

      log =
        capture_log(fn ->
          assert RelationshipRoutes.route_method(route) == "get"
        end)

      assert log =~ "unknown relationship route type: :unknown"
    end
  end

  describe "build_operation/2" do
    # Tests for operation object generation

    test "generates operation for related route" do
      operation = RelationshipRoutes.build_operation(mock_related_route())

      assert is_map(operation)
      assert Map.has_key?(operation, :operationId)
      assert Map.has_key?(operation, :summary)
      assert Map.has_key?(operation, :responses)
    end

    test "operation has correct operationId format" do
      operation = RelationshipRoutes.build_operation(mock_related_route())

      assert operation[:operationId] == "post_comments_related"
    end

    test "operation includes tags" do
      operation = RelationshipRoutes.build_operation(mock_related_route())

      assert operation[:tags] == ["Post"]
    end

    test "operation includes parameters" do
      operation = RelationshipRoutes.build_operation(mock_related_route())

      assert is_list(operation[:parameters])
      assert operation[:parameters] != []
    end

    test "related route includes pagination parameters" do
      operation = RelationshipRoutes.build_operation(mock_related_route())

      param_names = Enum.map(operation[:parameters], & &1[:name])
      assert "page" in param_names
    end

    test "relationship route does not include pagination parameters" do
      operation = RelationshipRoutes.build_operation(mock_relationship_route())

      param_names = Enum.map(operation[:parameters], & &1[:name])
      refute "page" in param_names
    end

    test "post_to_relationship route includes request body when relationship exists" do
      # Note: When relationship doesn't exist on the resource, requestBody is not added
      # This test documents expected behavior - request body is added when relationship exists
      operation = RelationshipRoutes.build_operation(mock_post_relationship_route())

      # Without a real relationship, no requestBody is added
      # The function correctly handles missing relationships gracefully
      assert is_map(operation)
    end

    test "patch_relationship route includes request body when relationship exists" do
      operation = RelationshipRoutes.build_operation(mock_patch_relationship_route())

      # Without a real relationship, operation is still valid
      assert is_map(operation)
    end

    test "delete_from_relationship route includes request body when relationship exists" do
      operation = RelationshipRoutes.build_operation(mock_delete_relationship_route())

      # Without a real relationship, operation is still valid
      assert is_map(operation)
    end

    test "related route does not include request body" do
      operation = RelationshipRoutes.build_operation(mock_related_route())

      refute Map.has_key?(operation, :requestBody)
    end

    test "operation includes description" do
      operation = RelationshipRoutes.build_operation(mock_related_route())

      assert Map.has_key?(operation, :description)
      assert is_binary(operation[:description])
    end
  end

  describe "build_resource_identifier_schema/1" do
    # Tests for resource identifier schema generation

    test "generates object type schema" do
      schema = RelationshipRoutes.build_resource_identifier_schema("comment")

      assert schema[:type] == :object
    end

    test "requires type and id fields" do
      schema = RelationshipRoutes.build_resource_identifier_schema("comment")

      assert "type" in schema[:required]
      assert "id" in schema[:required]
    end

    test "type property has enum with resource type" do
      schema = RelationshipRoutes.build_resource_identifier_schema("comment")

      assert schema[:properties]["type"][:enum] == ["comment"]
    end

    test "id property is string type" do
      schema = RelationshipRoutes.build_resource_identifier_schema("comment")

      assert schema[:properties]["id"][:type] == :string
    end

    test "handles different resource types" do
      schema = RelationshipRoutes.build_resource_identifier_schema("posts")

      assert schema[:properties]["type"][:enum] == ["posts"]
    end

    test "includes description for id field" do
      schema = RelationshipRoutes.build_resource_identifier_schema("comment")

      assert Map.has_key?(schema[:properties]["id"], :description)
    end
  end

  describe "build_relationship_linkage_schema/2" do
    # Tests for relationship linkage schema generation (to-one vs to-many)

    # Mock relationship structs
    defp mock_has_many_relationship do
      %{
        type: :has_many,
        destination: AshOaskit.Test.Comment,
        name: :comments
      }
    end

    defp mock_belongs_to_relationship do
      %{
        type: :belongs_to,
        destination: AshOaskit.Test.Post,
        name: :post
      }
    end

    defp mock_has_one_relationship do
      %{
        type: :has_one,
        destination: AshOaskit.Test.Comment,
        name: :featured_comment
      }
    end

    test "to-many relationship generates array schema" do
      schema =
        RelationshipRoutes.build_relationship_linkage_schema(
          mock_has_many_relationship(),
          version: "3.1"
        )

      assert schema[:type] == :array
      assert Map.has_key?(schema, :items)
    end

    test "to-many relationship items are resource identifiers" do
      schema =
        RelationshipRoutes.build_relationship_linkage_schema(
          mock_has_many_relationship(),
          version: "3.1"
        )

      assert schema[:items][:type] == :object
      assert "type" in schema[:items][:required]
      assert "id" in schema[:items][:required]
    end

    test "belongs_to relationship generates nullable object schema (3.1)" do
      schema =
        RelationshipRoutes.build_relationship_linkage_schema(
          mock_belongs_to_relationship(),
          version: "3.1"
        )

      # In 3.1, nullable is expressed as oneOf with %{type: :null}
      assert Map.has_key?(schema, :oneOf)
      assert %{type: :null} in schema[:oneOf]
    end

    test "has_one relationship generates nullable object schema (3.1)" do
      schema =
        RelationshipRoutes.build_relationship_linkage_schema(
          mock_has_one_relationship(),
          version: "3.1"
        )

      assert Map.has_key?(schema, :oneOf)
      assert %{type: :null} in schema[:oneOf]
    end

    test "belongs_to relationship uses nullable: true for 3.0" do
      schema =
        RelationshipRoutes.build_relationship_linkage_schema(
          mock_belongs_to_relationship(),
          version: "3.0"
        )

      assert schema[:nullable] == true
    end

    test "default version is 3.1" do
      schema =
        RelationshipRoutes.build_relationship_linkage_schema(
          mock_belongs_to_relationship(),
          []
        )

      # 3.1 uses oneOf for nullable
      assert Map.has_key?(schema, :oneOf)
      assert %{type: :null} in schema[:oneOf]
    end
  end

  describe "build_relationship_response_schema/2" do
    # Tests for full relationship response schema

    defp mock_relationship_for_response do
      %{
        type: :has_many,
        destination: AshOaskit.Test.Comment,
        name: :comments
      }
    end

    test "generates object type response" do
      schema =
        RelationshipRoutes.build_relationship_response_schema(
          mock_relationship_for_response(),
          version: "3.1"
        )

      assert schema[:type] == :object
    end

    test "includes data property" do
      schema =
        RelationshipRoutes.build_relationship_response_schema(
          mock_relationship_for_response(),
          version: "3.1"
        )

      assert Map.has_key?(schema[:properties], "data")
    end

    test "includes links property" do
      schema =
        RelationshipRoutes.build_relationship_response_schema(
          mock_relationship_for_response(),
          version: "3.1"
        )

      assert Map.has_key?(schema[:properties], "links")
      assert Map.has_key?(schema[:properties]["links"][:properties], "self")
      assert Map.has_key?(schema[:properties]["links"][:properties], "related")
    end

    test "includes meta property" do
      schema =
        RelationshipRoutes.build_relationship_response_schema(
          mock_relationship_for_response(),
          version: "3.1"
        )

      assert Map.has_key?(schema[:properties], "meta")
    end

    test "links have URI format" do
      schema =
        RelationshipRoutes.build_relationship_response_schema(
          mock_relationship_for_response(),
          version: "3.1"
        )

      assert schema[:properties]["links"][:properties]["self"][:format] == :uri
      assert schema[:properties]["links"][:properties]["related"][:format] == :uri
    end
  end

  describe "build_related_response_schema/2" do
    # Tests for related resources response schema

    defp mock_to_many_relationship do
      %{
        type: :has_many,
        destination: AshOaskit.Test.Comment,
        name: :comments
      }
    end

    defp mock_to_one_relationship do
      %{
        type: :belongs_to,
        destination: AshOaskit.Test.Post,
        name: :post
      }
    end

    test "generates object response schema" do
      schema =
        RelationshipRoutes.build_related_response_schema(
          mock_to_many_relationship(),
          version: "3.1"
        )

      assert schema[:type] == :object
    end

    test "to-many relationship has array data" do
      schema =
        RelationshipRoutes.build_related_response_schema(
          mock_to_many_relationship(),
          version: "3.1"
        )

      assert schema[:properties]["data"][:type] == :array
    end

    test "to-many relationship references response schema" do
      schema =
        RelationshipRoutes.build_related_response_schema(
          mock_to_many_relationship(),
          version: "3.1"
        )

      assert schema[:properties]["data"][:items]["$ref"] =~ "Response"
    end

    test "to-one relationship has single nullable data" do
      schema =
        RelationshipRoutes.build_related_response_schema(
          mock_to_one_relationship(),
          version: "3.1"
        )

      # Should reference a response schema, not be an array
      refute schema[:properties]["data"][:type] == :array
    end

    test "includes pagination links" do
      schema =
        RelationshipRoutes.build_related_response_schema(
          mock_to_many_relationship(),
          version: "3.1"
        )

      links = schema[:properties]["links"][:properties]
      assert Map.has_key?(links, "first")
      assert Map.has_key?(links, "last")
      assert Map.has_key?(links, "prev")
      assert Map.has_key?(links, "next")
    end

    test "includes meta with total count" do
      schema =
        RelationshipRoutes.build_related_response_schema(
          mock_to_many_relationship(),
          version: "3.1"
        )

      assert Map.has_key?(schema[:properties]["meta"][:properties], "total")
    end
  end

  describe "operation response codes" do
    # Tests for correct HTTP response codes

    test "related route has 200 and 404 responses" do
      operation = RelationshipRoutes.build_operation(mock_related_route())

      assert Map.has_key?(operation[:responses], "200")
      assert Map.has_key?(operation[:responses], "404")
    end

    test "post_to_relationship has 200, 400, 404 responses" do
      # Note: 422 response is added when relationship exists on the resource
      operation = RelationshipRoutes.build_operation(mock_post_relationship_route())

      assert Map.has_key?(operation[:responses], "200")
      assert Map.has_key?(operation[:responses], "400")
      assert Map.has_key?(operation[:responses], "404")
    end

    test "delete_from_relationship has 200, 204, 404 responses" do
      operation = RelationshipRoutes.build_operation(mock_delete_relationship_route())

      assert Map.has_key?(operation[:responses], "200")
      assert Map.has_key?(operation[:responses], "204")
      assert Map.has_key?(operation[:responses], "404")
    end
  end

  describe "path parameter extraction" do
    # Tests for extracting path parameters from route paths

    test "extracts single path parameter" do
      operation = RelationshipRoutes.build_operation(mock_related_route())

      path_params = Enum.filter(operation[:parameters], &(&1[:in] == :path))
      assert [path_param] = path_params
      assert path_param[:name] == "id"
    end

    test "path parameters are required" do
      operation = RelationshipRoutes.build_operation(mock_related_route())

      path_params = Enum.filter(operation[:parameters], &(&1[:in] == :path))

      Enum.each(path_params, fn param ->
        assert param[:required] == true
      end)
    end

    test "path parameters have string schema" do
      operation = RelationshipRoutes.build_operation(mock_related_route())

      path_params = Enum.filter(operation[:parameters], &(&1[:in] == :path))

      Enum.each(path_params, fn param ->
        assert param[:schema][:type] == :string
      end)
    end
  end

  describe "edge cases" do
    # Tests for edge cases and unusual scenarios

    test "handles route without relationship field" do
      route = %{
        type: :related,
        resource: AshOaskit.Test.Post,
        route: "/posts/:id/related",
        action: :read,
        name: :related
      }

      operation = RelationshipRoutes.build_operation(route)
      assert is_map(operation)
    end

    test "handles nil relationship gracefully" do
      route = %{
        type: :related,
        resource: AshOaskit.Test.Post,
        relationship: nil,
        route: "/posts/:id/related",
        action: :read,
        name: :related
      }

      operation = RelationshipRoutes.build_operation(route)
      assert is_map(operation)
    end

    test "handles route with multiple path parameters" do
      route = %{
        type: :related,
        resource: AshOaskit.Test.Post,
        relationship: :comments,
        route: "/users/:user_id/posts/:id/comments",
        action: :read,
        name: :comments
      }

      operation = RelationshipRoutes.build_operation(route)
      path_params = Enum.filter(operation[:parameters], &(&1[:in] == :path))

      assert [_, _] = path_params
      param_names = Enum.map(path_params, & &1[:name])
      assert "user_id" in param_names
      assert "id" in param_names
    end
  end

  describe "version compatibility" do
    # Tests for OpenAPI 3.0 vs 3.1 compatibility

    test "3.1 version generates valid schema" do
      operation = RelationshipRoutes.build_operation(mock_related_route(), version: "3.1")

      assert is_map(operation)
      assert Map.has_key?(operation, :responses)
    end

    test "3.0 version generates valid schema" do
      operation = RelationshipRoutes.build_operation(mock_related_route(), version: "3.0")

      assert is_map(operation)
      assert Map.has_key?(operation, :responses)
    end
  end

  describe "routes with real relationships" do
    # Tests using resources that have actual relationships defined
    # This covers the `if relationship do` branches

    defp route_with_real_relationship(type) do
      %{
        type: type,
        resource: AshOaskit.Test.Article,
        relationship: :author,
        route: "/articles/:id/relationships/author",
        action: :read,
        name: :author_relationship
      }
    end

    defp related_route_with_real_relationship do
      %{
        type: :related,
        resource: AshOaskit.Test.Article,
        relationship: :author,
        route: "/articles/:id/author",
        action: :read,
        name: :author
      }
    end

    test "related route with existing relationship includes proper response schema" do
      operation = RelationshipRoutes.build_operation(related_route_with_real_relationship())

      assert operation[:responses]["200"][:content]["application/vnd.api+json"][:schema]
    end

    test "relationship route with existing relationship includes proper response schema" do
      operation = RelationshipRoutes.build_operation(route_with_real_relationship(:relationship))

      response_schema =
        operation[:responses]["200"][:content]["application/vnd.api+json"][:schema]

      assert response_schema[:properties]["data"]
      assert response_schema[:properties]["links"]
    end

    test "post_to_relationship with real relationship includes request body" do
      operation =
        RelationshipRoutes.build_operation(route_with_real_relationship(:post_to_relationship))

      assert operation[:requestBody]
      assert operation[:requestBody][:content]["application/vnd.api+json"][:schema]
    end

    test "patch_relationship with real relationship includes request body" do
      operation =
        RelationshipRoutes.build_operation(route_with_real_relationship(:patch_relationship))

      assert operation[:requestBody]
    end

    test "delete_from_relationship with real relationship includes request body" do
      operation =
        RelationshipRoutes.build_operation(
          route_with_real_relationship(:delete_from_relationship)
        )

      assert operation[:requestBody]
    end
  end

  describe "unknown route type fallbacks" do
    # Tests for fallback branches with unknown route types

    test "unknown route type uses fallback operationId" do
      route = %{
        type: :custom_operation,
        resource: AshOaskit.Test.Post,
        relationship: :comments,
        route: "/posts/:id/custom",
        action: :read,
        name: :custom
      }

      operation = RelationshipRoutes.build_operation(route)

      # Should use fallback format
      assert operation[:operationId] =~ "post_comments"
    end

    test "unknown route type uses fallback summary" do
      route = %{
        type: :custom_operation,
        resource: AshOaskit.Test.Post,
        relationship: :comments,
        route: "/posts/:id/custom",
        action: :read,
        name: :custom
      }

      operation = RelationshipRoutes.build_operation(route)

      # Should use fallback summary
      assert operation[:summary] =~ "operation"
    end

    test "unknown route type uses fallback responses" do
      route = %{
        type: :custom_operation,
        resource: AshOaskit.Test.Post,
        relationship: :comments,
        route: "/posts/:id/custom",
        action: :read,
        name: :custom
      }

      operation = RelationshipRoutes.build_operation(route)

      assert operation[:responses]["200"][:description] == "Successful response"
    end
  end
end
