defmodule AshOaskit.RelationshipRoutes.RouteOperationsTest do
  @moduledoc """
  Tests for the `AshOaskit.RelationshipRoutes.RouteOperations` module.

  Verifies OpenAPI operation object generation for JSON:API relationship
  endpoints, including operation IDs, summaries, descriptions, tags,
  and parameters.

  ## Test categories

    - `build_operation_id/1` — Unique operation ID generation per route type
    - `build_summary/1` — Human-readable summary text
    - `build_description/1` — Detailed description per route type
    - `build_tags/1` — Resource-based tag assignment
    - `build_parameters/1` — Path and query parameter extraction
    - `build_operation/2` — Complete operation object assembly
  """
  use ExUnit.Case, async: true

  alias AshOaskit.RelationshipRoutes.RouteOperations

  # Mock route structs simulating AshJsonApi route structures
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

  defp mock_post_to_relationship_route do
    %{
      type: :post_to_relationship,
      resource: AshOaskit.Test.Post,
      relationship: :comments,
      route: "/posts/:id/relationships/comments",
      action: :update,
      name: :comments_add
    }
  end

  defp mock_patch_relationship_route do
    %{
      type: :patch_relationship,
      resource: AshOaskit.Test.Post,
      relationship: :comments,
      route: "/posts/:id/relationships/comments",
      action: :update,
      name: :comments_replace
    }
  end

  defp mock_delete_from_relationship_route do
    %{
      type: :delete_from_relationship,
      resource: AshOaskit.Test.Post,
      relationship: :comments,
      route: "/posts/:id/relationships/comments",
      action: :update,
      name: :comments_remove
    }
  end

  describe "build_operation_id/1" do
    test "related route generates _related suffix" do
      assert RouteOperations.build_operation_id(mock_related_route()) ==
               "post_comments_related"
    end

    test "relationship route generates _relationship suffix" do
      assert RouteOperations.build_operation_id(mock_relationship_route()) ==
               "post_comments_relationship"
    end

    test "post_to_relationship generates _add suffix" do
      assert RouteOperations.build_operation_id(mock_post_to_relationship_route()) ==
               "post_comments_add"
    end

    test "patch_relationship generates _replace suffix" do
      assert RouteOperations.build_operation_id(mock_patch_relationship_route()) ==
               "post_comments_replace"
    end

    test "delete_from_relationship generates _remove suffix" do
      assert RouteOperations.build_operation_id(mock_delete_from_relationship_route()) ==
               "post_comments_remove"
    end
  end

  describe "build_summary/1" do
    test "related route summary" do
      assert RouteOperations.build_summary(mock_related_route()) ==
               "Get Comments for Post"
    end

    test "relationship route summary" do
      assert RouteOperations.build_summary(mock_relationship_route()) ==
               "Get Comments relationship for Post"
    end

    test "post_to_relationship summary" do
      assert RouteOperations.build_summary(mock_post_to_relationship_route()) ==
               "Add to Comments relationship"
    end

    test "patch_relationship summary" do
      assert RouteOperations.build_summary(mock_patch_relationship_route()) ==
               "Replace Comments relationship"
    end

    test "delete_from_relationship summary" do
      assert RouteOperations.build_summary(mock_delete_from_relationship_route()) ==
               "Remove from Comments relationship"
    end
  end

  describe "build_description/1" do
    test "related route description" do
      desc = RouteOperations.build_description(mock_related_route())
      assert desc =~ "related resources"
    end

    test "relationship route description" do
      desc = RouteOperations.build_description(mock_relationship_route())
      assert desc =~ "resource identifiers"
    end

    test "post_to_relationship description" do
      desc = RouteOperations.build_description(mock_post_to_relationship_route())
      assert desc =~ "Adds"
    end

    test "patch_relationship description" do
      desc = RouteOperations.build_description(mock_patch_relationship_route())
      assert desc =~ "replaces"
    end

    test "delete_from_relationship description" do
      desc = RouteOperations.build_description(mock_delete_from_relationship_route())
      assert desc =~ "Removes"
    end

    test "unknown type returns nil" do
      assert RouteOperations.build_description(%{type: :unknown}) == nil
    end
  end

  describe "build_tags/1" do
    test "returns resource name as tag" do
      assert RouteOperations.build_tags(mock_related_route()) == ["Post"]
    end
  end

  describe "build_parameters/1" do
    test "extracts path parameters" do
      params = RouteOperations.build_parameters(mock_related_route())
      path_params = Enum.filter(params, &(&1.in == :path))

      assert length(path_params) == 1
      assert hd(path_params).name == "id"
      assert hd(path_params).required == true
    end

    test "related routes include pagination query parameter" do
      params = RouteOperations.build_parameters(mock_related_route())
      query_params = Enum.filter(params, &(&1.in == :query))

      assert length(query_params) == 1
      assert hd(query_params).name == "page"
    end

    test "relationship routes have no query parameters" do
      params = RouteOperations.build_parameters(mock_relationship_route())
      query_params = Enum.filter(params, &(&1.in == :query))

      assert query_params == []
    end

    test "extracts multiple path params from nested routes" do
      route = %{mock_related_route() | route: "/authors/:author_id/posts/:id/comments"}
      params = RouteOperations.build_parameters(route)
      path_params = Enum.filter(params, &(&1.in == :path))

      param_names = Enum.map(path_params, & &1.name)
      assert "author_id" in param_names
      assert "id" in param_names
    end
  end

  describe "build_operation/2" do
    test "returns complete operation object" do
      operation = RouteOperations.build_operation(mock_related_route())

      assert Map.has_key?(operation, :operationId)
      assert Map.has_key?(operation, :summary)
      assert Map.has_key?(operation, :tags)
      assert Map.has_key?(operation, :parameters)
      assert Map.has_key?(operation, :responses)
    end

    test "operation has correct operationId" do
      operation = RouteOperations.build_operation(mock_related_route())

      assert operation.operationId == "post_comments_related"
    end

    test "nil values are stripped from operation" do
      operation = RouteOperations.build_operation(%{mock_related_route() | type: :unknown})

      refute Map.has_key?(operation, :description)
    end
  end
end
