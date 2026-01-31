defmodule AshOaskit.Generators.PathBuilderTest do
  @moduledoc """
  Tests for the AshOaskit.Generators.PathBuilder module.

  This module tests the generation of OpenAPI path objects and operations
  from Ash domain route definitions and Phoenix controller routes.

  ## Test Categories

  - **Path building** - Generating paths from single and multiple domains
  - **Deep merge** - Overlapping controller routes merging with Ash routes
  - **Operation building** - Index, get, post, patch, delete operations
  - **Humanize** - Converting underscore strings to title case
  - **Domain paths** - Relationship paths, edge case domains, self-referential routes
  - **Response codes** - Standard error codes (400, 401, 404, 422) on operations

  ## How It Works

  The PathBuilder collects routes from AshJsonApi domain configuration,
  builds OpenAPI operation objects for each route, and optionally merges
  in paths from a Phoenix router implementing the OpenApiController behaviour.
  """

  use ExUnit.Case, async: true

  alias AshJsonApi.Domain.Info
  alias AshOaskit.Generators.PathBuilder
  alias AshOaskit.Test.Blog
  alias AshOaskit.Test.EdgeCaseDomain
  alias AshOaskit.Test.Publishing

  describe "build_paths/2" do
    test "builds paths from a single domain" do
      paths = PathBuilder.build_paths([Blog], version: "3.1")

      assert Map.has_key?(paths, "/posts")
      assert Map.has_key?(paths, "/posts/{id}")
      assert Map.has_key?(paths, "/comments")
    end

    test "builds paths from multiple domains" do
      paths =
        PathBuilder.build_paths(
          [Blog, Publishing],
          version: "3.1"
        )

      assert Map.has_key?(paths, "/posts")
      assert Map.has_key?(paths, "/articles")
      assert Map.has_key?(paths, "/authors")
    end

    test "returns empty map for empty domain list" do
      paths = PathBuilder.build_paths([], version: "3.1")
      assert paths == %{}
    end

    test "router: nil produces no controller paths" do
      paths = PathBuilder.build_paths([Blog], version: "3.1", router: nil)
      assert Map.has_key?(paths, "/posts")
    end
  end

  describe "deep_merge_paths with overlapping controller routes" do
    defmodule OverlappingController do
      @behaviour AshOaskit.OpenApiController

      @impl true
      def openapi_operations do
        %{
          search: %{
            "summary" => "Search posts",
            "operationId" => "searchPosts",
            "responses" => %{"200" => %{"description" => "Search results"}}
          }
        }
      end
    end

    defmodule OverlappingRouter do
      @spec __routes__() :: [map()]
      def __routes__ do
        [
          %{
            path: "/posts",
            verb: :get,
            plug: OverlappingController,
            plug_opts: :search
          }
        ]
      end
    end

    test "controller route merges into existing ash path" do
      paths =
        PathBuilder.build_paths(
          [Blog],
          version: "3.1",
          router: OverlappingRouter
        )

      # The controller GET /posts should override the ash GET /posts
      assert paths["/posts"]["get"]["operationId"] == "searchPosts"
      # But the ash POST /posts should remain
      assert Map.has_key?(paths["/posts"], "post")
    end

    defmodule NonOverlappingController do
      @behaviour AshOaskit.OpenApiController

      @impl true
      def openapi_operations do
        %{
          health: %{
            "summary" => "Health check",
            "operationId" => "healthCheck",
            "responses" => %{"200" => %{"description" => "OK"}}
          }
        }
      end
    end

    defmodule NonOverlappingRouter do
      @spec __routes__() :: [map()]
      def __routes__ do
        [
          %{
            path: "/health",
            verb: :get,
            plug: NonOverlappingController,
            plug_opts: :health
          }
        ]
      end
    end

    test "controller route adds new path alongside ash paths" do
      paths =
        PathBuilder.build_paths(
          [Blog],
          version: "3.1",
          router: NonOverlappingRouter
        )

      assert Map.has_key?(paths, "/posts")
      assert Map.has_key?(paths, "/health")
      assert paths["/health"]["get"]["operationId"] == "healthCheck"
    end

    defmodule EmptyRouter do
      @spec __routes__() :: [map()]
      def __routes__, do: []
    end

    test "empty router produces identical paths to no router" do
      without = PathBuilder.build_paths([Blog], version: "3.1")

      with_empty =
        PathBuilder.build_paths([Blog], version: "3.1", router: EmptyRouter)

      assert without == with_empty
    end
  end

  describe "build_operation/2" do
    test "index route has _list suffix in operationId" do
      routes = Info.routes(Blog)
      index_route = Enum.find(routes, &(&1.type == :index))
      operation = PathBuilder.build_operation(index_route, version: "3.1")

      assert String.ends_with?(operation["operationId"], "_list")
      assert is_list(operation["tags"])
      assert is_list(operation["parameters"])
    end

    test "get route does not have _list suffix" do
      routes = Info.routes(Blog)
      get_route = Enum.find(routes, &(&1.type == :get))
      operation = PathBuilder.build_operation(get_route, version: "3.1")

      refute String.ends_with?(operation["operationId"], "_list")
    end

    test "post route has request body and no parameters" do
      routes = Info.routes(Blog)
      post_route = Enum.find(routes, &(&1.type == :post))
      operation = PathBuilder.build_operation(post_route, version: "3.1")

      assert operation["requestBody"]["required"] == true
      assert operation["requestBody"]["content"]["application/vnd.api+json"]
      refute Map.has_key?(operation, "parameters")
    end

    test "patch route has request body" do
      routes = Info.routes(Blog)
      patch_route = Enum.find(routes, &(&1.type == :patch))
      operation = PathBuilder.build_operation(patch_route, version: "3.1")

      assert operation["requestBody"]["required"] == true
    end

    test "delete route has 204 response" do
      routes = Info.routes(Blog)
      delete_route = Enum.find(routes, &(&1.type == :delete))
      operation = PathBuilder.build_operation(delete_route, version: "3.1")

      assert operation["responses"]["204"]["description"] == "Deleted successfully"
    end

    test "get route includes path parameters" do
      routes = Info.routes(Blog)
      get_route = Enum.find(routes, &(&1.type == :get))
      operation = PathBuilder.build_operation(get_route, version: "3.1")

      path_params = Enum.filter(operation["parameters"], &(&1["in"] == "path"))
      assert path_params != []
      assert Enum.all?(path_params, &(&1["required"] == true))
    end

    test "index route includes query parameters (filter, sort, page)" do
      routes = Info.routes(Blog)
      index_route = Enum.find(routes, &(&1.type == :index))
      operation = PathBuilder.build_operation(index_route, version: "3.1")

      param_names = Enum.map(operation["parameters"], & &1["name"])
      assert "filter" in param_names
      assert "sort" in param_names
      assert "page" in param_names
    end

    test "builds operation for all route types in Blog" do
      routes = Info.routes(Blog)

      for route <- routes do
        operation = PathBuilder.build_operation(route, version: "3.1")
        assert is_binary(operation["operationId"])
        assert is_map(operation["responses"])
      end
    end

    test "builds operations for relationship routes in Publishing" do
      routes = Info.routes(Publishing)

      rel_routes =
        Enum.filter(routes, fn r ->
          r.type in [:related, :relationship, :post_to_relationship, :delete_from_relationship]
        end)

      assert rel_routes != []

      for route <- rel_routes do
        operation = PathBuilder.build_operation(route, version: "3.1")
        assert is_binary(operation["operationId"])
      end
    end
  end

  describe "humanize/1" do
    test "capitalizes single word" do
      assert PathBuilder.humanize("hello") == "Hello"
    end

    test "capitalizes and joins underscore-separated words" do
      assert PathBuilder.humanize("create_user") == "Create User"
      assert PathBuilder.humanize("foo_bar_baz") == "Foo Bar Baz"
    end

    test "handles already-capitalized input" do
      assert PathBuilder.humanize("Hello") == "Hello"
    end
  end

  describe "path generation for different domains" do
    test "Publishing domain produces relationship paths" do
      paths = PathBuilder.build_paths([Publishing], version: "3.1")

      has_relationship_path = Enum.any?(Map.keys(paths), &String.contains?(&1, "relationships"))
      assert has_relationship_path

      has_related_path =
        Enum.any?(Map.keys(paths), fn path ->
          String.contains?(path, "/reviews") and String.contains?(path, "/articles")
        end)

      assert has_related_path
    end

    test "EdgeCaseDomain with no-type resource builds valid paths" do
      paths = PathBuilder.build_paths([EdgeCaseDomain], version: "3.1")
      assert map_size(paths) > 0
    end

    test "Category self-referential routes do not cause issues" do
      paths = PathBuilder.build_paths([Publishing], version: "3.1")
      assert Map.has_key?(paths, "/categories")
    end

    test "responses include standard error codes" do
      routes = Info.routes(Blog)
      get_route = Enum.find(routes, &(&1.type == :get))
      operation = PathBuilder.build_operation(get_route, version: "3.1")

      assert Map.has_key?(operation["responses"], "400")
      assert Map.has_key?(operation["responses"], "401")
      assert Map.has_key?(operation["responses"], "404")
      assert Map.has_key?(operation["responses"], "422")
    end
  end
end
