defmodule AshOaskit.PhoenixIntrospectionTest do
  @moduledoc """
  Tests for the AshOaskit.PhoenixIntrospection module.

  This module tests the extraction of OpenAPI path information from Phoenix
  routers that implement the `AshOaskit.OpenApiController` behaviour. It
  bridges Phoenix routing with OpenAPI spec generation.

  ## Test Categories

  - **Route extraction** - Discovering routes from Phoenix router modules
  - **Path conversion** - Converting Phoenix `:param` syntax to OpenAPI `{param}`
  - **Parameter injection** - Auto-adding missing path parameters to operations
  - **Operation merging** - Combining controller-defined operations with route metadata
  - **Multi-segment paths** - Handling paths with multiple dynamic segments

  ## Why These Tests Matter

  Phoenix introspection allows users to define custom OpenAPI operations via
  controllers while AshOaskit handles Ash-generated routes. Incorrect path
  extraction or parameter injection breaks the combined spec.
  """

  use ExUnit.Case, async: true

  alias AshOaskit.PhoenixIntrospection

  # Test controller implementing the OpenApiController behaviour
  defmodule TestHealthController do
    @behaviour AshOaskit.OpenApiController

    @impl true
    def openapi_operations do
      %{
        index: %{
          summary: "Health check",
          tags: ["Infrastructure"],
          responses: %{
            "200" => %{description: "Healthy"}
          }
        },
        show: %{
          summary: "Detailed health",
          parameters: [
            %{
              name: "id",
              in: :path,
              required: true,
              schema: %{type: :string}
            }
          ],
          responses: %{
            "200" => %{description: "Success"}
          }
        }
      }
    end

    @impl true
    def openapi_tag do
      %{name: "Infrastructure", description: "System health endpoints"}
    end
  end

  # Controller with tag as string
  defmodule TestItemsController do
    @behaviour AshOaskit.OpenApiController

    @impl true
    def openapi_operations do
      %{
        index: %{
          summary: "List items",
          responses: %{"200" => %{description: "Success"}}
        }
      }
    end

    @impl true
    def openapi_tag do
      "Items"
    end
  end

  # Controller without openapi_tag (optional callback)
  defmodule TestUsersController do
    @behaviour AshOaskit.OpenApiController

    @impl true
    def openapi_operations do
      %{
        index: %{
          summary: "List users",
          responses: %{"200" => %{description: "Success"}}
        }
      }
    end
  end

  # Controller without the behaviour (should be excluded)
  defmodule TestPlainController do
    @spec index(any(), any()) :: :ok
    def index(_, _), do: :ok
  end

  # Tag using atom keys
  defmodule TestAtomTagController do
    @behaviour AshOaskit.OpenApiController

    @impl true
    def openapi_operations do
      %{
        index: %{
          summary: "Atom tag test",
          responses: %{"200" => %{description: "OK"}}
        }
      }
    end

    @impl true
    def openapi_tag do
      %{name: "AtomTag", description: "Tag with atom keys"}
    end
  end

  # Mock router that returns routes via __routes__/0
  defmodule TestRouter do
    @spec __routes__() :: [map()]
    def __routes__ do
      [
        %{
          path: "/api/health",
          verb: :get,
          plug: TestHealthController,
          plug_opts: :index
        },
        %{
          path: "/api/health/:id",
          verb: :get,
          plug: TestHealthController,
          plug_opts: :show
        },
        %{
          path: "/api/items",
          verb: :get,
          plug: TestItemsController,
          plug_opts: :index
        },
        %{
          path: "/api/users",
          verb: :get,
          plug: TestUsersController,
          plug_opts: :index
        },
        %{
          path: "/api/plain",
          verb: :get,
          plug: TestPlainController,
          plug_opts: :index
        },
        %{
          path: "/api/atom-tags",
          verb: :get,
          plug: TestAtomTagController,
          plug_opts: :index
        }
      ]
    end
  end

  # Router with no routes
  defmodule EmptyRouter do
    @spec __routes__() :: [map()]
    def __routes__, do: []
  end

  # Router with action not in openapi_operations (triggers default_operation)
  defmodule RouterWithUnknownAction do
    @spec __routes__() :: [map()]
    def __routes__ do
      [
        %{
          path: "/api/health/liveness",
          verb: :get,
          plug: TestHealthController,
          plug_opts: :liveness
        }
      ]
    end
  end

  # Router with non-atom plug (should be filtered out)
  defmodule RouterWithNonAtomPlug do
    @spec __routes__() :: [map()]
    def __routes__ do
      [%{path: "/test", verb: :get, plug: "not_a_module", plug_opts: :index}]
    end
  end

  # Router with path params already defined in operation
  defmodule RouterWithExistingParams do
    @spec __routes__() :: [map()]
    def __routes__ do
      [
        %{
          path: "/api/health/:id",
          verb: :get,
          plug: TestHealthController,
          plug_opts: :show
        }
      ]
    end
  end

  describe "extract_routes/1" do
    test "extracts routes from controllers implementing OpenApiController" do
      routes = PhoenixIntrospection.extract_routes(TestRouter)

      # Should exclude TestPlainController (no behaviour)
      controllers = Enum.map(routes, & &1.controller)
      refute TestPlainController in controllers
      assert TestHealthController in controllers
      assert TestItemsController in controllers
      assert TestUsersController in controllers
    end

    test "builds route info with correct fields" do
      routes = PhoenixIntrospection.extract_routes(TestRouter)
      health_route = Enum.find(routes, &(&1.path == "/api/health"))

      assert health_route.verb == :get
      assert health_route.controller == TestHealthController
      assert health_route.action == :index
      assert health_route.operation[:summary] == "Health check"
      assert health_route.operation[:operationId] == "test_health_index"
    end

    test "converts path params from Phoenix to OpenAPI format" do
      routes = PhoenixIntrospection.extract_routes(TestRouter)
      show_route = Enum.find(routes, &(&1.path == "/api/health/{id}"))

      assert show_route
      assert show_route.action == :show
    end

    test "adds path parameters to operation when not present" do
      routes = PhoenixIntrospection.extract_routes(RouterWithExistingParams)
      show_route = Enum.find(routes, &(&1.action == :show))

      # show already has "id" parameter defined - should not duplicate
      params = show_route.operation[:parameters]
      id_params = Enum.filter(params, &(&1[:name] == "id"))
      assert length(id_params) == 1
    end

    test "creates default operation for unmapped actions" do
      routes = PhoenixIntrospection.extract_routes(RouterWithUnknownAction)
      liveness_route = Enum.find(routes, &(&1.action == :liveness))

      assert liveness_route.operation[:summary] =~ "Liveness"
      assert liveness_route.operation[:tags] == ["TestHealth"]
      assert liveness_route.operation[:responses]["200"]
    end

    test "returns empty list for non-existent router" do
      assert PhoenixIntrospection.extract_routes(NonExistentModule) == []
    end

    test "returns empty list for router without __routes__" do
      assert PhoenixIntrospection.extract_routes(String) == []
    end

    test "returns empty list for empty router" do
      assert PhoenixIntrospection.extract_routes(EmptyRouter) == []
    end

    test "filters out non-atom plugs" do
      assert PhoenixIntrospection.extract_routes(RouterWithNonAtomPlug) == []
    end
  end

  describe "routes_to_paths/1" do
    test "groups routes by path with method keys" do
      routes = PhoenixIntrospection.extract_routes(TestRouter)
      paths = PhoenixIntrospection.routes_to_paths(routes)

      assert Map.has_key?(paths, "/api/health")
      assert Map.has_key?(paths["/api/health"], "get")
      assert paths["/api/health"]["get"][:summary] == "Health check"
    end

    test "converts verb atoms to lowercase strings" do
      routes = PhoenixIntrospection.extract_routes(TestRouter)
      paths = PhoenixIntrospection.routes_to_paths(routes)

      for {_, operations} <- paths do
        for {method, _} <- operations do
          assert method == String.downcase(method)
        end
      end
    end

    test "returns empty map for empty routes" do
      assert PhoenixIntrospection.routes_to_paths([]) == %{}
    end
  end

  describe "extract_tags/1" do
    test "extracts tags from controllers with openapi_tag/0" do
      tags = PhoenixIntrospection.extract_tags(TestRouter)
      tag_names = Enum.map(tags, & &1[:name])

      assert "Infrastructure" in tag_names
      assert "Items" in tag_names
    end

    test "normalizes string tags to map format" do
      tags = PhoenixIntrospection.extract_tags(TestRouter)
      items_tag = Enum.find(tags, &(&1[:name] == "Items"))

      assert items_tag == %{name: "Items"}
    end

    test "normalizes map tags with description" do
      tags = PhoenixIntrospection.extract_tags(TestRouter)
      infra_tag = Enum.find(tags, &(&1[:name] == "Infrastructure"))

      assert infra_tag[:description] == "System health endpoints"
    end

    test "normalizes tags with atom keys" do
      tags = PhoenixIntrospection.extract_tags(TestRouter)
      atom_tag = Enum.find(tags, &(&1[:name] == "AtomTag"))

      assert atom_tag[:name] == "AtomTag"
      assert atom_tag[:description] == "Tag with atom keys"
    end

    test "uses controller name as fallback tag" do
      tags = PhoenixIntrospection.extract_tags(TestRouter)
      tag_names = Enum.map(tags, & &1[:name])

      # TestUsersController has no openapi_tag, so uses "TestUsers"
      assert "TestUsers" in tag_names
    end

    test "deduplicates tags by name" do
      tags = PhoenixIntrospection.extract_tags(TestRouter)
      tag_names = Enum.map(tags, & &1[:name])

      assert length(tag_names) == length(Enum.uniq(tag_names))
    end

    test "returns empty list for non-existent router" do
      assert PhoenixIntrospection.extract_tags(NonExistentModule) == []
    end

    test "returns empty list for router without __routes__" do
      assert PhoenixIntrospection.extract_tags(String) == []
    end
  end

  describe "normalize_tag with string-keyed maps" do
    defmodule StringKeyTagController do
      @behaviour AshOaskit.OpenApiController

      @impl true
      def openapi_operations do
        %{
          index: %{
            summary: "String key tag test",
            responses: %{"200" => %{description: "OK"}}
          }
        }
      end

      @impl true
      def openapi_tag do
        # Return a map with string keys to test normalization to atom keys
        %{"name" => "StringKeyTag", "description" => "Tag with string keys"}
      end
    end

    defmodule StringKeyTagRouter do
      @spec __routes__() :: [map()]
      def __routes__ do
        [
          %{
            path: "/api/string-key-items",
            verb: :get,
            plug: StringKeyTagController,
            plug_opts: :index
          }
        ]
      end
    end

    test "normalizes tag with string keys to atom keys" do
      tags = PhoenixIntrospection.extract_tags(StringKeyTagRouter)
      tag = Enum.find(tags, &(&1[:name] == "StringKeyTag"))

      assert tag
      assert tag[:name] == "StringKeyTag"
      assert tag[:description] == "Tag with string keys"
    end

    test "normalize_tag handles map with only string name key" do
      defmodule StringNameOnlyController do
        @behaviour AshOaskit.OpenApiController

        @impl true
        def openapi_operations do
          %{
            index: %{
              summary: "Name only",
              responses: %{"200" => %{description: "OK"}}
            }
          }
        end

        @impl true
        def openapi_tag do
          %{"name" => "NameOnly"}
        end
      end

      defmodule StringNameOnlyRouter do
        @spec __routes__() :: [map()]
        def __routes__ do
          [
            %{
              path: "/api/name-only",
              verb: :get,
              plug: StringNameOnlyController,
              plug_opts: :index
            }
          ]
        end
      end

      tags = PhoenixIntrospection.extract_tags(StringNameOnlyRouter)
      tag = Enum.find(tags, &(&1[:name] == "NameOnly"))

      assert tag
      assert tag[:name] == "NameOnly"
      refute Map.has_key?(tag, :description)
    end
  end

  describe "multi-segment path parameter injection" do
    defmodule CoverageTestController do
      @behaviour AshOaskit.OpenApiController

      @impl true
      def openapi_operations do
        %{
          show: %{
            summary: "Show item",
            responses: %{"200" => %{description: "OK"}}
          }
        }
      end
    end

    defmodule CoverageTestRouter do
      @spec __routes__() :: [map()]
      def __routes__ do
        [
          %{
            path: "/items/:item_id/sub/:sub_id",
            verb: :get,
            plug: CoverageTestController,
            plug_opts: :show
          }
        ]
      end
    end

    test "auto-adds missing path parameters from multi-segment route path" do
      routes = PhoenixIntrospection.extract_routes(CoverageTestRouter)
      route = hd(routes)
      params = route.operation[:parameters]
      names = Enum.map(params, & &1[:name])

      assert "item_id" in names
      assert "sub_id" in names
      assert Enum.all?(params, &(&1[:in] == :path))
      assert Enum.all?(params, &(&1[:required] == true))
    end

    test "converts multi-segment route to OpenAPI path format" do
      paths =
        PhoenixIntrospection.routes_to_paths(
          PhoenixIntrospection.extract_routes(CoverageTestRouter)
        )

      assert Map.has_key?(paths, "/items/{item_id}/sub/{sub_id}")
    end
  end
end
