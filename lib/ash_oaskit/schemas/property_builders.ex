defmodule AshOaskit.SchemaBuilder.PropertyBuilders do
  @moduledoc """
  Property builders for attributes, calculations, and aggregates.

  This module handles the conversion of Ash resource properties (attributes,
  calculations, and aggregates) into OpenAPI JSON Schema property definitions.

  ## Overview

  When building schemas for Ash resources, each property type requires different
  handling:

  - **Attributes** - Core fields that map directly to JSON Schema types
  - **Calculations** - Computed fields that are always nullable (may not be loaded)
  - **Aggregates** - Computed summaries with type-specific schemas

  ## Type Mapping

  The module provides bidirectional type mapping between Ash types and JSON Schema:

  | Ash Type | JSON Schema |
  |----------|-------------|
  | `:string` | `{"type": "string"}` |
  | `:integer` | `{"type": "integer"}` |
  | `:float` | `{"type": "number", "format": "float"}` |
  | `:boolean` | `{"type": "boolean"}` |
  | `:uuid` | `{"type": "string", "format": "uuid"}` |
  | `:datetime` | `{"type": "string", "format": "date-time"}` |
  | `{:array, type}` | `{"type": "array", "items": ...}` |

  ## Aggregate Kinds

  Different aggregate kinds produce different schemas:

  | Kind | Schema |
  |------|--------|
  | `:count` | `{"type": "integer"}` |
  | `:exists` | `{"type": "boolean"}` |
  | `:sum`, `:avg` | `{"type": "number"}` |
  | `:list` | `{"type": "array", ...}` |
  | `:first`, `:min`, `:max` | Type-dependent |

  ## Usage

  This module is used internally by `AshOaskit.SchemaBuilder` to build
  property definitions:

      properties = PropertyBuilders.build_attribute_properties(builder, attributes)
      calc_props = PropertyBuilders.build_calculation_properties(builder, calculations)
      agg_props = PropertyBuilders.build_aggregate_properties(builder, aggregates)
  """

  alias AshOaskit.TypeMapper
  alias Ash.Resource.Info, as: ResourceInfo

  @schema_keys Map.new(
                 ~w(type format items properties required description enum anyOf oneOf allOf nullable
       pattern minimum maximum minLength maxLength minItems maxItems additionalProperties
       default uniqueItems multipleOf discriminator)a,
                 &{Atom.to_string(&1), &1}
               )
  @schema_values Map.new(
                   ~w(string integer number boolean object array null float double uuid date time date-time binary)a,
                   &{Atom.to_string(&1), &1}
                 )

  # Static aggregate kinds with fixed schemas
  @static_aggregate_schemas %{
    count: %{type: :integer},
    exists: %{type: :boolean},
    sum: %{type: :number},
    avg: %{type: :number}
  }

  @doc """
  Builds properties map from attributes.

  Uses TypeMapper to convert Ash types to JSON Schema, selecting
  the appropriate version-specific mapper based on the builder's
  OpenAPI version.

  ## Parameters

  - `builder` - The SchemaBuilder accumulator (for version info)
  - `attributes` - List of Ash attribute structs

  ## Returns

  A map of attribute names (strings) to JSON Schema definitions.

  ## Examples

      iex> attrs = [%{name: :title, type: :string, allow_nil?: false, constraints: []}]
      ...> PropertyBuilders.build_attribute_properties(%{version: "3.1"}, attrs)
      %{title: %{"type" => "string"}}
  """
  @spec build_attribute_properties(map(), [map()], keyword()) :: map()
  def build_attribute_properties(builder, attributes, opts \\ []) do
    action_name = opt(opts, :action_name, nil)
    argument_names = opt(opts, :argument_names, [])
    field_name_fn = opt(opts, :field_name_fn, &default_name/1)
    argument_name_fn = opt(opts, :argument_name_fn, field_name_fn)
    mapper_opts = if action_name, do: [direction: :input], else: []

    Map.new(attributes, fn attr ->
      schema =
        if builder.version == "3.1" do
          TypeMapper.to_json_schema_31(attr, mapper_opts)
        else
          TypeMapper.to_json_schema_30(attr, mapper_opts)
        end

      {property_name(attr, action_name, argument_names, field_name_fn, argument_name_fn), schema}
    end)
  end

  @doc """
  Builds properties and generates embedded schemas.

  Similar to `build_attribute_properties/2` but also detects embedded
  resource types and adds their schemas to the builder. This is necessary
  for attributes that reference embedded Ash resources.

  ## Parameters

  - `builder` - The SchemaBuilder accumulator
  - `attributes` - List of Ash attribute structs
  - `embedded_handler` - Function to call for embedded types

  ## Returns

  A tuple of `{properties_map, updated_builder}`.
  """
  @spec build_attribute_properties_with_embedded(map(), [map()], function(), keyword()) ::
          {map(), map()}
  def build_attribute_properties_with_embedded(builder, attributes, embedded_handler, opts \\ []) do
    action_name = opt(opts, :action_name, nil)
    argument_names = opt(opts, :argument_names, [])
    field_name_fn = opt(opts, :field_name_fn, &default_name/1)
    argument_name_fn = opt(opts, :argument_name_fn, field_name_fn)

    Enum.reduce(attributes, {%{}, builder}, fn attr, {props, bldr} ->
      # Check if this attribute is an embedded type
      bldr = Enum.reduce(TypeMapper.embedded_types(attr), bldr, &embedded_handler.(&2, &1))

      schema =
        if bldr.version == "3.1" do
          TypeMapper.to_json_schema_31(attr,
            direction: if(action_name, do: :input, else: :output)
          )
        else
          TypeMapper.to_json_schema_30(attr,
            direction: if(action_name, do: :input, else: :output)
          )
        end

      {Map.put(
         props,
         property_name(attr, action_name, argument_names, field_name_fn, argument_name_fn),
         schema
       ), bldr}
    end)
  end

  @doc """
  Builds properties map from calculations.

  Calculations are always nullable because they may not be loaded
  in the response. Each calculation is converted to its base schema
  and then wrapped to allow null values.

  ## Parameters

  - `builder` - The SchemaBuilder accumulator (for version info)
  - `calculations` - List of Ash calculation structs

  ## Returns

  A map of calculation names (strings) to JSON Schema definitions.
  """
  @spec build_calculation_properties(map(), [map()], keyword()) :: map()
  def build_calculation_properties(builder, calculations, opts \\ []) do
    field_name_fn = opt(opts, :field_name_fn, &default_name/1)

    Map.new(calculations, fn calc ->
      schema = calculation_to_schema(builder, calc)
      {field_name(calc.name, field_name_fn), schema}
    end)
  end

  @doc """
  Converts a calculation to a JSON Schema.

  Builds the base schema from the calculation's type, makes it
  nullable (calculations may not be loaded), and adds any description.

  ## Parameters

  - `builder` - The SchemaBuilder accumulator
  - `calc` - The calculation struct

  ## Returns

  A JSON Schema map for the calculation.
  """
  @spec calculation_to_schema(map(), map()) :: map()
  def calculation_to_schema(builder, calc) do
    field_schema(builder, Map.put_new(calc, :allow_nil?, true))
  end

  @doc """
  Builds properties map from aggregates.

  Aggregates are computed values that summarize related data.
  Like calculations, they are always nullable because they may
  not be loaded. The schema depends on the aggregate kind.

  ## Parameters

  - `builder` - The SchemaBuilder accumulator (for version info)
  - `aggregates` - List of Ash aggregate structs

  ## Returns

  A map of aggregate names (strings) to JSON Schema definitions.
  """
  @spec build_aggregate_properties(map(), [map()], keyword()) :: map()
  def build_aggregate_properties(builder, aggregates, opts \\ []) do
    field_name_fn = opt(opts, :field_name_fn, &default_name/1)

    Map.new(aggregates, fn agg ->
      schema = aggregate_to_schema(builder, agg)
      {field_name(agg.name, field_name_fn), schema}
    end)
  end

  @doc """
  Converts an aggregate to a JSON Schema.

  Maps the aggregate kind to its appropriate schema type,
  makes it nullable, and adds any description.

  ## Parameters

  - `builder` - The SchemaBuilder accumulator
  - `agg` - The aggregate struct

  ## Returns

  A JSON Schema map for the aggregate.
  """
  @spec aggregate_to_schema(map(), map()) :: map()
  def aggregate_to_schema(builder, agg) do
    case Map.get(agg, :resolved_type) do
      {type, constraints} ->
        field_schema(builder, %{
          type: type,
          constraints: constraints,
          allow_nil?: true,
          description: Map.get(agg, :description)
        })

      nil ->
        agg.kind
        |> aggregate_kind_to_schema(agg)
        |> make_nullable(builder.version)
        |> maybe_add_description(agg)
    end
  end

  @doc "Resolves an aggregate's effective type and constraints from its related field using Ash."
  @spec resolve_aggregate(module(), map()) :: map()
  def resolve_aggregate(resource, aggregate) do
    related = ResourceInfo.related(resource, Map.get(aggregate, :relationship_path, []))
    field = Map.get(aggregate, :field)
    field = if related && is_atom(field) && field, do: ResourceInfo.field(related, field)

    result =
      if aggregate.kind == :custom do
        {:ok, Map.get(aggregate, :type) || :term, Map.get(aggregate, :constraints, [])}
      else
        Ash.Query.Aggregate.kind_to_type(
          aggregate.kind,
          if(field, do: field.type),
          if(field, do: field.constraints, else: [])
        )
      end

    case result do
      {:ok, type, constraints} ->
        Map.put(aggregate, :resolved_type, {type, constraints})

      {:error, error} ->
        raise ArgumentError,
              "cannot resolve aggregate #{inspect(aggregate.name)}: #{inspect(error)}"
    end
  end

  @doc """
  Maps aggregate kind to JSON Schema type.

  Static kinds (count, exists, sum, avg) have fixed schemas.
  Dynamic kinds (list, first, min, max, custom) depend on the
  aggregate's configured type.

  ## Parameters

  - `kind` - The aggregate kind atom
  - `agg` - The aggregate struct (for type info)

  ## Returns

  A JSON Schema map for the aggregate kind.
  """
  @spec aggregate_kind_to_schema(atom(), map()) :: map()
  def aggregate_kind_to_schema(kind, %{type: type} = agg) when not is_nil(type) do
    kind = if kind == :custom, do: {:custom, type}, else: kind

    case Ash.Query.Aggregate.kind_to_type(kind, type, Map.get(agg, :constraints, [])) do
      {:ok, type, constraints} ->
        field_schema(%{version: "3.1"}, %{type: type, constraints: constraints, allow_nil?: false})

      {:error, _} ->
        %{}
    end
  end

  def aggregate_kind_to_schema(kind, agg) do
    case Map.get(@static_aggregate_schemas, kind) do
      nil -> dynamic_aggregate_schema(kind, agg)
      schema -> schema
    end
  end

  @doc """
  Converts an Ash type to a basic JSON Schema.

  Used for calculations and aggregates. Handles both atom types
  (`:string`) and module types (`Ash.Type.String`) by normalizing
  to atoms first.

  ## Parameters

  - `type` - The Ash type (atom, module, or tuple like `{:array, type}`)

  ## Returns

  A JSON Schema map for the type.

  ## Examples

      iex> PropertyBuilders.type_to_schema(:string)
      %{type: :string}

      iex> PropertyBuilders.type_to_schema({:array, :integer})
      %{type: :array, items: %{type: :integer}}
  """
  @spec type_to_schema(atom() | tuple(), keyword()) :: map()
  def type_to_schema(type, opts \\ [])
  def type_to_schema(:number, _), do: %{type: :number}

  def type_to_schema(type, opts),
    do:
      field_schema(%{version: Keyword.get(opts, :version, "3.1")}, %{
        type: type,
        allow_nil?: false
      })

  @doc """
  Normalizes Ash.Type.* modules to their atom equivalents.

  Maps module-based types like `Ash.Type.String` to their
  corresponding atom `:string` for consistent lookup.

  ## Parameters

  - `type` - The type to normalize

  ## Returns

  The normalized atom type.

  ## Examples

      iex> PropertyBuilders.normalize_type(Ash.Type.String)
      :string

      iex> PropertyBuilders.normalize_type(:boolean)
      :boolean
  """
  @spec normalize_type(atom()) :: atom()
  defdelegate normalize_type(type), to: TypeMapper

  defdelegate make_nullable(schema, version), to: AshOaskit.Schemas.Nullable

  @doc """
  Adds description to schema if present in the source map.

  ## Parameters

  - `schema` - The schema map to enhance
  - `source` - The source struct/map that may contain a description

  ## Returns

  The schema with description added if present.
  """
  @spec maybe_add_description(map(), map()) :: map()
  def maybe_add_description(schema, source) do
    case Map.get(source, :description) do
      desc when is_binary(desc) -> Map.put(schema, :description, desc)
      _ -> schema
    end
  end

  # Handle aggregate kinds that depend on the aggregate's type
  defp dynamic_aggregate_schema(:list, agg) do
    item_type = Map.get(agg, :type, :string)
    %{type: :array, items: type_to_schema(item_type)}
  end

  defp dynamic_aggregate_schema(kind, agg) when kind in [:first, :min, :max, :custom] do
    default_type = if kind in [:min, :max], do: :number, else: :string
    type_to_schema(Map.get(agg, :type, default_type))
  end

  defp dynamic_aggregate_schema(_, _), do: %{}

  defp property_name(attr, action_name, argument_names, field_name_fn, argument_name_fn) do
    json_name =
      if action_name && attr.name in argument_names do
        argument_name_fn.(attr.name)
      else
        field_name_fn.(attr.name)
      end

    json_property_key(attr.name, json_name)
  end

  defp field_name(name, field_name_fn) do
    json_property_key(name, field_name_fn.(name))
  end

  defp json_property_key(name, json_name) when is_atom(name) do
    if json_name == to_string(name), do: name, else: json_name
  end

  defp json_property_key(_, json_name), do: json_name

  defp default_name(name), do: name

  defp field_schema(builder, field) do
    schema =
      if builder.version == "3.1",
        do: TypeMapper.to_json_schema_31(field),
        else: TypeMapper.to_json_schema_30(field)

    atom_schema(schema)
  end

  defp atom_schema(schema) when is_map(schema) do
    Map.new(schema, fn {key, value} ->
      value = if key in ["type", "format"], do: atom_type(value), else: atom_schema(value)
      {Map.get(@schema_keys, key, key), value}
    end)
  end

  defp atom_schema(values) when is_list(values), do: Enum.map(values, &atom_schema/1)
  defp atom_schema(value), do: value
  defp atom_type(values) when is_list(values), do: Enum.map(values, &atom_type/1)
  defp atom_type(value), do: Map.get(@schema_values, value, value)

  defp opt([{key, value} | _], key, _), do: value
  defp opt([_ | rest], key, default), do: opt(rest, key, default)
  defp opt([], _, default), do: default
end
