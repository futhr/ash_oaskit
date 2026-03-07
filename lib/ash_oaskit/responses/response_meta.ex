defmodule AshOaskit.ResponseMeta do
  @moduledoc """
  Generates JSON:API response meta schemas for OpenAPI specifications.

  This module provides functions to build meta objects for JSON:API responses,
  including pagination metadata, record counts, and the JSON:API version object.
  Meta objects provide non-standard information that complements the primary data.

  ## Meta Object Types

  ### Pagination Meta
  Pagination responses typically include meta information about:
  - `count` or `total` - Total number of records in the collection
  - `page` - Current pagination state (offset, limit, etc.)

  ### Resource Meta
  Individual resources may include custom meta information defined
  by the application.

  ### JSON:API Version Object
  Top-level document meta can include the JSON:API version being used:
  ```json
  {
    "jsonapi": {
      "version": "1.0"
    }
  }
  ```

  ## OpenAPI Version Differences

  - **OpenAPI 3.1**: Uses native JSON Schema features
  - **OpenAPI 3.0**: May require compatibility adjustments

  ## Usage

      # Build pagination meta schema
      AshOaskit.ResponseMeta.build_pagination_meta_schema(version: "3.1")

      # Build JSONAPI version object schema
      AshOaskit.ResponseMeta.build_jsonapi_object_schema()

      # Add meta to response schema
      AshOaskit.ResponseMeta.add_meta_to_response(response, meta_type: :pagination)

  ## JSON:API Meta Structure

  ```json
  {
    "meta": {
      "count": 100,
      "page": {
        "offset": 20,
        "limit": 10,
        "total": 100
      }
    },
    "jsonapi": {
      "version": "1.0"
    }
  }
  ```
  """

  import AshOaskit.Schemas.Nullable, only: [make_nullable: 2]

  @doc """
  Builds a meta schema for paginated collection responses.

  Returns a JSON Schema object describing the meta information
  that can appear in paginated responses.

  ## Options

  - `:version` - OpenAPI version ("3.1" or "3.0"). Defaults to "3.1".
  - `:pagination_strategy` - One of `:offset`, `:keyset`, or `:both`. Defaults to `:both`.

  ## Examples

      iex> AshOaskit.ResponseMeta.build_pagination_meta_schema(version: "3.1")
      %{
        type: :object,
        properties: %{
          count: %{type: :integer},
          page: %{...}
        }
      }
  """
  @spec build_pagination_meta_schema(keyword()) :: map()
  def build_pagination_meta_schema(opts \\ []) do
    version = Keyword.get(opts, :version, "3.1")
    strategy = Keyword.get(opts, :pagination_strategy, :both)

    page_schema = build_page_info_schema(strategy, version)

    %{
      type: :object,
      properties: %{
        count: %{
          type: :integer,
          minimum: 0,
          description: "Total count of records matching the query"
        },
        page: page_schema
      },
      description: "Pagination and count metadata"
    }
  end

  @doc """
  Builds a page info schema based on pagination strategy.

  ## Options

  - `:strategy` - One of `:offset`, `:keyset`, or `:both`. Defaults to `:both`.
  - `:version` - OpenAPI version ("3.1" or "3.0"). Defaults to "3.1".

  ## Examples

      iex> AshOaskit.ResponseMeta.build_page_info_schema(:offset)
      %{
        type: :object,
        properties: %{
          offset: %{type: :integer},
          limit: %{type: :integer},
          total: %{type: :integer}
        }
      }
  """
  @spec build_page_info_schema(atom(), String.t()) :: map()
  def build_page_info_schema(strategy \\ :both, version \\ "3.1")

  def build_page_info_schema(:offset, _) do
    %{
      type: :object,
      properties: %{
        offset: %{
          type: :integer,
          minimum: 0,
          description: "Current offset position"
        },
        limit: %{
          type: :integer,
          minimum: 1,
          description: "Number of records per page"
        },
        total: %{
          type: :integer,
          minimum: 0,
          description: "Total number of records"
        },
        has_more: %{
          type: :boolean,
          description: "Whether more records exist beyond current page"
        }
      },
      description: "Offset-based pagination info"
    }
  end

  def build_page_info_schema(:keyset, version) do
    %{
      type: :object,
      properties: %{
        after: make_nullable(%{type: :string, description: "Cursor for next page"}, version),
        before: make_nullable(%{type: :string, description: "Cursor for previous page"}, version),
        limit: %{
          type: :integer,
          minimum: 1,
          description: "Number of records per page"
        },
        has_next_page: %{
          type: :boolean,
          description: "Whether a next page exists"
        },
        has_previous_page: %{
          type: :boolean,
          description: "Whether a previous page exists"
        }
      },
      description: "Keyset/cursor-based pagination info"
    }
  end

  def build_page_info_schema(:both, version) do
    offset_props = build_page_info_schema(:offset, version)[:properties]
    keyset_props = build_page_info_schema(:keyset, version)[:properties]

    %{
      type: :object,
      properties: Map.merge(offset_props, keyset_props),
      description: "Pagination info (supports both offset and keyset strategies)"
    }
  end

  def build_page_info_schema(_, version) do
    build_page_info_schema(:both, version)
  end

  @doc """
  Builds a generic resource meta schema.

  Resources can include application-specific meta information.
  This schema allows any additional properties.

  ## Options

  - `:version` - OpenAPI version ("3.1" or "3.0"). Defaults to "3.1".

  ## Examples

      iex> AshOaskit.ResponseMeta.build_resource_meta_schema()
      %{
        type: :object,
        additionalProperties: true
      }
  """
  @spec build_resource_meta_schema(keyword()) :: map()
  def build_resource_meta_schema(_ \\ []) do
    %{
      type: :object,
      additionalProperties: true,
      description: "Non-standard meta information about the resource"
    }
  end

  @doc """
  Builds the JSON:API version object schema.

  The jsonapi object describes the implementation's version of the JSON:API spec.

  ## Options

  - `:version` - OpenAPI version ("3.1" or "3.0"). Defaults to "3.1".
  - `:supported_versions` - List of supported JSON:API versions. Defaults to ["1.0", "1.1"].

  ## Examples

      iex> AshOaskit.ResponseMeta.build_jsonapi_object_schema()
      %{
        type: :object,
        properties: %{
          version: %{type: :string, enum: ["1.0", "1.1"]}
        }
      }
  """
  @spec build_jsonapi_object_schema(keyword()) :: map()
  def build_jsonapi_object_schema(opts \\ []) do
    supported_versions = Keyword.get(opts, :supported_versions, ["1.0", "1.1"])

    %{
      type: :object,
      properties: %{
        version: %{
          type: :string,
          enum: supported_versions,
          description: "JSON:API specification version"
        },
        ext: %{
          type: :array,
          items: %{type: :string, format: :uri},
          description: "Array of URIs for applied extensions"
        },
        profile: %{
          type: :array,
          items: %{type: :string, format: :uri},
          description: "Array of URIs for applied profiles"
        }
      },
      description: "JSON:API implementation information"
    }
  end

  @doc """
  Builds a document-level meta schema.

  Top-level documents can include meta objects with application-specific
  information. This is typically used for pagination counts in collections.

  ## Options

  - `:version` - OpenAPI version ("3.1" or "3.0"). Defaults to "3.1".
  - `:include_count` - Whether to include count property. Defaults to true.
  - `:include_page` - Whether to include page info. Defaults to false.

  ## Examples

      iex> AshOaskit.ResponseMeta.build_document_meta_schema(include_count: true)
      %{
        type: :object,
        properties: %{
          count: %{type: :integer}
        }
      }
  """
  @spec build_document_meta_schema(keyword()) :: map()
  def build_document_meta_schema(opts \\ []) do
    version = Keyword.get(opts, :version, "3.1")
    include_count = Keyword.get(opts, :include_count, true)
    include_page = Keyword.get(opts, :include_page, false)
    pagination_strategy = Keyword.get(opts, :pagination_strategy, :both)

    properties = %{}

    properties =
      if include_count do
        Map.put(properties, :count, %{
          type: :integer,
          minimum: 0,
          description: "Total count of records"
        })
      else
        properties
      end

    properties =
      if include_page do
        page_schema = build_page_info_schema(pagination_strategy, version)
        Map.put(properties, :page, page_schema)
      else
        properties
      end

    base = %{
      type: :object,
      additionalProperties: true,
      description: "Document-level meta information"
    }

    if map_size(properties) > 0 do
      Map.put(base, :properties, properties)
    else
      base
    end
  end

  @doc """
  Builds a response meta schema for different response types.

  ## Options

  - `:version` - OpenAPI version ("3.1" or "3.0"). Defaults to "3.1".
  - `:response_type` - One of `:single`, `:collection`, or `:relationship`. Defaults to `:single`.

  ## Examples

      AshOaskit.ResponseMeta.build_response_meta_schema(response_type: :collection)
      # => %{...pagination_meta_schema...}

      AshOaskit.ResponseMeta.build_response_meta_schema(response_type: :single)
      # => %{...resource_meta_schema...}
  """
  @spec build_response_meta_schema(keyword()) :: map()
  def build_response_meta_schema(opts \\ []) do
    response_type = Keyword.get(opts, :response_type, :single)

    case response_type do
      :collection -> build_pagination_meta_schema(opts)
      :relationship -> build_resource_meta_schema(opts)
      _ -> build_resource_meta_schema(opts)
    end
  end

  @doc """
  Adds meta schema to an existing response schema.

  Takes a response schema and adds the appropriate meta property.

  ## Options

  - `:version` - OpenAPI version ("3.1" or "3.0"). Defaults to "3.1".
  - `:meta_type` - Type of meta to add (:resource, :pagination, :document).
    Defaults to :resource.

  ## Examples

      response = %{type: :object, properties: %{data: %{}}}
      AshOaskit.ResponseMeta.add_meta_to_response(response, meta_type: :pagination)
      # => %{
      #      type: :object,
      #      properties: %{
      #        data: %{},
      #        meta: %{...pagination_meta_schema...}
      #      }
      #    }
  """
  @spec add_meta_to_response(map(), keyword()) :: map()
  def add_meta_to_response(response_schema, opts \\ []) do
    meta_type = Keyword.get(opts, :meta_type, :resource)

    meta_schema =
      case meta_type do
        :pagination -> build_pagination_meta_schema(opts)
        :document -> build_document_meta_schema(opts)
        _ -> build_resource_meta_schema(opts)
      end

    properties = Map.get(response_schema, :properties, %{})
    updated_properties = Map.put(properties, :meta, meta_schema)

    Map.put(response_schema, :properties, updated_properties)
  end

  @doc """
  Adds the jsonapi version object to a response schema.

  ## Options

  - `:version` - OpenAPI version ("3.1" or "3.0"). Defaults to "3.1".
  - `:supported_versions` - List of supported JSON:API versions. Defaults to ["1.0", "1.1"].

  ## Examples

      response = %{type: :object, properties: %{data: %{}}}
      AshOaskit.ResponseMeta.add_jsonapi_object_to_response(response)
      # => %{
      #      type: :object,
      #      properties: %{
      #        data: %{},
      #        jsonapi: %{...jsonapi_object_schema...}
      #      }
      #    }
  """
  @spec add_jsonapi_object_to_response(map(), keyword()) :: map()
  def add_jsonapi_object_to_response(response_schema, opts \\ []) do
    jsonapi_schema = build_jsonapi_object_schema(opts)

    properties = Map.get(response_schema, :properties, %{})
    updated_properties = Map.put(properties, :jsonapi, jsonapi_schema)

    Map.put(response_schema, :properties, updated_properties)
  end

  @doc """
  Generates named meta schema references for use in components.

  Creates schema definitions that can be added to the components/schemas
  section and referenced via $ref.

  ## Options

  - `:version` - OpenAPI version ("3.1" or "3.0"). Defaults to "3.1".
  - `:name_prefix` - Prefix for the schema name. Defaults to "".

  ## Examples

      AshOaskit.ResponseMeta.build_meta_component_schemas(version: "3.1")
      # => %{
      #      "Meta" => %{...resource_meta_schema...},
      #      "PaginationMeta" => %{...pagination_meta_schema...},
      #      "JsonApi" => %{...jsonapi_object_schema...}
      #    }
  """
  @spec build_meta_component_schemas(keyword()) :: map()
  def build_meta_component_schemas(opts \\ []) do
    prefix = Keyword.get(opts, :name_prefix, "")

    %{
      "#{prefix}Meta" => build_resource_meta_schema(opts),
      "#{prefix}PaginationMeta" => build_pagination_meta_schema(opts),
      "#{prefix}DocumentMeta" =>
        build_document_meta_schema(Keyword.put(opts, :include_page, true)),
      "#{prefix}JsonApi" => build_jsonapi_object_schema(opts),
      "#{prefix}PageInfo" => build_page_info_schema(:both, Keyword.get(opts, :version, "3.1"))
    }
  end

  @doc """
  Checks if a route type should include pagination meta.

  ## Examples

      iex> AshOaskit.ResponseMeta.paginated_route?(:index)
      true

      iex> AshOaskit.ResponseMeta.paginated_route?(:get)
      false
  """
  @spec paginated_route?(atom()) :: boolean()
  def paginated_route?(route_type) do
    route_type in [:index, :related]
  end

  @doc """
  Builds a complete top-level document meta section.

  This combines all top-level meta information: count, page info,
  and application-specific meta.

  ## Options

  - `:version` - OpenAPI version ("3.1" or "3.0"). Defaults to "3.1".
  - `:include_count` - Whether to include count. Defaults to true.
  - `:include_page` - Whether to include page info. Defaults to true.
  - `:pagination_strategy` - Pagination strategy. Defaults to :both.

  ## Examples

      iex> AshOaskit.ResponseMeta.build_complete_meta_schema(
      ...>   include_count: true,
      ...>   include_page: true
      ...> )
      %{
        type: :object,
        properties: %{
          count: %{...},
          page: %{...}
        },
        additionalProperties: true
      }
  """
  @spec build_complete_meta_schema(keyword()) :: map()
  def build_complete_meta_schema(opts \\ []) do
    version = Keyword.get(opts, :version, "3.1")
    include_count = Keyword.get(opts, :include_count, true)
    include_page = Keyword.get(opts, :include_page, true)
    strategy = Keyword.get(opts, :pagination_strategy, :both)

    properties = %{}

    properties =
      if include_count do
        Map.put(properties, :count, %{
          type: :integer,
          minimum: 0,
          description: "Total count of records matching the query"
        })
      else
        properties
      end

    properties =
      if include_page do
        Map.put(properties, :page, build_page_info_schema(strategy, version))
      else
        properties
      end

    %{
      type: :object,
      properties: properties,
      additionalProperties: true,
      description: "Response meta information including pagination details"
    }
  end
end
