defmodule AshOaskit.QueryParameters do
  @moduledoc """
  Generates detailed JSON:API query parameter schemas for OpenAPI specs.

  This module provides comprehensive query parameter schemas for JSON:API
  compliant APIs, including pagination, sparse fieldsets, includes,
  filtering, and sorting.

  ## JSON:API Query Parameters

  The JSON:API specification defines several query parameters:

  ### Page Parameter

  Pagination can use either offset-based or keyset/cursor-based strategies:

      # Offset pagination
      GET /posts?page[offset]=0&page[limit]=10

      # Keyset pagination
      GET /posts?page[after]=cursor&page[limit]=10

      # With count
      GET /posts?page[count]=true

  ### Fields Parameter (Sparse Fieldsets)

  Request specific fields per resource type:

      GET /posts?fields[post]=title,body&fields[author]=name

  ### Include Parameter

  Include related resources:

      GET /posts?include=author,comments.author

  ### Filter Parameter

  Filter resources using various operators:

      GET /posts?filter[status]=published&filter[title][contains]=hello

  ### Sort Parameter

  Sort resources by fields:

      GET /posts?sort=-created_at,title

  ## Usage

      # Build page parameter for a resource
      page_param = QueryParameters.build_page_parameter(opts)

      # Build fields parameter with resource types
      fields_param = QueryParameters.build_fields_parameter(["post", "author"])

      # Build include parameter with relationship paths
      include_param = QueryParameters.build_include_parameter([:author, :comments])

      # Get all standard JSON:API parameters
      params = QueryParameters.all_parameters(resource, opts)
  """

  alias AshOaskit.FilterBuilder
  alias AshOaskit.SortBuilder

  @doc """
  Builds the page query parameter schema.

  Supports both offset and keyset pagination strategies.

  ## Parameters

    - `opts` - Options keyword list
      - `:pagination_strategy` - `:offset`, `:keyset`, or `:both` (default)

  ## Returns

    An OpenAPI parameter object for pagination.

  ## Examples

      iex> QueryParameters.build_page_parameter([])
      %{
        name: "page",
        in: :query,
        style: :deepObject,
        schema: %{
          type: :object,
          properties: %{
            "offset" => %{...},
            "limit" => %{...},
            ...
          }
        }
      }

  """
  @spec build_page_parameter(keyword()) :: map()
  def build_page_parameter(opts \\ []) do
    strategy = Keyword.get(opts, :pagination_strategy, :both)

    properties = build_pagination_properties(strategy)

    %{
      name: "page",
      in: :query,
      required: false,
      style: :deepObject,
      explode: true,
      schema: %{
        type: :object,
        properties: properties
      },
      description: build_pagination_description(strategy)
    }
  end

  @doc """
  Builds the fields query parameter schema for sparse fieldsets.

  ## Parameters

    - `resource_types` - List of JSON:API type names
    - `opts` - Options keyword list

  ## Returns

    An OpenAPI parameter object for sparse fieldsets.

  ## Examples

      iex> QueryParameters.build_fields_parameter(["post", "author"])
      %{
        name: "fields",
        in: :query,
        style: :deepObject,
        schema: %{
          type: :object,
          properties: %{
            "post" => %{type: :string},
            "author" => %{type: :string}
          }
        }
      }

  """
  @spec build_fields_parameter([String.t()], keyword()) :: map()
  def build_fields_parameter(resource_types, _opts \\ []) do
    properties =
      resource_types
      |> Enum.map(fn type ->
        {type,
         %{
           type: :string,
           description: "Comma-separated list of #{type} fields to include"
         }}
      end)
      |> Enum.into(%{})

    %{
      name: "fields",
      in: :query,
      required: false,
      style: :deepObject,
      explode: true,
      schema: %{
        type: :object,
        properties: properties,
        additionalProperties: %{
          type: :string,
          description: "Comma-separated list of fields for any resource type"
        }
      },
      description:
        "Sparse fieldsets - specify which fields to include for each resource type. " <>
          "Format: fields[type]=field1,field2"
    }
  end

  @doc """
  Builds the include query parameter schema.

  ## Parameters

    - `available_includes` - List of includable relationship paths
    - `opts` - Options keyword list

  ## Returns

    An OpenAPI parameter object for relationship includes.

  ## Examples

      iex> QueryParameters.build_include_parameter([:author, :comments])
      %{
        name: "include",
        in: :query,
        schema: %{
          type: :string,
          description: "..."
        }
      }

  """
  @spec build_include_parameter([atom() | String.t()], keyword()) :: map()
  def build_include_parameter(available_includes, _opts \\ []) do
    include_list = Enum.map_join(available_includes, ", ", &to_string/1)

    description =
      if available_includes != [] do
        "Comma-separated list of relationship paths to include. " <>
          "Available: #{include_list}. " <>
          "Nested relationships use dot notation (e.g., 'comments.author')."
      else
        "Comma-separated list of relationship paths to include. " <>
          "Nested relationships use dot notation (e.g., 'comments.author')."
      end

    %{
      name: "include",
      in: :query,
      required: false,
      schema: %{
        type: :string
      },
      description: description
    }
  end

  @doc """
  Builds all standard JSON:API query parameters for a resource.

  Combines filter, sort, page, include, and fields parameters.

  ## Parameters

    - `resource` - The Ash resource module
    - `opts` - Options keyword list
      - `:version` - OpenAPI version ("3.0" or "3.1")
      - `:pagination_strategy` - Pagination type
      - `:include_paths` - Available include paths

  ## Returns

    List of OpenAPI parameter objects.

  ## Examples

      QueryParameters.all_parameters(MyApp.Post, version: "3.1")
      #=> [
      #=>   %{name: "filter", ...},
      #=>   %{name: "sort", ...},
      #=>   %{name: "page", ...},
      #=>   %{name: "include", ...},
      #=>   %{name: "fields", ...}
      #=> ]

  """
  @spec all_parameters(module(), keyword()) :: [map()]
  def all_parameters(resource, opts \\ []) do
    params = []

    # Filter parameter
    filter_param = FilterBuilder.build_filter_parameter(resource, opts)
    params = if filter_param, do: [filter_param | params], else: params

    # Sort parameter
    sort_param = SortBuilder.build_sort_parameter(resource, opts)
    params = if sort_param, do: [sort_param | params], else: params

    # Page parameter
    page_param = build_page_parameter(opts)
    params = [page_param | params]

    # Include parameter
    include_paths = Keyword.get(opts, :include_paths, get_includable_relationships(resource))
    include_param = build_include_parameter(include_paths, opts)
    params = [include_param | params]

    # Fields parameter
    resource_types = get_related_resource_types(resource)
    fields_param = build_fields_parameter(resource_types, opts)
    params = [fields_param | params]

    Enum.reverse(params)
  end

  @doc """
  Builds a read-only parameters list (no filter/sort).

  Useful for simple GET operations that don't support filtering.

  ## Parameters

    - `resource` - The Ash resource module
    - `opts` - Options keyword list

  ## Returns

    List of OpenAPI parameter objects (page, include, fields only).

  """
  @spec basic_parameters(module(), keyword()) :: [map()]
  def basic_parameters(resource, opts \\ []) do
    [
      build_page_parameter(opts),
      build_include_parameter(get_includable_relationships(resource), opts),
      build_fields_parameter(get_related_resource_types(resource), opts)
    ]
  end

  @doc """
  Builds parameters for index/list operations.

  Includes all standard parameters plus optional count parameter.

  ## Parameters

    - `resource` - The Ash resource module
    - `opts` - Options keyword list

  ## Returns

    List of OpenAPI parameter objects.

  """
  @spec index_parameters(module(), keyword()) :: [map()]
  def index_parameters(resource, opts \\ []) do
    all_parameters(resource, opts)
  end

  @doc """
  Builds parameters for get/show operations.

  Typically only needs include and fields parameters.

  ## Parameters

    - `resource` - The Ash resource module
    - `opts` - Options keyword list

  ## Returns

    List of OpenAPI parameter objects.

  """
  @spec show_parameters(module(), keyword()) :: [map()]
  def show_parameters(resource, opts \\ []) do
    [
      build_include_parameter(get_includable_relationships(resource), opts),
      build_fields_parameter(get_related_resource_types(resource), opts)
    ]
  end

  defp build_pagination_properties(:offset) do
    %{
      "offset" => %{
        type: :integer,
        minimum: 0,
        description: "Number of records to skip"
      },
      "limit" => %{
        type: :integer,
        minimum: 1,
        maximum: 1000,
        description: "Maximum number of records to return"
      },
      "count" => %{
        type: :boolean,
        description: "Include total count in response"
      }
    }
  end

  defp build_pagination_properties(:keyset) do
    %{
      "after" => %{
        type: :string,
        description: "Cursor for fetching records after this position"
      },
      "before" => %{
        type: :string,
        description: "Cursor for fetching records before this position"
      },
      "limit" => %{
        type: :integer,
        minimum: 1,
        maximum: 1000,
        description: "Maximum number of records to return"
      },
      "count" => %{
        type: :boolean,
        description: "Include total count in response"
      }
    }
  end

  defp build_pagination_properties(:both) do
    %{
      "offset" => %{
        type: :integer,
        minimum: 0,
        description: "Number of records to skip (offset pagination)"
      },
      "limit" => %{
        type: :integer,
        minimum: 1,
        maximum: 1000,
        description: "Maximum number of records to return"
      },
      "after" => %{
        type: :string,
        description: "Cursor for fetching records after this position (keyset pagination)"
      },
      "before" => %{
        type: :string,
        description: "Cursor for fetching records before this position (keyset pagination)"
      },
      "count" => %{
        type: :boolean,
        description: "Include total count in response"
      }
    }
  end

  defp build_pagination_properties(_), do: build_pagination_properties(:both)

  defp build_pagination_description(:offset) do
    "Offset-based pagination. Use 'offset' and 'limit' to paginate results."
  end

  defp build_pagination_description(:keyset) do
    "Keyset/cursor-based pagination. Use 'after'/'before' with 'limit' to paginate."
  end

  defp build_pagination_description(:both) do
    "Pagination parameters. Supports both offset (offset+limit) and keyset (after/before+limit) strategies."
  end

  defp build_pagination_description(_), do: build_pagination_description(:both)

  defp get_includable_relationships(resource) do
    resource
    |> Ash.Resource.Info.relationships()
    |> Enum.reject(fn rel -> Map.get(rel, :private?, false) end)
    |> Enum.map(& &1.name)
  end

  defp get_related_resource_types(resource) do
    primary_type = resource_type(resource)

    related_types =
      resource
      |> Ash.Resource.Info.relationships()
      |> Enum.reject(fn rel -> Map.get(rel, :private?, false) end)
      |> Enum.map(fn rel -> resource_type(rel.destination) end)
      |> Enum.uniq()

    Enum.uniq([primary_type | related_types])
  end

  defp resource_type(resource) do
    case AshJsonApi.Resource.Info.type(resource) do
      nil -> default_type(resource)
      type -> type
    end
  end

  defp default_type(resource) do
    resource
    |> Module.split()
    |> List.last()
    |> Macro.underscore()
  end
end
