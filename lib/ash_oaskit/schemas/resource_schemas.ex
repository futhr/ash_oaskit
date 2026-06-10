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
  | Action input | Input schema derived from one action | `PostCreateInput`, `PostPublishInput` |

  ## Attributes Schema

  The attributes schema includes:
  - Public attributes (excluding the sole primary key)
  - Public calculations (computed values, always nullable)
  - Public aggregates (summary values, always nullable)

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

  Input schemas are derived per action (see `add_action_input_schema/5`):
  the attributes the action accepts plus its public arguments, with
  `required` computed from the action's semantics — create-type actions
  require non-nil attributes without defaults; update-type actions only
  require `require_attributes` (partial updates).

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
  - Action-derived input schemas (see `add_input_schemas/4`)

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
    builder = add_input_schemas(builder, resource, schema_name, opts)

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
  Adds action-derived input schemas.

  One input schema is generated per entry in the `:input_actions`
  option, named `{Resource}{ActionCamelized}Input` — for the
  conventional `create`/`update` action names this yields the familiar
  `{Resource}CreateInput`/`{Resource}UpdateInput`.

  Each entry is an `{action_name, route}` tuple (route may be `nil`).
  When `:input_actions` is omitted, the resource's primary create and
  update actions are used.

  ## Parameters

  - `builder` - The SchemaBuilder accumulator
  - `resource` - The Ash resource module
  - `schema_name` - Base name for the schema
  - `opts` - Options including `:add_schema_fn` and `:input_actions`

  ## Returns

  Updated builder with input schemas added.
  """
  @spec add_input_schemas(map(), module(), String.t(), keyword()) :: map()
  def add_input_schemas(builder, resource, schema_name, opts) do
    input_actions =
      Keyword.get_lazy(opts, :input_actions, fn -> default_input_actions(resource) end)

    Enum.reduce(input_actions, builder, fn {action_name, route}, builder ->
      add_action_input_schema(
        builder,
        resource,
        action_name,
        schema_name,
        Keyword.put(opts, :route, route)
      )
    end)
  end

  @doc """
  Adds the input schema for a single action.

  The schema is derived from the action the way AshJsonApi derives
  request bodies:

  - properties: the attributes in the action's `accept` list that are
    writable, plus the action's public arguments (minus path params,
    `query_params`, and `relationship_arguments` of the given route)
  - required (create-type actions): accepted attributes with
    `allow_nil?: false`, no default, not `generated?`, and not in
    `allow_nil_input`; plus non-nil arguments; plus `require_attributes`
  - required (update-type actions): `require_attributes` plus non-nil
    arguments — updates are otherwise partial
  - generic actions document their arguments only

  Unknown action names are skipped.

  ## Parameters

  - `builder` - The SchemaBuilder accumulator
  - `resource` - The Ash resource module
  - `action_name` - The action to derive the input from
  - `schema_name` - Base name for the schema
  - `opts` - Options including `:add_schema_fn` and `:route` (the route
    the action is exposed under, or `nil`)

  ## Returns

  Updated builder with the action input schema added.
  """
  @spec add_action_input_schema(map(), module(), atom(), String.t(), keyword()) :: map()
  def add_action_input_schema(builder, resource, action_name, schema_name, opts) do
    add_schema_fn = Keyword.fetch!(opts, :add_schema_fn)
    route = Keyword.get(opts, :route)

    case ResourceInfo.action(resource, action_name) do
      nil ->
        builder

      action ->
        attributes = accepted_writable_attributes(resource, action)
        arguments = body_arguments(action, route)

        properties = PropertyBuilders.build_attribute_properties(builder, attributes ++ arguments)

        schema =
          maybe_add_required(
            %{type: :object, properties: properties},
            action_input_required(action, attributes, arguments)
          )

        add_schema_fn.(builder, action_input_schema_name(schema_name, action_name), schema)
    end
  end

  @doc """
  Returns the component schema name for an action's input.

  ## Examples

      iex> ResourceSchemas.action_input_schema_name("Post", :create)
      "PostCreateInput"

      iex> ResourceSchemas.action_input_schema_name("Post", :bulk_archive)
      "PostBulkArchiveInput"
  """
  @spec action_input_schema_name(String.t(), atom()) :: String.t()
  def action_input_schema_name(schema_name, action_name) do
    "#{schema_name}#{action_name |> to_string() |> Macro.camelize()}Input"
  end

  # All create/update actions, used when no routes are known
  defp default_input_actions(resource) do
    resource
    |> ResourceInfo.actions()
    |> Enum.filter(&(&1.type in [:create, :update]))
    |> Enum.map(&{&1.name, nil})
  end

  # Attributes in the action's accept list that are writable; generic
  # and read actions take no attributes
  defp accepted_writable_attributes(_, %{type: type}) when type in [:action, :read] do
    []
  end

  defp accepted_writable_attributes(resource, action) do
    accept = action.accept || []

    resource
    |> ResourceInfo.attributes()
    |> Enum.filter(&(&1.name in accept and &1.writable?))
  end

  # Public arguments that belong in the request body: path params,
  # query params, and relationship arguments are carried elsewhere
  defp body_arguments(action, route) do
    action.arguments
    |> Enum.filter(& &1.public?)
    |> reject_path_arguments(route)
    |> reject_query_params(route)
    |> reject_relationship_arguments(route)
  end

  defp reject_path_arguments(arguments, %{route: route_path}) when is_binary(route_path) do
    path_params =
      route_path
      |> Path.split()
      |> Enum.filter(&String.starts_with?(&1, ":"))
      |> Enum.map(&String.trim_leading(&1, ":"))

    Enum.reject(arguments, &(to_string(&1.name) in path_params))
  end

  defp reject_path_arguments(arguments, _), do: arguments

  defp reject_query_params(arguments, %{query_params: query_params}) do
    query_params = List.wrap(query_params)
    Enum.reject(arguments, &(&1.name in query_params))
  end

  defp reject_query_params(arguments, _), do: arguments

  defp reject_relationship_arguments(arguments, %{relationship_arguments: rel_args})
       when is_list(rel_args) do
    Enum.reject(arguments, &relationship_argument?(rel_args, &1.name))
  end

  defp reject_relationship_arguments(arguments, _), do: arguments

  defp relationship_argument?(rel_args, name) do
    Enum.any?(rel_args, fn
      {:id, ^name} -> true
      ^name -> true
      _ -> false
    end)
  end

  # Required body members, mirroring AshJsonApi.OpenApi.required_write_attributes/4
  defp action_input_required(action, attributes, arguments) do
    argument_names = arguments |> Enum.reject(& &1.allow_nil?) |> Enum.map(&to_string(&1.name))

    attribute_names =
      case action.type do
        :update ->
          []

        type when type in [:action, :read] ->
          []

        _ ->
          allow_nil_input = Map.get(action, :allow_nil_input, [])
          argument_name_set = MapSet.new(arguments, & &1.name)

          attributes
          |> Enum.reject(fn attr ->
            attr.allow_nil? or not is_nil(attr.default) or
              Map.get(attr, :generated?, false) or
              attr.name in allow_nil_input or
              MapSet.member?(argument_name_set, attr.name)
          end)
          |> Enum.map(&to_string(&1.name))
      end

    require_attributes =
      action
      |> Map.get(:require_attributes, [])
      |> Enum.map(&to_string/1)

    Enum.uniq(attribute_names ++ argument_names ++ require_attributes)
  end

  @doc """
  Gets public attributes, excluding the sole primary key.

  Only attributes marked `public? true` are included, matching what
  AshJsonApi actually serializes. The primary key is excluded only when
  it is the resource's single primary key — JSON:API carries it as the
  top-level `id` member, never inside `attributes`. Composite primary
  keys keep their parts as regular attributes. Public timestamps are
  included.

  ## Parameters

  - `resource` - The Ash resource module

  ## Returns

  List of public attribute structs.
  """
  @spec get_public_attributes(module()) :: [map()]
  def get_public_attributes(resource) do
    resource
    |> ResourceInfo.public_attributes()
    |> Enum.reject(&only_primary_key?(resource, &1.name))
  end

  defp only_primary_key?(resource, name) do
    ResourceInfo.primary_key(resource) == [name]
  end

  @doc """
  Gets public calculations from a resource.

  Only calculations marked `public? true` are included.

  ## Parameters

  - `resource` - The Ash resource module

  ## Returns

  List of public calculation structs.
  """
  @spec get_public_calculations(module()) :: [map()]
  def get_public_calculations(resource) do
    ResourceInfo.public_calculations(resource)
  end

  @doc """
  Gets public aggregates from a resource.

  Only aggregates marked `public? true` are included.

  ## Parameters

  - `resource` - The Ash resource module

  ## Returns

  List of public aggregate structs.
  """
  @spec get_public_aggregates(module()) :: [map()]
  def get_public_aggregates(resource) do
    ResourceInfo.public_aggregates(resource)
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
