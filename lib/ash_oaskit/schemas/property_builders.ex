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

  # Map of types to their JSON Schema representation
  @type_to_schema_map %{
    string: %{type: :string},
    ci_string: %{type: :string},
    integer: %{type: :integer},
    float: %{type: :number, format: :float},
    decimal: %{type: :number, format: :double},
    boolean: %{type: :boolean},
    date: %{type: :string, format: :date},
    time: %{type: :string, format: :time},
    datetime: %{type: :string, format: :"date-time"},
    utc_datetime: %{type: :string, format: :"date-time"},
    utc_datetime_usec: %{type: :string, format: :"date-time"},
    naive_datetime: %{type: :string, format: :"date-time"},
    uuid: %{type: :string, format: :uuid},
    binary: %{type: :string, format: :binary},
    map: %{type: :object},
    atom: %{type: :string},
    term: %{},
    number: %{type: :number}
  }

  # Map of Ash.Type.* modules to their atom equivalents
  @ash_type_to_atom %{
    Ash.Type.String => :string,
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
    Ash.Type.Binary => :binary,
    Ash.Type.Map => :map,
    Ash.Type.Atom => :atom,
    Ash.Type.Term => :term
  }

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
  @spec build_attribute_properties(map(), [map()]) :: map()
  def build_attribute_properties(builder, attributes) do
    Map.new(attributes, fn attr ->
      schema =
        if builder.version == "3.1" do
          TypeMapper.to_json_schema_31(attr)
        else
          TypeMapper.to_json_schema_30(attr)
        end

      {attr.name, schema}
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
  @spec build_attribute_properties_with_embedded(map(), [map()], function()) :: {map(), map()}
  def build_attribute_properties_with_embedded(builder, attributes, embedded_handler) do
    Enum.reduce(attributes, {%{}, builder}, fn attr, {props, bldr} ->
      # Check if this attribute is an embedded type
      bldr = embedded_handler.(bldr, attr.type)

      schema =
        if bldr.version == "3.1" do
          TypeMapper.to_json_schema_31(attr)
        else
          TypeMapper.to_json_schema_30(attr)
        end

      {Map.put(props, attr.name, schema), bldr}
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
  @spec build_calculation_properties(map(), [map()]) :: map()
  def build_calculation_properties(builder, calculations) do
    Map.new(calculations, fn calc ->
      schema = calculation_to_schema(builder, calc)
      {calc.name, schema}
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
    base_schema = type_to_schema(calc.type)

    base_schema
    |> make_nullable(builder.version)
    |> maybe_add_description(calc)
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
  @spec build_aggregate_properties(map(), [map()]) :: map()
  def build_aggregate_properties(builder, aggregates) do
    Map.new(aggregates, fn agg ->
      schema = aggregate_to_schema(builder, agg)
      {agg.name, schema}
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
    agg.kind
    |> aggregate_kind_to_schema(agg)
    |> make_nullable(builder.version)
    |> maybe_add_description(agg)
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
  @spec type_to_schema(atom() | tuple()) :: map()
  def type_to_schema({:array, inner}), do: %{type: :array, items: type_to_schema(inner)}

  def type_to_schema(type) when is_atom(type) do
    normalized = normalize_type(type)
    Map.get(@type_to_schema_map, normalized, %{type: :string})
  end

  def type_to_schema(_), do: %{type: :string}

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
  def normalize_type(type), do: Map.get(@ash_type_to_atom, type, type)

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
end
