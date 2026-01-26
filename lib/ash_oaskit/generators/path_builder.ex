defmodule AshOaskit.Generators.PathBuilder do
  @moduledoc """
  OpenAPI paths and operations builder.

  This module generates the `paths` section of OpenAPI specifications,
  converting Ash domain routes into OpenAPI path items with operations.

  ## Overview

  For each route defined in an Ash domain, this module generates:

  - Path item with the appropriate HTTP method
  - Operation with operationId, summary, tags
  - Parameters (path, query)
  - Request body (for POST/PATCH)
  - Response definitions

  ## Route Types

  Standard CRUD routes are mapped to HTTP methods:

  | Route Type | HTTP Method | Success Code |
  |------------|-------------|--------------|
  | `:index` | GET | 200 |
  | `:get` | GET | 200 |
  | `:post` | POST | 201 |
  | `:patch` | PATCH | 200 |
  | `:delete` | DELETE | 204 |

  Relationship routes are delegated to `AshOaskit.RelationshipRoutes`.

  ## Query Parameters

  For GET operations, the following parameters are added:

  - **filter** - Field-specific filtering (from FilterBuilder)
  - **sort** - Sorting specification (from SortBuilder)
  - **page** - Pagination (offset, limit, cursor-based)
  - **include** - Relationship inclusion paths

  ## Usage

      paths = PathBuilder.build_paths([MyApp.Domain], version: "3.1")
  """

  alias AshOaskit.FilterBuilder
  alias AshOaskit.Generators.InfoBuilder
  alias AshOaskit.RelationshipRoutes
  alias AshOaskit.SortBuilder

  @type opts :: keyword()

  @doc """
  Builds paths from domains.

  Extracts all routes from the given domains and converts them
  to OpenAPI path items grouped by path.

  ## Parameters

  - `domains` - List of Ash domain modules
  - `opts` - Options including `:version`

  ## Returns

  A map of path strings to path item objects.

  ## Examples

      iex> PathBuilder.build_paths([MyApp.Blog], version: "3.1")
      %{
        "/posts" => %{
          "get" => %{...},
          "post" => %{...}
        },
        "/posts/{id}" => %{
          "get" => %{...},
          "patch" => %{...},
          "delete" => %{...}
        }
      }
  """
  @spec build_paths(list(module()), opts()) :: map()
  def build_paths(domains, opts) do
    domains
    |> Enum.flat_map(&get_domain_routes/1)
    |> Enum.group_by(fn {path, _route} -> path end)
    |> Enum.map(fn {path, routes} ->
      operations =
        routes
        |> Enum.map(fn {_path, route} ->
          {route_to_method(route), build_operation(route, opts)}
        end)
        |> Map.new()

      {path, operations}
    end)
    |> Map.new()
  end

  @doc """
  Builds an operation object for a route.

  ## Parameters

  - `route` - The AshJsonApi route struct
  - `opts` - Options including `:version`

  ## Returns

  An OpenAPI operation object.
  """
  @spec build_operation(map(), opts()) :: map()
  def build_operation(route, opts) do
    version = Keyword.fetch!(opts, :version)

    if RelationshipRoutes.relationship_route?(route) do
      RelationshipRoutes.build_operation(route, opts)
    else
      %{
        "operationId" => build_operation_id(route),
        "summary" => route.name |> to_string() |> humanize(),
        "responses" => build_responses(route)
      }
      |> InfoBuilder.maybe_add("tags", build_operation_tags(route))
      |> InfoBuilder.maybe_add("parameters", build_parameters(route, version))
      |> InfoBuilder.maybe_add("requestBody", build_request_body(route))
    end
  end

  @doc """
  Humanizes an underscore-separated string.

  ## Parameters

  - `string` - The underscore-separated string to humanize

  ## Returns

  A title-cased, space-separated string.

  ## Examples

      iex> PathBuilder.humanize("create_user")
      "Create User"
  """
  @spec humanize(String.t()) :: String.t()
  def humanize(string) do
    string
    |> String.replace("_", " ")
    |> String.split(" ")
    |> Enum.map_join(" ", &String.capitalize/1)
  end

  # Gets routes from a domain with their paths
  defp get_domain_routes(domain) do
    domain
    |> AshJsonApi.Domain.Info.routes()
    |> Enum.map(fn route -> {route.route, route} end)
  end

  # Converts route type to HTTP method string
  defp route_to_method(route) do
    if RelationshipRoutes.relationship_route?(route) do
      RelationshipRoutes.route_method(route)
    else
      route.type
      |> to_string()
      |> String.downcase()
    end
  end

  # Builds operation ID from resource and action names
  defp build_operation_id(route) do
    resource_name =
      route.resource
      |> Module.split()
      |> List.last()
      |> Macro.underscore()

    action_name = to_string(route.action)
    "#{resource_name}_#{action_name}"
  end

  # Builds operation tags from resource name
  defp build_operation_tags(route) do
    resource_name =
      route.resource
      |> Module.split()
      |> List.last()

    [resource_name]
  end

  # Builds parameters for an operation (path + query params)
  defp build_parameters(route, version) do
    path_params =
      route.route
      |> extract_path_params()
      |> Enum.map(fn param ->
        %{
          "name" => param,
          "in" => "path",
          "required" => true,
          "schema" => %{"type" => "string"}
        }
      end)

    params =
      if route.type in [:index, :get] do
        path_params ++ build_query_parameters(route, version)
      else
        path_params
      end

    case params do
      [] -> nil
      params -> params
    end
  end

  # Extracts path parameter names from a route path
  defp extract_path_params(path) do
    ~r/:([a-zA-Z_]+)/
    |> Regex.scan(path)
    |> Enum.map(fn [_, name] -> name end)
  end

  # Builds query parameters for GET operations
  defp build_query_parameters(route, version) do
    resource = route.resource

    filter_param = FilterBuilder.build_filter_parameter(resource, version: version)
    sort_param = SortBuilder.build_sort_parameter(resource, version: version)

    base_params = [
      %{
        "name" => "page",
        "in" => "query",
        "required" => false,
        "schema" => %{
          "type" => "object",
          "properties" => %{
            "offset" => %{"type" => "integer", "minimum" => 0},
            "limit" => %{"type" => "integer", "minimum" => 1},
            "after" => %{"type" => "string"},
            "before" => %{"type" => "string"},
            "count" => %{"type" => "boolean"}
          }
        },
        "style" => "deepObject",
        "description" => "Pagination parameters"
      },
      %{
        "name" => "include",
        "in" => "query",
        "required" => false,
        "schema" => %{"type" => "string"},
        "description" => "Comma-separated list of relationship paths to include"
      }
    ]

    params = if sort_param, do: [sort_param | base_params], else: base_params
    if filter_param, do: [filter_param | params], else: params
  end

  # Builds request body for POST/PATCH operations
  defp build_request_body(route) do
    if route.type in [:post, :patch] do
      schema_name =
        route.resource
        |> Module.split()
        |> List.last()

      %{
        "required" => true,
        "content" => %{
          "application/vnd.api+json" => %{
            "schema" => %{
              "type" => "object",
              "properties" => %{
                "data" => %{
                  "type" => "object",
                  "properties" => %{
                    "type" => %{"type" => "string"},
                    "attributes" => %{
                      "$ref" => "#/components/schemas/#{schema_name}Attributes"
                    }
                  }
                }
              }
            }
          }
        }
      }
    else
      nil
    end
  end

  # Builds response definitions for an operation
  defp build_responses(route) do
    success_code =
      case route.type do
        :post -> "201"
        :delete -> "204"
        _ -> "200"
      end

    schema_name =
      route.resource
      |> Module.split()
      |> List.last()

    success_response =
      if route.type == :delete do
        %{"description" => "Deleted successfully"}
      else
        %{
          "description" => "Successful response",
          "content" => %{
            "application/vnd.api+json" => %{
              "schema" => %{
                "$ref" => "#/components/schemas/#{schema_name}Response"
              }
            }
          }
        }
      end

    %{
      success_code => success_response,
      "400" => %{"description" => "Bad request"},
      "401" => %{"description" => "Unauthorized"},
      "404" => %{"description" => "Not found"},
      "422" => %{"description" => "Unprocessable entity"}
    }
  end
end
