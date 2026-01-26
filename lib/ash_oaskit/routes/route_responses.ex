defmodule AshOaskit.RelationshipRoutes.RouteResponses do
  @moduledoc """
  Response schema builders for relationship routes.

  This module generates OpenAPI response schemas for JSON:API relationship
  endpoints, including both relationship linkage and related resource responses.

  ## Response Types

  ### Relationship Linkage Response

  For relationship endpoints (`/relationships/comments`), the response contains
  resource identifier objects (type + id only):

      %{
        "data" => [{"type": "comment", "id": "1"}, ...],
        "links" => {"self": "...", "related": "..."}
      }

  ### Related Resources Response

  For related endpoints (`/comments`), the response contains full resource
  representations with pagination:

      %{
        "data" => [full_resource_objects],
        "links" => {"self": "...", "first": "...", "next": "..."},
        "meta" => {"total": 42}
      }

  ## Cardinality

  Schema structure varies by relationship cardinality:

  - **to-one**: Single resource identifier or null
  - **to-many**: Array of resource identifiers

  ## Usage

      schema = RouteResponses.build_relationship_linkage_schema(relationship, version: "3.1")
      response = RouteResponses.build_related_response_schema(relationship, version: "3.1")
  """

  @to_one_relationships [:belongs_to, :has_one]

  @doc """
  Builds the resource identifier schema for a resource type.

  A resource identifier object contains only the `type` and `id` fields,
  as defined by JSON:API for relationship linkage.

  ## Parameters

  - `resource_type` - The JSON:API type name (string)

  ## Returns

  An OpenAPI schema object for a resource identifier.

  ## Examples

      iex> RouteResponses.build_resource_identifier_schema("comment")
      %{
        "type" => "object",
        "required" => ["type", "id"],
        "properties" => %{
          "type" => %{"type" => "string", "enum" => ["comment"]},
          "id" => %{"type" => "string", "description" => "The unique identifier of the resource"}
        }
      }
  """
  @spec build_resource_identifier_schema(String.t()) :: map()
  def build_resource_identifier_schema(resource_type) do
    %{
      "type" => "object",
      "required" => ["type", "id"],
      "properties" => %{
        "type" => %{"type" => "string", "enum" => [resource_type]},
        "id" => %{"type" => "string", "description" => "The unique identifier of the resource"}
      }
    }
  end

  @doc """
  Builds a relationship linkage schema for response/request bodies.

  For to-one relationships, returns a single resource identifier or null.
  For to-many relationships, returns an array of resource identifiers.

  ## Parameters

  - `relationship` - The Ash relationship struct
  - `opts` - Options keyword list including `:version`

  ## Returns

  An OpenAPI schema object for relationship linkage.
  """
  @spec build_relationship_linkage_schema(map() | struct(), keyword()) :: map()
  def build_relationship_linkage_schema(relationship, opts) do
    version = Keyword.get(opts, :version, "3.1")
    related_type = get_related_type(relationship)
    identifier_schema = build_resource_identifier_schema(related_type)

    case relationship_cardinality(relationship) do
      :one ->
        nullable_schema(identifier_schema, version)

      :many ->
        %{
          "type" => "array",
          "items" => identifier_schema
        }
    end
  end

  @doc """
  Builds a full relationship response schema with data and links.

  Used for relationship routes that return linkage data.

  ## Parameters

  - `relationship` - The Ash relationship struct
  - `opts` - Options keyword list

  ## Returns

  An OpenAPI schema object for a relationship response.
  """
  @spec build_relationship_response_schema(map() | struct(), keyword()) :: map()
  def build_relationship_response_schema(relationship, opts) do
    %{
      "type" => "object",
      "properties" => %{
        "data" => build_relationship_linkage_schema(relationship, opts),
        "links" => %{
          "type" => "object",
          "properties" => %{
            "self" => %{
              "type" => "string",
              "format" => "uri",
              "description" => "Link to this relationship"
            },
            "related" => %{
              "type" => "string",
              "format" => "uri",
              "description" => "Link to the related resource(s)"
            }
          }
        },
        "meta" => %{
          "type" => "object",
          "description" => "Optional metadata about the relationship"
        }
      }
    }
  end

  @doc """
  Builds a related resources response schema.

  Used for related routes that return full resource representations.

  ## Parameters

  - `relationship` - The Ash relationship struct
  - `opts` - Options keyword list

  ## Returns

  An OpenAPI schema object for a related resources response.
  """
  @spec build_related_response_schema(map() | struct(), keyword()) :: map()
  def build_related_response_schema(relationship, opts) do
    version = Keyword.get(opts, :version, "3.1")
    related_resource = relationship.destination
    schema_name = related_resource |> Module.split() |> List.last()

    data_schema =
      case relationship_cardinality(relationship) do
        :one ->
          nullable_schema(
            %{"$ref" => "#/components/schemas/#{schema_name}Response"},
            version
          )

        :many ->
          %{
            "type" => "array",
            "items" => %{"$ref" => "#/components/schemas/#{schema_name}Response"}
          }
      end

    %{
      "type" => "object",
      "properties" => %{
        "data" => data_schema,
        "links" => %{
          "type" => "object",
          "properties" => %{
            "self" => %{"type" => "string", "format" => "uri"},
            "first" => %{"type" => "string", "format" => "uri"},
            "last" => %{"type" => "string", "format" => "uri"},
            "prev" => %{"type" => "string", "format" => "uri"},
            "next" => %{"type" => "string", "format" => "uri"}
          }
        },
        "meta" => %{
          "type" => "object",
          "properties" => %{
            "total" => %{"type" => "integer", "description" => "Total count of related resources"}
          }
        }
      }
    }
  end

  @doc """
  Builds responses for related resource routes.

  ## Parameters

  - `route` - The AshJsonApi route struct
  - `opts` - Options keyword list

  ## Returns

  A map of response code to response object.
  """
  @spec build_related_responses(map(), keyword()) :: map()
  def build_related_responses(route, opts) do
    relationship = get_route_relationship(route)

    if relationship do
      %{
        "200" => %{
          "description" => "Successful response with related resources",
          "content" => %{
            "application/vnd.api+json" => %{
              "schema" => build_related_response_schema(relationship, opts)
            }
          }
        },
        "404" => %{"description" => "Resource not found"}
      }
    else
      %{
        "200" => %{"description" => "Successful response"},
        "404" => %{"description" => "Resource not found"}
      }
    end
  end

  @doc """
  Builds responses for relationship linkage routes.

  ## Parameters

  - `route` - The AshJsonApi route struct
  - `opts` - Options keyword list

  ## Returns

  A map of response code to response object.
  """
  @spec build_relationship_responses(map(), keyword()) :: map()
  def build_relationship_responses(route, opts) do
    relationship = get_route_relationship(route)

    if relationship do
      %{
        "200" => %{
          "description" => "Successful response with relationship linkage",
          "content" => %{
            "application/vnd.api+json" => %{
              "schema" => build_relationship_response_schema(relationship, opts)
            }
          }
        },
        "404" => %{"description" => "Resource not found"}
      }
    else
      %{
        "200" => %{"description" => "Successful response"},
        "404" => %{"description" => "Resource not found"}
      }
    end
  end

  @doc """
  Builds responses for relationship modification routes (POST/PATCH).

  ## Parameters

  - `route` - The AshJsonApi route struct
  - `opts` - Options keyword list
  - `success_code` - The success response code

  ## Returns

  A map of response code to response object.
  """
  @spec build_modify_relationship_responses(map(), keyword(), String.t()) :: map()
  def build_modify_relationship_responses(route, opts, success_code) do
    relationship = get_route_relationship(route)

    if relationship do
      %{
        success_code => %{
          "description" => "Relationship modified successfully",
          "content" => %{
            "application/vnd.api+json" => %{
              "schema" => build_relationship_response_schema(relationship, opts)
            }
          }
        },
        "400" => %{"description" => "Bad request - invalid relationship data"},
        "404" => %{"description" => "Resource not found"},
        "422" => %{"description" => "Unprocessable entity - validation error"}
      }
    else
      %{
        success_code => %{"description" => "Successful response"},
        "400" => %{"description" => "Bad request"},
        "404" => %{"description" => "Resource not found"}
      }
    end
  end

  @doc """
  Builds responses for relationship deletion routes.

  ## Returns

  A map of response code to response object.
  """
  @spec build_delete_relationship_responses() :: map()
  def build_delete_relationship_responses do
    %{
      "200" => %{"description" => "Resources removed from relationship successfully"},
      "204" => %{"description" => "Relationship cleared successfully"},
      "404" => %{"description" => "Resource not found"}
    }
  end

  @doc """
  Builds the request body schema for relationship modification.

  ## Parameters

  - `relationship` - The Ash relationship struct
  - `opts` - Options keyword list

  ## Returns

  An OpenAPI request body object.
  """
  @spec build_request_body(map() | struct(), keyword()) :: map()
  def build_request_body(relationship, opts) do
    %{
      "required" => true,
      "content" => %{
        "application/vnd.api+json" => %{
          "schema" => %{
            "type" => "object",
            "required" => ["data"],
            "properties" => %{
              "data" => build_relationship_linkage_schema(relationship, opts)
            }
          }
        }
      }
    }
  end

  @doc """
  Gets the relationship struct from a route.

  ## Parameters

  - `route` - The AshJsonApi route struct

  ## Returns

  The relationship struct or nil.
  """
  @spec get_route_relationship(map()) :: map() | nil
  def get_route_relationship(route) do
    if Map.has_key?(route, :relationship) and route.relationship do
      Ash.Resource.Info.relationship(route.resource, route.relationship)
    else
      nil
    end
  end

  @doc """
  Determines the cardinality of a relationship.

  ## Parameters

  - `relationship` - The Ash relationship struct

  ## Returns

  `:one` or `:many`.
  """
  @spec relationship_cardinality(map() | struct()) :: :one | :many
  def relationship_cardinality(relationship) do
    if relationship.type in @to_one_relationships, do: :one, else: :many
  end

  # Gets the JSON:API type for the related resource
  defp get_related_type(relationship) do
    case AshJsonApi.Resource.Info.type(relationship.destination) do
      nil -> default_type_name(relationship.destination)
      type -> type
    end
  end

  defp default_type_name(resource) do
    resource
    |> Module.split()
    |> List.last()
    |> Macro.underscore()
  end

  # Makes schema nullable based on OpenAPI version
  defp nullable_schema(schema, "3.1") do
    Map.update(schema, "type", ["object", "null"], fn type -> [type, "null"] end)
  end

  defp nullable_schema(schema, _version) do
    Map.put(schema, "nullable", true)
  end
end
