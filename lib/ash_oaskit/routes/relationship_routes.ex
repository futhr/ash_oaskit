defmodule AshOaskit.RelationshipRoutes do
  @moduledoc """
  Generates OpenAPI path operations for JSON:API relationship routes.

  This module handles the generation of OpenAPI specifications for relationship
  endpoints as defined by the JSON:API specification. These endpoints allow
  clients to manage relationships between resources independently of the
  resource attributes.

  ## JSON:API Relationship Routes

  JSON:API defines several types of relationship operations:

  ### Related Resource Routes

  These routes return the actual related resources:

      GET /posts/:id/comments

  Returns the full Comment resources that are related to the Post.

  ### Relationship Routes

  These routes operate on the relationship linkage itself:

      GET /posts/:id/relationships/comments
      POST /posts/:id/relationships/comments
      PATCH /posts/:id/relationships/comments
      DELETE /posts/:id/relationships/comments

  These endpoints work with resource identifier objects (type + id only),
  not full resource representations.

  ## Route Types

  The following AshJsonApi route types are supported:

  - `:related` - GET request returning related resources
  - `:relationship` - GET request returning relationship linkage
  - `:post_to_relationship` - POST to add to a to-many relationship
  - `:patch_relationship` - PATCH to replace relationship linkage
  - `:delete_from_relationship` - DELETE to remove from a to-many relationship

  ## Module Organization

  This module delegates to focused submodules:

  - `AshOaskit.RelationshipRoutes.RouteOperations` - Operation building
  - `AshOaskit.RelationshipRoutes.RouteResponses` - Response schema building

  ## Usage

      # Check if a route is a relationship route
      RelationshipRoutes.relationship_route?(route)

      # Build operation for a relationship route
      operation = RelationshipRoutes.build_operation(route, opts)

      # Build the path pattern for a relationship route
      path = RelationshipRoutes.build_path(route)

  ## Schema Generation

  Relationship routes use specific schema patterns:

  ### Resource Identifier Object

      %{
        type: :object,
        required: ["type", "id"],
        properties: %{
          "type" => %{type: :string},
          "id" => %{type: :string}
        }
      }

  ### Relationship Linkage Response

      %{
        type: :object,
        properties: %{
          "data" => resource_identifier_or_array,
          "links" => %{
            "self" => %{type: :string},
            "related" => %{type: :string}
          }
        }
      }
  """

  alias AshOaskit.RelationshipRoutes.RouteOperations
  alias AshOaskit.RelationshipRoutes.RouteResponses

  require Logger

  @relationship_route_types [
    :related,
    :relationship,
    :post_to_relationship,
    :patch_relationship,
    :delete_from_relationship
  ]

  @doc """
  Checks if the given route is a relationship route.

  Returns `true` if the route type is one of the relationship route types,
  `false` otherwise.

  ## Parameters

  - `route` - An AshJsonApi route struct

  ## Returns

  Boolean indicating if this is a relationship route.

  ## Examples

      iex> RelationshipRoutes.relationship_route?(%{type: :related})
      true

      iex> RelationshipRoutes.relationship_route?(%{type: :index})
      false
  """
  @spec relationship_route?(map()) :: boolean()
  def relationship_route?(route) do
    Map.get(route, :type) in @relationship_route_types
  end

  @doc """
  Builds an OpenAPI operation object for a relationship route.

  Generates the appropriate request/response schemas based on the
  relationship type and route operation.

  Delegates to `AshOaskit.RelationshipRoutes.RouteOperations.build_operation/2`.

  ## Parameters

  - `route` - An AshJsonApi route struct
  - `opts` - Options keyword list
    - `:version` - OpenAPI version ("3.0" or "3.1", defaults to "3.1")

  ## Returns

  A map representing the OpenAPI operation object.

  ## Examples

      RelationshipRoutes.build_operation(%{type: :related, ...}, [])
      # => %{
      #      operationId: "post_comments_related",
      #      summary: "Get related comments",
      #      ...
      #    }
  """
  @spec build_operation(map(), keyword()) :: map()
  defdelegate build_operation(route, opts \\ []), to: RouteOperations

  @doc """
  Builds the HTTP method for a relationship route.

  ## Parameters

  - `route` - An AshJsonApi route struct

  ## Returns

  The HTTP method as a lowercase string.

  ## Examples

      iex> RelationshipRoutes.route_method(%{type: :related})
      "get"

      iex> RelationshipRoutes.route_method(%{type: :post_to_relationship})
      "post"
  """
  @spec route_method(map()) :: String.t()
  def route_method(route) do
    case route.type do
      :related ->
        "get"

      :relationship ->
        "get"

      :post_to_relationship ->
        "post"

      :patch_relationship ->
        "patch"

      :delete_from_relationship ->
        "delete"

      other ->
        Logger.warning(
          "AshOaskit: unknown relationship route type: #{inspect(other)}, defaulting to GET"
        )

        "get"
    end
  end

  @doc """
  Builds the resource identifier schema for a resource type.

  A resource identifier object contains only the `type` and `id` fields,
  as defined by JSON:API for relationship linkage.

  Delegates to `AshOaskit.RelationshipRoutes.RouteResponses.build_resource_identifier_schema/1`.

  ## Parameters

  - `resource_type` - The JSON:API type name (string)

  ## Returns

  An OpenAPI schema object for a resource identifier.

  ## Examples

      iex> RelationshipRoutes.build_resource_identifier_schema("comment")
      %{
        type: :object,
        required: ["type", "id"],
        properties: %{
          "type" => %{type: :string, enum: ["comment"]},
          "id" => %{type: :string, description: "The unique identifier of the resource"}
        }
      }
  """
  @spec build_resource_identifier_schema(String.t()) :: map()
  defdelegate build_resource_identifier_schema(resource_type), to: RouteResponses

  @doc """
  Builds a relationship linkage schema for response/request bodies.

  For to-one relationships, returns a single resource identifier or null.
  For to-many relationships, returns an array of resource identifiers.

  Delegates to `AshOaskit.RelationshipRoutes.RouteResponses.build_relationship_linkage_schema/2`.

  ## Parameters

  - `relationship` - The Ash relationship struct
  - `opts` - Options keyword list including `:version`

  ## Returns

  An OpenAPI schema object for relationship linkage.
  """
  @spec build_relationship_linkage_schema(map() | struct(), keyword()) :: map()
  defdelegate build_relationship_linkage_schema(relationship, opts), to: RouteResponses

  @doc """
  Builds a full relationship response schema with data and links.

  Delegates to `AshOaskit.RelationshipRoutes.RouteResponses.build_relationship_response_schema/2`.

  ## Parameters

  - `relationship` - The Ash relationship struct
  - `opts` - Options keyword list

  ## Returns

  An OpenAPI schema object for a relationship response.
  """
  @spec build_relationship_response_schema(map() | struct(), keyword()) :: map()
  defdelegate build_relationship_response_schema(relationship, opts), to: RouteResponses

  @doc """
  Builds a related resources response schema.

  This is used for `:related` routes that return full resource representations.

  Delegates to `AshOaskit.RelationshipRoutes.RouteResponses.build_related_response_schema/2`.

  ## Parameters

  - `relationship` - The Ash relationship struct
  - `opts` - Options keyword list

  ## Returns

  An OpenAPI schema object for a related resources response.
  """
  @spec build_related_response_schema(map() | struct(), keyword()) :: map()
  defdelegate build_related_response_schema(relationship, opts), to: RouteResponses
end
