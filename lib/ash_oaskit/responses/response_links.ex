defmodule AshOaskit.ResponseLinks do
  @moduledoc """
  Generates JSON:API response links schemas for OpenAPI specifications.

  This module provides functions to build link objects for JSON:API responses,
  including self links, related links, and pagination links (first, last, prev, next).
  Links are essential for HATEOAS compliance and enable clients to navigate
  the API without hardcoding URLs.

  ## Link Types

  ### Self Links
  Every resource and collection response should include a `self` link pointing
  to the canonical URL for that resource or collection.

  ### Related Links
  Relationship objects include `related` links that point to the related
  resource collection endpoint.

  ### Pagination Links
  Collection responses include pagination links:
  - `first` - URL to the first page of results
  - `last` - URL to the last page of results
  - `prev` - URL to the previous page (null if on first page)
  - `next` - URL to the next page (null if on last page)

  ## OpenAPI Version Differences

  - **OpenAPI 3.1**: Uses `type: ["string", "null"]` for nullable fields
  - **OpenAPI 3.0**: Uses `type: "string"` with `nullable: true`

  ## Usage

      # Build a resource links schema
      AshOaskit.ResponseLinks.build_resource_links_schema(version: "3.1")

      # Build pagination links schema
      AshOaskit.ResponseLinks.build_pagination_links_schema(version: "3.1")

      # Build relationship links schema
      AshOaskit.ResponseLinks.build_relationship_links_schema(version: "3.1")

  ## JSON:API Links Structure

  ```json
  {
    "links": {
      "self": "https://api.example.com/posts/1",
      "related": "https://api.example.com/posts/1/comments"
    }
  }
  ```

  For paginated collections:
  ```json
  {
    "links": {
      "self": "https://api.example.com/posts?page[offset]=20&page[limit]=10",
      "first": "https://api.example.com/posts?page[offset]=0&page[limit]=10",
      "last": "https://api.example.com/posts?page[offset]=90&page[limit]=10",
      "prev": "https://api.example.com/posts?page[offset]=10&page[limit]=10",
      "next": "https://api.example.com/posts?page[offset]=30&page[limit]=10"
    }
  }
  ```
  """

  @doc """
  Builds a complete links schema for resource responses.

  Returns a JSON Schema object describing the links that can appear
  in a single resource response (self link only).

  ## Options

  - `:version` - OpenAPI version ("3.1" or "3.0"). Defaults to "3.1".

  ## Examples

      iex> AshOaskit.ResponseLinks.build_resource_links_schema(version: "3.1")
      %{
        "type" => "object",
        "properties" => %{
          "self" => %{"type" => "string", "format" => "uri"}
        }
      }
  """
  @spec build_resource_links_schema(keyword()) :: map()
  def build_resource_links_schema(opts \\ []) do
    _version = Keyword.get(opts, :version, "3.1")

    %{
      "type" => "object",
      "properties" => %{
        "self" => uri_schema()
      },
      "additionalProperties" => false
    }
  end

  @doc """
  Builds a links schema for collection responses with pagination.

  Returns a JSON Schema object describing the links that can appear
  in a collection response, including pagination links.

  ## Options

  - `:version` - OpenAPI version ("3.1" or "3.0"). Defaults to "3.1".

  ## Examples

      iex> AshOaskit.ResponseLinks.build_collection_links_schema(version: "3.1")
      %{
        "type" => "object",
        "properties" => %{
          "self" => %{"type" => "string", "format" => "uri"},
          "first" => %{"type" => "string", "format" => "uri"},
          "last" => %{"type" => "string", "format" => "uri"},
          "prev" => %{"type" => ["string", "null"], "format" => "uri"},
          "next" => %{"type" => ["string", "null"], "format" => "uri"}
        }
      }
  """
  @spec build_collection_links_schema(keyword()) :: map()
  def build_collection_links_schema(opts \\ []) do
    version = Keyword.get(opts, :version, "3.1")

    %{
      "type" => "object",
      "properties" => %{
        "self" => uri_schema(),
        "first" => uri_schema(),
        "last" => uri_schema(),
        "prev" => nullable_uri_schema(version),
        "next" => nullable_uri_schema(version)
      },
      "additionalProperties" => false
    }
  end

  @doc """
  Builds a links schema specifically for pagination.

  This is a subset of collection links focused only on pagination navigation.

  ## Options

  - `:version` - OpenAPI version ("3.1" or "3.0"). Defaults to "3.1".

  ## Examples

      iex> AshOaskit.ResponseLinks.build_pagination_links_schema(version: "3.0")
      %{
        "type" => "object",
        "properties" => %{
          "first" => %{"type" => "string", "format" => "uri"},
          "last" => %{"type" => "string", "format" => "uri"},
          "prev" => %{"type" => "string", "format" => "uri", "nullable" => true},
          "next" => %{"type" => "string", "format" => "uri", "nullable" => true}
        }
      }
  """
  @spec build_pagination_links_schema(keyword()) :: map()
  def build_pagination_links_schema(opts \\ []) do
    version = Keyword.get(opts, :version, "3.1")

    %{
      "type" => "object",
      "properties" => %{
        "first" => uri_schema(),
        "last" => uri_schema(),
        "prev" => nullable_uri_schema(version),
        "next" => nullable_uri_schema(version)
      },
      "description" => "Pagination navigation links"
    }
  end

  @doc """
  Builds a links schema for relationship objects.

  Relationship links include:
  - `self` - The URL for the relationship itself (for manipulation)
  - `related` - The URL for the related resource(s)

  ## Options

  - `:version` - OpenAPI version ("3.1" or "3.0"). Defaults to "3.1".

  ## Examples

      iex> AshOaskit.ResponseLinks.build_relationship_links_schema(version: "3.1")
      %{
        "type" => "object",
        "properties" => %{
          "self" => %{"type" => "string", "format" => "uri"},
          "related" => %{"type" => "string", "format" => "uri"}
        }
      }
  """
  @spec build_relationship_links_schema(keyword()) :: map()
  def build_relationship_links_schema(opts \\ []) do
    _version = Keyword.get(opts, :version, "3.1")

    %{
      "type" => "object",
      "properties" => %{
        "self" => uri_schema(),
        "related" => uri_schema()
      },
      "description" => "Links for relationship navigation"
    }
  end

  @doc """
  Builds a top-level document links schema.

  This is used for the top-level `links` object in JSON:API responses,
  which can include both resource/collection self links and pagination.

  ## Options

  - `:version` - OpenAPI version ("3.1" or "3.0"). Defaults to "3.1".
  - `:paginated` - Whether to include pagination links. Defaults to false.

  ## Examples

      iex> AshOaskit.ResponseLinks.build_document_links_schema(version: "3.1", paginated: true)
      %{
        "type" => "object",
        "properties" => %{
          "self" => %{"type" => "string", "format" => "uri"},
          "first" => %{"type" => "string", "format" => "uri"},
          "last" => %{"type" => "string", "format" => "uri"},
          "prev" => %{"type" => ["string", "null"], "format" => "uri"},
          "next" => %{"type" => ["string", "null"], "format" => "uri"}
        }
      }
  """
  @spec build_document_links_schema(keyword()) :: map()
  def build_document_links_schema(opts \\ []) do
    version = Keyword.get(opts, :version, "3.1")
    paginated = Keyword.get(opts, :paginated, false)

    base_properties = %{
      "self" => uri_schema()
    }

    properties =
      if paginated do
        Map.merge(base_properties, %{
          "first" => uri_schema(),
          "last" => uri_schema(),
          "prev" => nullable_uri_schema(version),
          "next" => nullable_uri_schema(version)
        })
      else
        base_properties
      end

    %{
      "type" => "object",
      "properties" => properties
    }
  end

  @doc """
  Builds a comprehensive links schema that can contain any valid link type.

  This flexible schema allows for self, related, and pagination links,
  useful when the exact link set isn't known at schema generation time.

  ## Options

  - `:version` - OpenAPI version ("3.1" or "3.0"). Defaults to "3.1".

  ## Examples

      iex> AshOaskit.ResponseLinks.build_flexible_links_schema(version: "3.1")
      %{
        "type" => "object",
        "properties" => %{
          "self" => %{"type" => "string", "format" => "uri"},
          "related" => %{"type" => "string", "format" => "uri"},
          "first" => %{"type" => "string", "format" => "uri"},
          "last" => %{"type" => "string", "format" => "uri"},
          "prev" => %{"type" => ["string", "null"], "format" => "uri"},
          "next" => %{"type" => ["string", "null"], "format" => "uri"}
        },
        "additionalProperties" => %{"type" => "string", "format" => "uri"}
      }
  """
  @spec build_flexible_links_schema(keyword()) :: map()
  def build_flexible_links_schema(opts \\ []) do
    version = Keyword.get(opts, :version, "3.1")

    %{
      "type" => "object",
      "properties" => %{
        "self" => uri_schema(),
        "related" => uri_schema(),
        "first" => uri_schema(),
        "last" => uri_schema(),
        "prev" => nullable_uri_schema(version),
        "next" => nullable_uri_schema(version)
      },
      "additionalProperties" => uri_schema(),
      "description" => "Links object for HATEOAS navigation"
    }
  end

  @doc """
  Adds links schema to an existing response schema.

  Takes a response schema and adds the appropriate links property.

  ## Options

  - `:version` - OpenAPI version ("3.1" or "3.0"). Defaults to "3.1".
  - `:link_type` - Type of links to add (:resource, :collection, :relationship).
    Defaults to :resource.

  ## Examples

      response = %{"type" => "object", "properties" => %{"data" => %{}}}
      AshOaskit.ResponseLinks.add_links_to_response(response, link_type: :collection)
      # => %{
      #      "type" => "object",
      #      "properties" => %{
      #        "data" => %{},
      #        "links" => %{...collection_links_schema...}
      #      }
      #    }
  """
  @spec add_links_to_response(map(), keyword()) :: map()
  def add_links_to_response(response_schema, opts \\ []) do
    link_type = Keyword.get(opts, :link_type, :resource)

    links_schema =
      case link_type do
        :collection -> build_collection_links_schema(opts)
        :relationship -> build_relationship_links_schema(opts)
        :flexible -> build_flexible_links_schema(opts)
        _ -> build_resource_links_schema(opts)
      end

    properties = Map.get(response_schema, "properties", %{})
    updated_properties = Map.put(properties, "links", links_schema)

    Map.put(response_schema, "properties", updated_properties)
  end

  @doc """
  Generates a named links schema reference for use in components.

  Creates a schema definition that can be added to the components/schemas
  section and referenced via $ref.

  ## Options

  - `:version` - OpenAPI version ("3.1" or "3.0"). Defaults to "3.1".
  - `:name_prefix` - Prefix for the schema name. Defaults to "".

  ## Examples

      AshOaskit.ResponseLinks.build_links_component_schemas(version: "3.1")
      # => %{
      #      "Links" => %{...resource_links_schema...},
      #      "PaginationLinks" => %{...pagination_links_schema...},
      #      "RelationshipLinks" => %{...relationship_links_schema...}
      #    }
  """
  @spec build_links_component_schemas(keyword()) :: map()
  def build_links_component_schemas(opts \\ []) do
    prefix = Keyword.get(opts, :name_prefix, "")

    %{
      "#{prefix}Links" => build_resource_links_schema(opts),
      "#{prefix}PaginationLinks" => build_collection_links_schema(opts),
      "#{prefix}RelationshipLinks" => build_relationship_links_schema(opts)
    }
  end

  @doc """
  Checks if a route type should include pagination links.

  ## Examples

      iex> AshOaskit.ResponseLinks.paginated_route?(:index)
      true

      iex> AshOaskit.ResponseLinks.paginated_route?(:get)
      false
  """
  @spec paginated_route?(atom()) :: boolean()
  def paginated_route?(route_type) do
    route_type in [:index, :related]
  end

  @doc """
  Builds a link object schema (for when links themselves have objects as values).

  Per JSON:API spec, a link can be either a string URL or a link object
  with href and optional meta.

  ## Options

  - `:version` - OpenAPI version ("3.1" or "3.0"). Defaults to "3.1".

  ## Examples

      iex> AshOaskit.ResponseLinks.build_link_object_schema(version: "3.1")
      %{
        "oneOf" => [
          %{"type" => "string", "format" => "uri"},
          %{
            "type" => "object",
            "required" => ["href"],
            "properties" => %{
              "href" => %{"type" => "string", "format" => "uri"},
              "meta" => %{"type" => "object", "additionalProperties" => true}
            }
          }
        ]
      }
  """
  @spec build_link_object_schema(keyword()) :: map()
  def build_link_object_schema(opts \\ []) do
    _version = Keyword.get(opts, :version, "3.1")

    %{
      "oneOf" => [
        uri_schema(),
        %{
          "type" => "object",
          "required" => ["href"],
          "properties" => %{
            "href" => uri_schema(),
            "meta" => %{
              "type" => "object",
              "additionalProperties" => true,
              "description" => "Non-standard meta information about the link"
            }
          }
        }
      ],
      "description" =>
        "A link, either as a URL string or a link object with href and optional meta"
    }
  end

  @doc """
  Builds a nullable link object schema.

  Used for links that may be null (like prev/next in pagination).

  ## Options

  - `:version` - OpenAPI version ("3.1" or "3.0"). Defaults to "3.1".

  ## Examples

      AshOaskit.ResponseLinks.build_nullable_link_object_schema(version: "3.1")
      # => %{
      #      "oneOf" => [
      #        %{"type" => "null"},
      #        %{"type" => "string", "format" => "uri"},
      #        %{...link_object...}
      #      ]
      #    }
  """
  @spec build_nullable_link_object_schema(keyword()) :: map()
  def build_nullable_link_object_schema(opts \\ []) do
    version = Keyword.get(opts, :version, "3.1")

    link_object_schema = build_link_object_schema(opts)

    if version == "3.1" do
      Map.update!(link_object_schema, "oneOf", fn schemas ->
        [%{"type" => "null"} | schemas]
      end)
    else
      Map.put(link_object_schema, "nullable", true)
    end
  end

  # Private helper functions

  @spec uri_schema() :: map()
  defp uri_schema do
    %{
      "type" => "string",
      "format" => "uri"
    }
  end

  @spec nullable_uri_schema(String.t()) :: map()
  defp nullable_uri_schema("3.1") do
    %{
      "type" => ["string", "null"],
      "format" => "uri"
    }
  end

  defp nullable_uri_schema(_version) do
    %{
      "type" => "string",
      "format" => "uri",
      "nullable" => true
    }
  end
end
