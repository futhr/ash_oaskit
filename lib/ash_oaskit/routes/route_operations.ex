defmodule AshOaskit.RelationshipRoutes.RouteOperations do
  @moduledoc """
  Operation builders for relationship routes.

  This module generates OpenAPI operation objects for JSON:API relationship
  endpoints, including operation metadata, parameters, and routing to
  appropriate response builders.

  ## Operations

  Each relationship route type generates a different operation:

  | Route Type | Method | Operation ID Pattern |
  |------------|--------|---------------------|
  | `:related` | GET | `{resource}_{rel}_related` |
  | `:relationship` | GET | `{resource}_{rel}_relationship` |
  | `:post_to_relationship` | POST | `{resource}_{rel}_add` |
  | `:patch_relationship` | PATCH | `{resource}_{rel}_replace` |
  | `:delete_from_relationship` | DELETE | `{resource}_{rel}_remove` |

  ## Parameters

  Path parameters are extracted from the route pattern (e.g., `:id`).
  Query parameters are added for related routes (pagination).

  ## Usage

      operation = RouteOperations.build_operation(route, version: "3.1")
  """

  alias AshOaskit.RelationshipRoutes.RouteResponses

  @doc """
  Builds an OpenAPI operation object for a relationship route.

  Generates the complete operation including operationId, summary,
  description, tags, parameters, responses, and optional request body.

  ## Parameters

  - `route` - An AshJsonApi route struct
  - `opts` - Options keyword list including `:version`

  ## Returns

  A map representing the OpenAPI operation object.
  """
  @spec build_operation(map(), keyword()) :: map()
  def build_operation(route, opts \\ []) do
    %{
      "operationId" => build_operation_id(route),
      "summary" => build_summary(route),
      "description" => build_description(route),
      "tags" => build_tags(route),
      "parameters" => build_parameters(route),
      "responses" => build_responses(route, opts)
    }
    |> maybe_add_request_body(route, opts)
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Enum.into(%{})
  end

  @doc """
  Builds the operation ID for a relationship route.

  ## Parameters

  - `route` - An AshJsonApi route struct

  ## Returns

  A unique operation identifier string.
  """
  @spec build_operation_id(map()) :: String.t()
  def build_operation_id(route) do
    resource_name =
      route.resource
      |> Module.split()
      |> List.last()
      |> Macro.underscore()

    relationship_name = to_string(Map.get(route, :relationship) || "related")

    case route.type do
      :related ->
        "#{resource_name}_#{relationship_name}_related"

      :relationship ->
        "#{resource_name}_#{relationship_name}_relationship"

      :post_to_relationship ->
        "#{resource_name}_#{relationship_name}_add"

      :patch_relationship ->
        "#{resource_name}_#{relationship_name}_replace"

      :delete_from_relationship ->
        "#{resource_name}_#{relationship_name}_remove"

      _ ->
        "#{resource_name}_#{relationship_name}"
    end
  end

  @doc """
  Builds the summary text for a relationship route.

  ## Parameters

  - `route` - An AshJsonApi route struct

  ## Returns

  A human-readable summary string.
  """
  @spec build_summary(map()) :: String.t()
  def build_summary(route) do
    resource_name = route.resource |> Module.split() |> List.last()
    relationship_name = route |> Map.get(:relationship, "related") |> to_string() |> humanize()

    case route.type do
      :related ->
        "Get #{relationship_name} for #{resource_name}"

      :relationship ->
        "Get #{relationship_name} relationship for #{resource_name}"

      :post_to_relationship ->
        "Add to #{relationship_name} relationship"

      :patch_relationship ->
        "Replace #{relationship_name} relationship"

      :delete_from_relationship ->
        "Remove from #{relationship_name} relationship"

      _ ->
        "#{relationship_name} operation"
    end
  end

  @doc """
  Builds the description text for a relationship route.

  ## Parameters

  - `route` - An AshJsonApi route struct

  ## Returns

  A description string or nil.
  """
  @spec build_description(map()) :: String.t() | nil
  def build_description(route) do
    case route.type do
      :related ->
        "Returns the related resources for this relationship."

      :relationship ->
        "Returns the resource identifiers for this relationship linkage."

      :post_to_relationship ->
        "Adds the specified resources to this to-many relationship."

      :patch_relationship ->
        "Completely replaces this relationship with the specified resource identifiers."

      :delete_from_relationship ->
        "Removes the specified resources from this to-many relationship."

      _ ->
        nil
    end
  end

  @doc """
  Builds the tags for a relationship route.

  ## Parameters

  - `route` - An AshJsonApi route struct

  ## Returns

  A list of tag strings.
  """
  @spec build_tags(map()) :: [String.t()]
  def build_tags(route) do
    resource_name = route.resource |> Module.split() |> List.last()
    [resource_name]
  end

  @doc """
  Builds the parameters for a relationship route.

  Extracts path parameters and adds query parameters for related routes.

  ## Parameters

  - `route` - An AshJsonApi route struct

  ## Returns

  A list of parameter objects.
  """
  @spec build_parameters(map()) :: [map()]
  def build_parameters(route) do
    path_params =
      route.route
      |> extract_path_params()
      |> Enum.map(fn param ->
        %{
          "name" => param,
          "in" => "path",
          "required" => true,
          "schema" => %{"type" => "string"},
          "description" => "The #{param} of the resource"
        }
      end)

    if route.type == :related do
      path_params ++
        [
          %{
            "name" => "page",
            "in" => "query",
            "required" => false,
            "style" => "deepObject",
            "schema" => %{
              "type" => "object",
              "properties" => %{
                "offset" => %{"type" => "integer"},
                "limit" => %{"type" => "integer"}
              }
            },
            "description" => "Pagination parameters"
          }
        ]
    else
      path_params
    end
  end

  # Builds responses based on route type
  defp build_responses(route, opts) do
    case route.type do
      :related ->
        RouteResponses.build_related_responses(route, opts)

      :relationship ->
        RouteResponses.build_relationship_responses(route, opts)

      :post_to_relationship ->
        RouteResponses.build_modify_relationship_responses(route, opts, "200")

      :patch_relationship ->
        RouteResponses.build_modify_relationship_responses(route, opts, "200")

      :delete_from_relationship ->
        RouteResponses.build_delete_relationship_responses()

      _ ->
        %{"200" => %{"description" => "Successful response"}}
    end
  end

  # Adds request body for modification routes
  defp maybe_add_request_body(operation, route, opts) do
    if route.type in [:post_to_relationship, :patch_relationship, :delete_from_relationship] do
      relationship = RouteResponses.get_route_relationship(route)

      if relationship do
        request_body = RouteResponses.build_request_body(relationship, opts)
        Map.put(operation, "requestBody", request_body)
      else
        operation
      end
    else
      operation
    end
  end

  # Extracts path parameter names from a route path
  defp extract_path_params(path) do
    ~r/:([a-zA-Z_]+)/
    |> Regex.scan(path)
    |> Enum.map(fn [_, name] -> name end)
  end

  # Humanizes an underscore-separated string
  defp humanize(string) do
    string
    |> String.replace("_", " ")
    |> String.split(" ")
    |> Enum.map_join(" ", &String.capitalize/1)
  end
end
