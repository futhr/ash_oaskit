defmodule AshOaskit.SchemaBuilder.ResourceSchemas do
  @moduledoc """
  Resource schema generation for JSON:API responses and inputs.

  This module handles the generation of OpenAPI schemas for Ash resources,
  including response wrappers, attribute schemas, and input schemas for
  create/update operations.

  ## Schema Types Generated

  For each resource, this module can generate:

  | Schema | Purpose | Example Name |
  |--------|---------|--------------|
  | Attributes | Object containing all public attributes | `PostAttributes` |
  | Response | JSON:API response wrapper with data object | `PostResponse` |
  | Relationships | Object containing relationship linkages | `PostRelationships` |
  | CreateInput | Input schema for create operations | `PostCreateInput` |
  | UpdateInput | Input schema for update operations | `PostUpdateInput` |

  ## Attributes Schema

  The attributes schema includes:
  - Regular attributes (excluding id, timestamps, private fields)
  - Calculations (computed values, always nullable)
  - Aggregates (summary values, always nullable)

  ## Response Schema

  Follows JSON:API structure:

      {
        "data": {
          "id": "string",
          "type": "resource_type",
          "attributes": { "$ref": "#/components/schemas/PostAttributes" },
          "relationships": { "$ref": "#/components/schemas/PostRelationships" }
        }
      }

  ## Input Schemas

  - **CreateInput**: Includes required fields without defaults
  - **UpdateInput**: All fields optional (partial updates)

  ## Usage

      builder = ResourceSchemas.add_resource_schemas(builder, MyApp.Post)
  """

  import AshOaskit.Core.SchemaRef, only: [schema_ref: 1]

  alias Ash.Resource.Info, as: ResourceInfo
  alias AshOaskit.SchemaBuilder.EmbeddedSchemas
  alias AshOaskit.SchemaBuilder.PropertyBuilders
  alias AshOaskit.SchemaBuilder.RelationshipSchemas

  @doc """
  Adds all schemas for a resource to the builder.

  This is the main entry point that generates:
  - Attributes schema
  - Response schema
  - Relationships schema (if resource has relationships)
  - Input schemas (create and update)

  ## Parameters

  - `builder` - The SchemaBuilder accumulator
  - `resource` - The Ash resource module
  - `opts` - Options including callback functions for builder operations

  ## Returns

  Updated builder with all resource schemas added.
  """
  @spec add_resource_schemas(map(), module(), keyword()) :: map()
  def add_resource_schemas(builder, resource, opts) do
    schema_name = resource_schema_name(resource)
    mark_seen_fn = Keyword.fetch!(opts, :mark_seen_fn)
    add_schema_fn = Keyword.fetch!(opts, :add_schema_fn)

    # Mark as seen to prevent cycles
    builder = mark_seen_fn.(builder, resource)

    # Build attributes schema
    builder = add_attributes_schema(builder, resource, schema_name, opts)

    # Build response schema
    builder = add_response_schema(builder, resource, schema_name, add_schema_fn)

    # Build relationships schema if resource has relationships
    rel_opts = [
      add_schema_fn: add_schema_fn,
      seen_fn: Keyword.fetch!(opts, :seen_fn),
      add_resource_schemas_fn: &add_resource_schemas(&1, &2, opts)
    ]

    builder =
      RelationshipSchemas.add_relationships_schema(builder, resource, schema_name, rel_opts)

    # Build input schemas
    builder = add_input_schemas(builder, resource, schema_name, add_schema_fn)

    builder
  end

  @doc """
  Generates the schema name for a resource.

  Extracts the last part of the module name.

  ## Parameters

  - `resource` - The Ash resource module

  ## Returns

  The schema name string.

  ## Examples

      iex> ResourceSchemas.resource_schema_name(MyApp.Blog.Post)
      "Post"
  """
  @spec resource_schema_name(module()) :: String.t()
  def resource_schema_name(resource) when is_atom(resource) do
    resource |> Module.split() |> List.last()
  end

  @doc """
  Adds the attributes schema for a resource.

  Includes regular attributes, calculations, and aggregates.
  Also generates embedded resource schemas as needed.

  ## Parameters

  - `builder` - The SchemaBuilder accumulator
  - `resource` - The Ash resource module
  - `schema_name` - Base name for the schema
  - `opts` - Options with callback functions

  ## Returns

  Updated builder with attributes schema added.
  """
  @spec add_attributes_schema(map(), module(), String.t(), keyword()) :: map()
  def add_attributes_schema(builder, resource, schema_name, opts) do
    add_schema_fn = Keyword.fetch!(opts, :add_schema_fn)
    mark_seen_fn = Keyword.fetch!(opts, :mark_seen_fn)
    has_schema_fn = Keyword.fetch!(opts, :has_schema_fn)

    # Build properties from attributes (and generate embedded schemas)
    attributes = get_public_attributes(resource)

    # Create embedded handler that uses our callback functions
    embedded_handler = fn bldr, type ->
      EmbeddedSchemas.maybe_add_embedded_schema(bldr, type, fn b, t ->
        if EmbeddedSchemas.has_embedded_schema?(b, t, has_schema_fn) do
          b
        else
          EmbeddedSchemas.add_embedded_resource_schema(b, t, mark_seen_fn, add_schema_fn)
        end
      end)
    end

    {attr_properties, builder} =
      PropertyBuilders.build_attribute_properties_with_embedded(
        builder,
        attributes,
        embedded_handler
      )

    # Build properties from calculations
    calculations = get_public_calculations(resource)
    calc_properties = PropertyBuilders.build_calculation_properties(builder, calculations)

    # Build properties from aggregates
    aggregates = get_public_aggregates(resource)
    agg_properties = PropertyBuilders.build_aggregate_properties(builder, aggregates)

    # Merge all properties (attributes take precedence)
    properties =
      agg_properties
      |> Map.merge(calc_properties)
      |> Map.merge(attr_properties)

    # Only attributes can be required (calculations/aggregates are computed)
    required =
      attributes
      |> Enum.filter(&EmbeddedSchemas.required_attribute?/1)
      |> Enum.map(&to_string(&1.name))

    schema =
      %{
        type: :object,
        properties: properties
      }

    schema = maybe_add_required(schema, required)

    add_schema_fn.(builder, "#{schema_name}Attributes", schema)
  end

  @doc """
  Adds the response wrapper schema for a resource.

  Creates a JSON:API compliant response structure with data object
  containing id, type, attributes, and optionally relationships.

  ## Parameters

  - `builder` - The SchemaBuilder accumulator
  - `resource` - The Ash resource module
  - `schema_name` - Base name for the schema
  - `add_schema_fn` - Function to add schemas

  ## Returns

  Updated builder with response schema added.
  """
  @spec add_response_schema(map(), module(), String.t(), function()) :: map()
  def add_response_schema(builder, resource, schema_name, add_schema_fn) do
    json_api_type = RelationshipSchemas.get_json_api_type(resource)

    data_schema = %{
      type: :object,
      properties: %{
        id: %{type: :string},
        type: %{type: :string, enum: [json_api_type]},
        attributes: schema_ref("#{schema_name}Attributes")
      },
      required: ["id", "type"]
    }

    # Add relationships reference if resource has relationships
    data_schema =
      if RelationshipSchemas.has_relationships?(resource) do
        put_in(
          data_schema,
          [:properties, :relationships],
          schema_ref("#{schema_name}Relationships")
        )
      else
        data_schema
      end

    response_schema = %{
      type: :object,
      properties: %{
        data: data_schema
      }
    }

    add_schema_fn.(builder, "#{schema_name}Response", response_schema)
  end

  @doc """
  Adds input schemas for create and update actions.

  ## Parameters

  - `builder` - The SchemaBuilder accumulator
  - `resource` - The Ash resource module
  - `schema_name` - Base name for the schema
  - `add_schema_fn` - Function to add schemas

  ## Returns

  Updated builder with input schemas added.
  """
  @spec add_input_schemas(map(), module(), String.t(), function()) :: map()
  def add_input_schemas(builder, resource, schema_name, add_schema_fn) do
    builder = add_create_input_schema(builder, resource, schema_name, add_schema_fn)
    builder = add_update_input_schema(builder, resource, schema_name, add_schema_fn)
    builder
  end

  @doc """
  Adds the create input schema.

  For create operations, required fields are those that:
  - Do not allow nil (`allow_nil?: false`)
  - Have no default value

  ## Parameters

  - `builder` - The SchemaBuilder accumulator
  - `resource` - The Ash resource module
  - `schema_name` - Base name for the schema
  - `add_schema_fn` - Function to add schemas

  ## Returns

  Updated builder with create input schema added.
  """
  @spec add_create_input_schema(map(), module(), String.t(), function()) :: map()
  def add_create_input_schema(builder, resource, schema_name, add_schema_fn) do
    attributes = get_writable_attributes(resource)
    properties = PropertyBuilders.build_attribute_properties(builder, attributes)

    # For create, required = allow_nil? false AND no default
    required =
      attributes
      |> Enum.filter(&create_required_attribute?/1)
      |> Enum.map(&to_string(&1.name))

    schema =
      %{
        type: :object,
        properties: properties
      }

    schema = maybe_add_required(schema, required)

    add_schema_fn.(builder, "#{schema_name}CreateInput", schema)
  end

  @doc """
  Adds the update input schema.

  For update operations, no fields are required since updates
  support partial modifications.

  ## Parameters

  - `builder` - The SchemaBuilder accumulator
  - `resource` - The Ash resource module
  - `schema_name` - Base name for the schema
  - `add_schema_fn` - Function to add schemas

  ## Returns

  Updated builder with update input schema added.
  """
  @spec add_update_input_schema(map(), module(), String.t(), function()) :: map()
  def add_update_input_schema(builder, resource, schema_name, add_schema_fn) do
    attributes = get_writable_attributes(resource)
    properties = PropertyBuilders.build_attribute_properties(builder, attributes)

    # For update, nothing is required (partial updates)
    schema = %{
      type: :object,
      properties: properties
    }

    add_schema_fn.(builder, "#{schema_name}UpdateInput", schema)
  end

  @doc """
  Gets public (non-private) attributes, excluding id and timestamps.

  ## Parameters

  - `resource` - The Ash resource module

  ## Returns

  List of public attribute structs.
  """
  @spec get_public_attributes(module()) :: [map()]
  def get_public_attributes(resource) do
    resource
    |> ResourceInfo.attributes()
    |> Enum.reject(fn attr ->
      attr.name in [:id, :inserted_at, :updated_at] or Map.get(attr, :private?, false)
    end)
  end

  @doc """
  Gets public (non-private) calculations from a resource.

  ## Parameters

  - `resource` - The Ash resource module

  ## Returns

  List of public calculation structs.
  """
  @spec get_public_calculations(module()) :: [map()]
  def get_public_calculations(resource) do
    resource
    |> ResourceInfo.calculations()
    |> Enum.reject(fn calc -> Map.get(calc, :private?, false) end)
  end

  @doc """
  Gets public (non-private) aggregates from a resource.

  ## Parameters

  - `resource` - The Ash resource module

  ## Returns

  List of public aggregate structs.
  """
  @spec get_public_aggregates(module()) :: [map()]
  def get_public_aggregates(resource) do
    resource
    |> ResourceInfo.aggregates()
    |> Enum.reject(fn agg -> Map.get(agg, :private?, false) end)
  end

  @doc """
  Gets writable attributes for input schemas.

  Excludes generated and non-writable attributes from the
  base public attributes.

  ## Parameters

  - `resource` - The Ash resource module

  ## Returns

  List of writable attribute structs.
  """
  @spec get_writable_attributes(module()) :: [map()]
  def get_writable_attributes(resource) do
    resource
    |> get_public_attributes()
    |> Enum.reject(fn attr ->
      Map.get(attr, :generated?, false) or
        Map.get(attr, :writable?, true) == false
    end)
  end

  @doc """
  Checks if an attribute is required for create operations.

  Required for create if: not nullable AND no default value.

  ## Parameters

  - `attr` - The attribute struct

  ## Returns

  `true` if required for create, `false` otherwise.
  """
  @spec create_required_attribute?(map()) :: boolean()
  def create_required_attribute?(%{allow_nil?: false} = attr) do
    Map.get(attr, :default) == nil
  end

  def create_required_attribute?(_), do: false

  # Adds required field to schema if there are required properties
  @spec maybe_add_required(map(), [String.t()]) :: map()
  defp maybe_add_required(schema, []), do: schema
  defp maybe_add_required(schema, required), do: Map.put(schema, :required, required)
end
