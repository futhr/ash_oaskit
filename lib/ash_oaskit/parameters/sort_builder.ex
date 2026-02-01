defmodule AshOaskit.SortBuilder do
  @moduledoc """
  Builds OpenAPI sort parameter schemas for Ash resources.

  This module generates proper sort parameter schemas that reflect the actual
  sortable fields available on an Ash resource, including attributes, calculations,
  and aggregates that support sorting.

  ## Sort Parameter Format

  The JSON:API specification allows sorting via a comma-separated list of field names.
  Fields can be prefixed with `-` for descending order or `+` (optional) for ascending.

  ## Example

      GET /posts?sort=-created_at,title

  This sorts by `created_at` descending, then `title` ascending.

  ## Generated Schema

  The sort parameter schema includes:
  - An enum of all valid sort field values
  - Both ascending and descending variants for each field
  - A description listing available fields

  ## Usage

      # Build sort parameter for a resource
      param = SortBuilder.build_sort_parameter(MyApp.Post)

      # With options
      param = SortBuilder.build_sort_parameter(MyApp.Post, version: "3.0")

  ## Configuration

  Sort derivation can be disabled via the `derive_sort?` configuration on the
  AshJsonApi resource DSL. When disabled, this module returns `nil`.
  """

  @doc """
  Builds the sort query parameter schema for the given resource.

  Returns an OpenAPI parameter object with a schema that enumerates all
  valid sort field values (both ascending and descending variants).

  ## Parameters

    - `resource` - The Ash resource module
    - `opts` - Options keyword list
      - `:version` - OpenAPI version ("3.0" or "3.1", defaults to "3.1")

  ## Returns

    - A map representing the OpenAPI parameter object, or
    - `nil` if sorting is disabled for the resource

  ## Examples

      iex> SortBuilder.build_sort_parameter(MyApp.Post)
      %{
        name: "sort",
        in: :query,
        required: false,
        schema: %{
          type: :string,
          description: "..."
        },
        description: "Sort criteria for Post records"
      }

  """
  @spec build_sort_parameter(module(), keyword()) :: map() | nil
  def build_sort_parameter(resource, opts \\ []) do
    if derive_sort?(resource) do
      sortable_fields = get_sortable_fields(resource)

      %{
        name: "sort",
        in: :query,
        required: false,
        schema: build_sort_schema(sortable_fields, opts),
        description: "Sort criteria for #{resource_name(resource)} records"
      }
    else
      nil
    end
  end

  @doc """
  Gets all sortable fields for the given resource.

  Returns a list of field names (as atoms) that can be used in sort parameters.
  This includes:
  - Public attributes
  - Public calculations marked as sortable
  - Public aggregates

  ## Parameters

    - `resource` - The Ash resource module

  ## Returns

    A list of atom field names.

  ## Examples

      iex> SortBuilder.get_sortable_fields(MyApp.Post)
      [:title, :created_at, :view_count, :comment_count]

  """
  @spec get_sortable_fields(module()) :: [atom()]
  def get_sortable_fields(resource) do
    attributes = get_sortable_attributes(resource)
    calculations = get_sortable_calculations(resource)
    aggregates = get_sortable_aggregates(resource)

    attributes ++ calculations ++ aggregates
  end

  @doc """
  Builds the sort schema object.

  Creates an OpenAPI schema that describes valid sort parameter values.
  The schema uses a string type with a description of available fields
  and their sort directions.

  ## Parameters

    - `sortable_fields` - List of atom field names
    - `opts` - Options keyword list (version, etc.)

  ## Returns

    A map representing the OpenAPI schema object.

  ## Examples

      iex> SortBuilder.build_sort_schema([:title, :created_at], [])
      %{
        type: :string,
        description: "Comma-separated list of fields. Prefix with '-' for descending."
      }

  """
  @spec build_sort_schema([atom()], keyword()) :: map()
  def build_sort_schema(sortable_fields, _opts) do
    field_list = Enum.map_join(sortable_fields, ", ", &to_string/1)

    %{
      type: :string,
      description:
        "Comma-separated list of fields to sort by. " <>
          "Prefix with '-' for descending order, '+' or no prefix for ascending. " <>
          "Available fields: #{field_list}"
    }
  end

  @doc """
  Builds an enum-based sort schema with explicit field values.

  This creates a more restrictive schema that explicitly enumerates all
  valid sort values, including both ascending and descending variants.

  ## Parameters

    - `sortable_fields` - List of atom field names
    - `opts` - Options keyword list

  ## Returns

    A map with an enum array of valid sort values.

  ## Examples

      iex> SortBuilder.build_sort_enum_schema([:title, :created_at], [])
      %{
        type: :string,
        enum: ["title", "-title", "created_at", "-created_at"]
      }

  """
  @spec build_sort_enum_schema([atom()], keyword()) :: map()
  def build_sort_enum_schema(sortable_fields, _opts) do
    enum_values =
      Enum.flat_map(sortable_fields, fn field ->
        name = to_string(field)
        [name, "-#{name}"]
      end)

    %{
      type: :string,
      enum: enum_values
    }
  end

  @doc """
  Builds an array-based sort schema for multiple sort fields.

  This creates a schema for accepting an array of sort values, useful
  when the API accepts sort as repeated query parameters rather than
  a comma-separated string.

  ## Parameters

    - `sortable_fields` - List of atom field names
    - `opts` - Options keyword list

  ## Returns

    A map with array type and items schema.

  ## Examples

      iex> SortBuilder.build_sort_array_schema([:title], [])
      %{
        type: :array,
        items: %{
          type: :string,
          enum: ["title", "-title"]
        }
      }

  """
  @spec build_sort_array_schema([atom()], keyword()) :: map()
  def build_sort_array_schema(sortable_fields, opts) do
    %{
      type: :array,
      items: build_sort_enum_schema(sortable_fields, opts)
    }
  end

  # Private functions

  defp derive_sort?(resource) do
    case AshJsonApi.Resource.Info.derive_sort?(resource) do
      nil -> true
      value -> value
    end
  end

  defp get_sortable_attributes(resource) do
    resource
    |> Ash.Resource.Info.attributes()
    |> Enum.reject(fn attr ->
      attr.name in [:id, :inserted_at, :updated_at] or Map.get(attr, :private?, false)
    end)
    |> Enum.map(& &1.name)
  end

  defp get_sortable_calculations(resource) do
    resource
    |> Ash.Resource.Info.calculations()
    |> Enum.reject(fn calc -> Map.get(calc, :private?, false) end)
    |> Enum.filter(&sortable_calculation?/1)
    |> Enum.map(& &1.name)
  end

  defp sortable_calculation?(calculation) do
    sortable = Map.get(calculation, :sortable?, true)
    args = calculation.arguments || []
    no_required_args = args == [] or Enum.all?(args, &argument_optional?/1)
    sortable and no_required_args
  end

  defp argument_optional?(arg) do
    Map.has_key?(arg, :default) or Map.get(arg, :allow_nil?, false)
  end

  defp get_sortable_aggregates(resource) do
    resource
    |> Ash.Resource.Info.aggregates()
    |> Enum.reject(fn agg -> Map.get(agg, :private?, false) end)
    |> Enum.map(& &1.name)
  end

  defp resource_name(resource) do
    resource
    |> Module.split()
    |> List.last()
  end
end
