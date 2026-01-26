defmodule AshOaskit.FilterBuilder do
  @moduledoc """
  Builds OpenAPI filter schemas for Ash resources.

  This module generates proper filter parameter schemas that describe the
  available filter operators for each resource attribute, matching the
  functionality provided by AshJsonApi.OpenApi.

  ## Overview

  JSON:API filtering uses the `filter` query parameter with a nested object
  structure. For example:

      GET /posts?filter[status]=published&filter[title][contains]=hello

  This module generates OpenAPI schemas that describe this structure.

  ## Filter Schema Structure

  The generated filter schema is a `deepObject` style query parameter:

      %{
        "name" => "filter",
        "in" => "query",
        "style" => "deepObject",
        "explode" => true,
        "schema" => %{
          "type" => "object",
          "properties" => %{
            "title" => %{...},
            "status" => %{...},
            "and" => %{...},
            "or" => %{...},
            "not" => %{...}
          }
        }
      }

  ## Supported Filter Operators

  ### Equality Operators
  - Direct value: `filter[field]=value`
  - `eq`: `filter[field][eq]=value`
  - `ne`: `filter[field][ne]=value`

  ### Comparison Operators
  - `gt`: Greater than
  - `gte`: Greater than or equal
  - `lt`: Less than
  - `lte`: Less than or equal

  ### Set Operators
  - `in`: `filter[field][in][]=value1&filter[field][in][]=value2`
  - `not_in`: Negation of `in`

  ### String Operators
  - `contains`: Substring match
  - `starts_with`: Prefix match
  - `ends_with`: Suffix match
  - `icontains`: Case-insensitive contains
  - `istarts_with`: Case-insensitive starts_with
  - `iends_with`: Case-insensitive ends_with

  ### Null Check
  - `is_nil`: `filter[field][is_nil]=true`

  ### Boolean Operators
  - `and`: Array of filter conditions (all must match)
  - `or`: Array of filter conditions (any must match)
  - `not`: Single filter condition (must not match)

  ## Integration with Generators

  This module is used by the V30 and V31 generators to create filter
  parameter schemas:

      filter_param = FilterBuilder.build_filter_parameter(resource)

  ## Configuration

  Filtering can be disabled per-resource via AshJsonApi DSL:

      json_api do
        derive_filter? false
      end

  This module respects that configuration when available.
  """

  @typedoc """
  Filter operator specification.

  Contains the JSON Schema for a single filter operator.
  """
  @type operator_schema :: map()

  @doc """
  Builds the complete filter query parameter for a resource.

  ## Parameters

  - `resource` - The Ash resource module
  - `opts` - Options (currently unused, reserved for future use)

  ## Returns

  A map representing the OpenAPI parameter object for the `filter` query
  parameter, or `nil` if filtering is disabled for the resource.

  ## Examples

      iex> param = AshOaskit.FilterBuilder.build_filter_parameter(MyApp.Post)
      ...> param["name"]
      "filter"
      iex> param["in"]
      "query"
  """
  @spec build_filter_parameter(module(), keyword()) :: map() | nil
  def build_filter_parameter(resource, opts \\ []) do
    if derive_filter?(resource) do
      %{
        "name" => "filter",
        "in" => "query",
        "required" => false,
        "style" => "deepObject",
        "explode" => true,
        "schema" => build_filter_schema(resource, opts),
        "description" => "Filter criteria for #{resource_name(resource)} records"
      }
    else
      nil
    end
  end

  @doc """
  Builds the filter schema for a resource.

  This returns just the schema object without the parameter wrapper,
  useful for testing or custom parameter construction.

  ## Parameters

  - `resource` - The Ash resource module
  - `opts` - Options (currently unused)

  ## Returns

  A map representing the JSON Schema for the filter object.
  """
  @spec build_filter_schema(module(), keyword()) :: map()
  def build_filter_schema(resource, _opts \\ []) do
    attribute_filters = build_attribute_filters(resource)
    boolean_filters = build_boolean_filters()

    properties = Map.merge(attribute_filters, boolean_filters)

    %{
      "type" => "object",
      "properties" => properties,
      "additionalProperties" => false
    }
  end

  @doc """
  Builds filter properties for all filterable attributes.

  ## Parameters

  - `resource` - The Ash resource module

  ## Returns

  A map of attribute name to filter schema.
  """
  @spec build_attribute_filters(module()) :: map()
  def build_attribute_filters(resource) do
    resource
    |> get_filterable_attributes()
    |> Enum.map(fn attr ->
      {to_string(attr.name), build_attribute_filter_schema(attr)}
    end)
    |> Enum.into(%{})
  end

  @doc """
  Builds the filter schema for a single attribute.

  The schema allows either a direct value or an object with operators.

  ## Parameters

  - `attr` - The attribute struct

  ## Returns

  A JSON Schema for the attribute's filter.
  """
  @spec build_attribute_filter_schema(map()) :: map()
  def build_attribute_filter_schema(attr) do
    base_type_schema = attribute_type_schema(attr.type)
    operators = operators_for_type(attr.type)

    operator_properties =
      operators
      |> Enum.map(fn op -> {to_string(op), operator_schema(op, base_type_schema)} end)
      |> Enum.into(%{})

    # Allow either direct value or operator object
    %{
      "oneOf" => [
        base_type_schema,
        %{
          "type" => "object",
          "properties" => operator_properties
        }
      ]
    }
  end

  # Gets filterable attributes from a resource
  @spec get_filterable_attributes(module()) :: [map()]
  defp get_filterable_attributes(resource) do
    resource
    |> Ash.Resource.Info.attributes()
    |> Enum.reject(fn attr ->
      Map.get(attr, :private?, false) or
        Map.get(attr, :filterable?, true) == false
    end)
  end

  # Map of types to their JSON Schema representation
  @type_to_schema %{
    string: %{"type" => "string"},
    ci_string: %{"type" => "string"},
    integer: %{"type" => "integer"},
    float: %{"type" => "number"},
    decimal: %{"type" => "number"},
    boolean: %{"type" => "boolean"},
    date: %{"type" => "string", "format" => "date"},
    time: %{"type" => "string", "format" => "time"},
    datetime: %{"type" => "string", "format" => "date-time"},
    utc_datetime: %{"type" => "string", "format" => "date-time"},
    utc_datetime_usec: %{"type" => "string", "format" => "date-time"},
    naive_datetime: %{"type" => "string", "format" => "date-time"},
    uuid: %{"type" => "string", "format" => "uuid"},
    atom: %{"type" => "string"}
  }

  # Map of Ash.Type modules to atom equivalents
  @ash_type_to_atom %{
    Ash.Type.String => :string,
    Ash.Type.CiString => :ci_string,
    Ash.Type.Integer => :integer,
    Ash.Type.Float => :float,
    Ash.Type.Decimal => :decimal,
    Ash.Type.Boolean => :boolean,
    Ash.Type.Date => :date,
    Ash.Type.Time => :time,
    Ash.Type.DateTime => :datetime,
    Ash.Type.UtcDatetime => :utc_datetime,
    Ash.Type.UtcDatetimeUsec => :utc_datetime_usec,
    Ash.Type.NaiveDatetime => :naive_datetime,
    Ash.Type.UUID => :uuid,
    Ash.Type.Atom => :atom
  }

  # Maps Ash type to base JSON Schema for filter values
  @spec attribute_type_schema(atom() | tuple()) :: map()
  defp attribute_type_schema({:array, inner}) do
    %{"type" => "array", "items" => attribute_type_schema(inner)}
  end

  defp attribute_type_schema(type) do
    normalized = normalize_type(type)
    Map.get(@type_to_schema, normalized, %{"type" => "string"})
  end

  # Normalizes type to a simple atom
  @spec normalize_type(atom() | tuple()) :: atom() | tuple()
  defp normalize_type({:array, inner}), do: {:array, normalize_type(inner)}

  defp normalize_type(type) when is_atom(type) do
    # Check if it's an Ash.Type module, otherwise return the type itself
    Map.get(@ash_type_to_atom, type, type)
  end

  defp normalize_type(_), do: :string

  # Returns available operators for a type
  @spec operators_for_type(atom() | tuple()) :: [atom()]
  defp operators_for_type(type) do
    base_ops = [:eq, :ne, :in, :not_in, :is_nil]

    case normalize_type(type) do
      t when t in [:string, :ci_string] ->
        base_ops ++ [:contains, :starts_with, :ends_with, :icontains, :istarts_with, :iends_with]

      t
      when t in [
             :integer,
             :float,
             :decimal,
             :date,
             :time,
             :datetime,
             :utc_datetime,
             :utc_datetime_usec,
             :naive_datetime
           ] ->
        base_ops ++ [:gt, :gte, :lt, :lte]

      :boolean ->
        [:eq, :ne, :is_nil]

      {:array, _} ->
        [:eq, :ne, :is_nil, :contains, :has_any, :has_all]

      _ ->
        base_ops
    end
  end

  # Builds schema for a specific operator
  @spec operator_schema(atom(), map()) :: map()
  defp operator_schema(:eq, base_schema), do: base_schema
  defp operator_schema(:ne, base_schema), do: base_schema
  defp operator_schema(:gt, base_schema), do: base_schema
  defp operator_schema(:gte, base_schema), do: base_schema
  defp operator_schema(:lt, base_schema), do: base_schema
  defp operator_schema(:lte, base_schema), do: base_schema
  defp operator_schema(:contains, _base_schema), do: %{"type" => "string"}
  defp operator_schema(:starts_with, _base_schema), do: %{"type" => "string"}
  defp operator_schema(:ends_with, _base_schema), do: %{"type" => "string"}
  defp operator_schema(:icontains, _base_schema), do: %{"type" => "string"}
  defp operator_schema(:istarts_with, _base_schema), do: %{"type" => "string"}
  defp operator_schema(:iends_with, _base_schema), do: %{"type" => "string"}
  defp operator_schema(:is_nil, _base_schema), do: %{"type" => "boolean"}
  defp operator_schema(:in, base_schema), do: %{"type" => "array", "items" => base_schema}
  defp operator_schema(:not_in, base_schema), do: %{"type" => "array", "items" => base_schema}
  defp operator_schema(:has_any, base_schema), do: %{"type" => "array", "items" => base_schema}
  defp operator_schema(:has_all, base_schema), do: %{"type" => "array", "items" => base_schema}
  defp operator_schema(_, base_schema), do: base_schema

  # Builds boolean filter operators (and, or, not)
  @spec build_boolean_filters() :: map()
  defp build_boolean_filters do
    %{
      "and" => %{
        "type" => "array",
        "items" => %{"type" => "object"},
        "description" => "All conditions must match"
      },
      "or" => %{
        "type" => "array",
        "items" => %{"type" => "object"},
        "description" => "Any condition must match"
      },
      "not" => %{
        "type" => "object",
        "description" => "Condition must not match"
      }
    }
  end

  # Checks if filtering should be derived for a resource
  @spec derive_filter?(module()) :: boolean()
  defp derive_filter?(resource) do
    case AshJsonApi.Resource.Info.derive_filter?(resource) do
      nil -> true
      value -> value
    end
  end

  # Gets the resource name for descriptions
  @spec resource_name(module()) :: String.t()
  defp resource_name(resource) do
    resource |> Module.split() |> List.last()
  end
end
