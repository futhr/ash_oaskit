defmodule AshOaskit.SchemaBuilder.EmbeddedSchemas do
  @moduledoc """
  Embedded resource schema generation.

  This module handles the detection and schema generation for embedded Ash
  resources. Embedded resources are value objects that are serialized inline
  within their parent resource, rather than as separate JSON:API resources.

  ## Overview

  Embedded resources in Ash are defined with `data_layer: :embedded` and are
  used for complex value types like addresses, metadata objects, or any
  structured data that doesn't need a separate identity.

  ## Detection

  The module identifies embedded resources by checking:

  1. The type is a loaded Elixir module
  2. The module implements `spark_is/0` (indicating a Spark DSL resource)
  3. The module is an Ash.Resource
  4. The resource has `embedded?: true`

  ## Schema Generation

  When an embedded resource is detected, the module:

  1. Extracts public attributes (excluding id, timestamps)
  2. Recursively handles nested embedded types
  3. Builds a JSON Schema with properties and required fields
  4. Adds the schema to the builder's schema collection

  ## Cycle Detection

  The module marks embedded types as "seen" before processing to prevent
  infinite loops with self-referential embedded types.

  ## Usage

      # Check if a type is embedded
      if EmbeddedSchemas.embedded_resource?(MyApp.Address) do
        builder = EmbeddedSchemas.add_embedded_resource_schema(builder, MyApp.Address)
      end

      # Or use the maybe_ variant which handles detection automatically
      builder = EmbeddedSchemas.maybe_add_embedded_schema(builder, attr.type, embedded_handler)
  """

  alias Ash.Resource.Info, as: ResourceInfo
  alias AshOaskit.SchemaBuilder.PropertyBuilders

  @doc """
  Checks if a type is an embedded Ash resource.

  Performs a series of checks to determine if the given type module
  is an embedded resource that should have its schema generated.

  ## Parameters

  - `type` - The type module to check

  ## Returns

  `true` if the type is an embedded Ash resource, `false` otherwise.

  ## Examples

      iex> EmbeddedSchemas.embedded_resource?(MyApp.Address)
      true

      iex> EmbeddedSchemas.embedded_resource?(:string)
      false
  """
  @spec embedded_resource?(atom()) :: boolean()
  def embedded_resource?(type) do
    is_atom(type) and
      Code.ensure_loaded?(type) and
      function_exported?(type, :spark_is, 0) and
      Spark.Dsl.is?(type, Ash.Resource) and
      ResourceInfo.embedded?(type)
  end

  @doc """
  Checks if an embedded schema already exists in the builder.

  Prevents duplicate schema generation by checking if the schema
  name derived from the embedded type already exists.

  ## Parameters

  - `builder` - The SchemaBuilder accumulator
  - `type` - The embedded type module
  - `has_schema_fn` - Function to check schema existence

  ## Returns

  `true` if the schema exists, `false` otherwise.
  """
  @spec has_embedded_schema?(map(), module(), function()) :: boolean()
  def has_embedded_schema?(builder, type, has_schema_fn) do
    schema_name = type |> Module.split() |> List.last()
    has_schema_fn.(builder, schema_name)
  end

  @doc """
  Conditionally adds an embedded schema if the type is embedded.

  Handles array types by unwrapping to check the inner type.
  Only adds the schema if it's an embedded resource that hasn't
  been processed yet.

  ## Parameters

  - `builder` - The SchemaBuilder accumulator
  - `type` - The attribute type (may be `{:array, inner}`)
  - `add_fn` - Function to add the embedded schema

  ## Returns

  The builder, potentially with new embedded schemas added.
  """
  @spec maybe_add_embedded_schema(map(), atom() | tuple(), function()) :: map()
  def maybe_add_embedded_schema(builder, {:array, inner_type}, add_fn) do
    maybe_add_embedded_schema(builder, inner_type, add_fn)
  end

  def maybe_add_embedded_schema(builder, type, add_fn) when is_atom(type) do
    if embedded_resource?(type) do
      add_fn.(builder, type)
    else
      builder
    end
  end

  def maybe_add_embedded_schema(builder, _type, _add_fn), do: builder

  @doc """
  Adds schema for an embedded resource.

  Extracts the embedded resource's attributes and builds a JSON Schema
  with proper property definitions and required fields. Handles nested
  embedded types recursively.

  ## Parameters

  - `builder` - The SchemaBuilder accumulator
  - `embedded_type` - The embedded resource module
  - `mark_seen_fn` - Function to mark types as processed
  - `add_schema_fn` - Function to add schemas to builder

  ## Returns

  Updated builder with the embedded schema added.
  """
  @spec add_embedded_resource_schema(map(), module(), function(), function()) :: map()
  def add_embedded_resource_schema(builder, embedded_type, mark_seen_fn, add_schema_fn) do
    schema_name = embedded_type |> Module.split() |> List.last()

    # Mark as seen to prevent cycles
    builder = mark_seen_fn.(builder, embedded_type)

    # Get embedded resource attributes
    attributes = get_embedded_attributes(embedded_type)

    # Build properties (recursively handling nested embedded types)
    # Create the embedded handler that uses our functions
    embedded_handler = fn bldr, type ->
      maybe_add_embedded_schema(bldr, type, fn b, t ->
        add_embedded_resource_schema(b, t, mark_seen_fn, add_schema_fn)
      end)
    end

    {properties, builder} =
      PropertyBuilders.build_attribute_properties_with_embedded(
        builder,
        attributes,
        embedded_handler
      )

    # Determine required fields
    required =
      attributes
      |> Enum.filter(&required_attribute?/1)
      |> Enum.map(&to_string(&1.name))

    schema =
      %{
        type: :object,
        properties: properties
      }

    schema = maybe_add_required(schema, required)

    add_schema_fn.(builder, schema_name, schema)
  end

  @doc """
  Gets attributes from an embedded resource.

  Filters out internal attributes (id, timestamps) and private attributes,
  returning only the public attributes that should appear in the schema.

  ## Parameters

  - `embedded_type` - The embedded resource module

  ## Returns

  List of attribute structs.
  """
  @spec get_embedded_attributes(module()) :: [map()]
  def get_embedded_attributes(embedded_type) do
    embedded_type
    |> ResourceInfo.attributes()
    |> Enum.reject(fn attr ->
      attr.name in [:id, :inserted_at, :updated_at] or Map.get(attr, :private?, false)
    end)
  end

  @doc """
  Checks if an attribute should be in the required list.

  An attribute is required if it does not allow nil values.

  ## Parameters

  - `attr` - The attribute struct

  ## Returns

  `true` if the attribute is required, `false` otherwise.
  """
  @spec required_attribute?(map()) :: boolean()
  def required_attribute?(%{allow_nil?: false}), do: true
  def required_attribute?(_attr), do: false

  # Adds required field to schema if there are required properties
  @spec maybe_add_required(map(), [String.t()]) :: map()
  defp maybe_add_required(schema, []), do: schema
  defp maybe_add_required(schema, required), do: Map.put(schema, :required, required)
end
