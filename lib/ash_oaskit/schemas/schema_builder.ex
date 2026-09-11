defmodule AshOaskit.SchemaBuilder do
  @moduledoc """
  Accumulator-based schema builder for recursive type handling.

  This module provides the core infrastructure for building OpenAPI schemas
  from Ash resources, with proper handling of recursive types, embedded
  resources, relationships, and cycle detection.

  ## Overview

  The SchemaBuilder uses an accumulator pattern (similar to AshJsonApi.OpenApi)
  to collect schemas during spec generation. This pattern enables:

  - **Cycle Detection**: Prevents infinite loops when resources reference themselves
  - **Schema Deduplication**: Each schema is generated once and referenced via `$ref`
  - **Ordered Generation**: Ensures all referenced schemas exist in components

  ## Architecture

  The builder maintains state through a struct containing:

  - `schemas` - Map of schema name to schema definition
  - `resource_names` - Map of component base name to its owning resource
  - `seen_types` - MapSet of types already processed (output schemas)
  - `seen_input_types` - MapSet of input types already processed
  - `version` - OpenAPI version ("3.0" or "3.1") for nullable handling

  ## Module Organization

  The SchemaBuilder delegates to focused submodules:

  - `AshOaskit.SchemaBuilder.PropertyBuilders` - Attribute/calculation/aggregate properties
  - `AshOaskit.SchemaBuilder.EmbeddedSchemas` - Embedded resource handling
  - `AshOaskit.SchemaBuilder.RelationshipSchemas` - Relationship schema building
  - `AshOaskit.SchemaBuilder.ResourceSchemas` - Resource/response/input schemas

  ## Usage

      # Initialize a new builder
      builder = SchemaBuilder.new(version: "3.1")

      # Add schemas for a resource
      builder = SchemaBuilder.add_resource_schemas(builder, MyResource)

      # Extract final components
      components = SchemaBuilder.to_components(builder)

  ## Schema Naming Conventions

  | Schema Type | Naming Pattern | Example |
  |-------------|---------------|---------|
  | Output attributes | `{Resource}Attributes` | `PostAttributes` |
  | Output response | `{Resource}Response` | `PostResponse` |
  | Create input | `{Resource}CreateInput` | `PostCreateInput` |
  | Update input | `{Resource}UpdateInput` | `PostUpdateInput` |
  | Relationships | `{Resource}Relationships` | `PostRelationships` |
  | Relationship linkage | `{Resource}{Rel}Linkage` | `PostCommentsLinkage` |
  | Embedded output | `{Embedded}` | `Address` |
  | Embedded input | `{Embedded}Input` | `AddressInput` |

  ## Cycle Detection

  When building schemas for types that may reference themselves (directly or
  indirectly), the builder tracks seen types to prevent infinite recursion:

      # Self-referential type (e.g., Category with parent)
      defmodule Category do
        relationships do
          belongs_to :parent, __MODULE__
          has_many :children, __MODULE__
        end
      end

  When a cycle is detected, the builder emits a `$ref` instead of inlining:

      %{"$ref" => "#/components/schemas/Category"}

  ## Integration with Generators

  This module is used by both V30 and V31 generators to build schemas:

      defmodule AshOaskit.Generators.V31 do
        def generate(domains, opts) do
          builder = SchemaBuilder.new(version: "3.1")
          builder = Enum.reduce(domains, builder, &add_domain_schemas/2)

          %{
            "components" => SchemaBuilder.to_components(builder)
          }
        end
      end

  ## Error Handling

  The builder gracefully handles edge cases:

  - Invalid resource modules: Raise through Ash introspection
  - Private attributes: Excluded from schemas
  - Function defaults: Omitted (can't serialize to JSON)
  - Unknown types: Falls back to empty schema `{}`
  """

  alias AshOaskit.SchemaBuilder.ResourceSchemas

  @typedoc """
  The SchemaBuilder accumulator map.

  ## Fields

  - `:schemas` - Map of schema name (string) to schema definition (map)
  - `:resource_names` - Map of schema base name to the resource that owns it
  - `:seen_types` - MapSet of modules already processed for output schemas
  - `:seen_input_types` - MapSet of modules already processed for input schemas
  - `:version` - OpenAPI version string ("3.0" or "3.1")
  """
  @type t :: map()

  @doc """
  Creates a new SchemaBuilder with the given options.

  ## Options

  - `:version` - OpenAPI version ("3.0" or "3.1"). Defaults to "3.1".

  ## Examples

      iex> builder = AshOaskit.SchemaBuilder.new()
      ...> builder.version
      "3.1"

      iex> builder = AshOaskit.SchemaBuilder.new(version: "3.0")
      ...> builder.version
      "3.0"
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %{
      schemas: %{},
      resource_names: %{},
      schema_owners: %{
        "JsonApiError" => {AshOaskit.ErrorSchemas, :response},
        "JsonApiErrorObject" => {AshOaskit.ErrorSchemas, :object}
      },
      seen_types: MapSet.new(),
      seen_input_types: MapSet.new(),
      version: Keyword.get(opts, :version, "3.1")
    }
  end

  @doc """
  Adds a schema to the builder.

  If a schema with the same name already exists, it is not overwritten.
  This ensures the first definition wins (important for recursive types
  where we want the full definition, not a placeholder).

  ## Parameters

  - `builder` - The current SchemaBuilder
  - `name` - Schema name (string)
  - `schema` - Schema definition (map)

  ## Returns

  Updated SchemaBuilder with the new schema added.

  ## Examples

      iex> builder = AshOaskit.SchemaBuilder.new()
      ...> schema = %{type: :object, properties: %{}}
      ...> builder = AshOaskit.SchemaBuilder.add_schema(builder, "Post", schema)
      ...> AshOaskit.SchemaBuilder.has_schema?(builder, "Post")
      true
  """
  @spec add_schema(t(), String.t(), map()) :: t()
  def add_schema(%{schemas: schemas} = builder, name, schema)
      when is_binary(name) and is_map(schema) do
    if Map.has_key?(Map.get(builder, :embedded_names, %{}), name) and
         Map.has_key?(schemas, name) and Map.fetch!(schemas, name) !== schema do
      raise ArgumentError, "component #{inspect(name)} conflicts with an embedded resource schema"
    end

    if has_schema?(builder, name) do
      builder
    else
      %{builder | schemas: Map.put(schemas, name, schema)}
    end
  end

  @doc """
  Checks if a schema with the given name exists in the builder.

  ## Parameters

  - `builder` - The current SchemaBuilder
  - `name` - Schema name to check

  ## Returns

  `true` if the schema exists, `false` otherwise.

  ## Examples

      iex> builder = AshOaskit.SchemaBuilder.new()
      ...> AshOaskit.SchemaBuilder.has_schema?(builder, "Post")
      false

      iex> builder = AshOaskit.SchemaBuilder.new()
      ...> builder = AshOaskit.SchemaBuilder.add_schema(builder, "Post", %{})
      ...> AshOaskit.SchemaBuilder.has_schema?(builder, "Post")
      true
  """
  @spec has_schema?(t(), String.t()) :: boolean()
  def has_schema?(%{schemas: schemas}, name) when is_binary(name) do
    Map.has_key?(schemas, name)
  end

  @doc """
  Marks a type as seen for output schema generation.

  Used to detect cycles in recursive type definitions. When a type
  is marked as seen, subsequent calls to `seen?/2` will return `true`,
  allowing the builder to emit a `$ref` instead of recursing infinitely.

  ## Parameters

  - `builder` - The current SchemaBuilder
  - `type` - The type module to mark as seen

  ## Returns

  Updated SchemaBuilder with the type marked as seen.

  ## Examples

      iex> builder = AshOaskit.SchemaBuilder.new()
      ...> builder = AshOaskit.SchemaBuilder.mark_seen(builder, MyApp.Post)
      ...> AshOaskit.SchemaBuilder.seen?(builder, MyApp.Post)
      true
  """
  @spec mark_seen(t(), module()) :: t()
  def mark_seen(%{seen_types: seen_types} = builder, type) when is_atom(type) do
    %{builder | seen_types: MapSet.put(seen_types, type)}
  end

  @doc """
  Checks if a type has been seen for output schema generation.

  ## Parameters

  - `builder` - The current SchemaBuilder
  - `type` - The type module to check

  ## Returns

  `true` if the type has been seen, `false` otherwise.

  ## Examples

      iex> builder = AshOaskit.SchemaBuilder.new()
      ...> AshOaskit.SchemaBuilder.seen?(builder, MyApp.Post)
      false
  """
  @spec seen?(t(), module()) :: boolean()
  def seen?(%{seen_types: seen_types}, type) when is_atom(type) do
    MapSet.member?(seen_types, type)
  end

  @doc """
  Marks a type as seen for input schema generation.

  Input schemas are tracked separately from output schemas because
  they may have different structures (e.g., different required fields
  for create vs update operations).

  ## Parameters

  - `builder` - The current SchemaBuilder
  - `type` - The type module to mark as seen

  ## Returns

  Updated SchemaBuilder with the input type marked as seen.
  """
  @spec mark_input_seen(t(), module()) :: t()
  def mark_input_seen(%{seen_input_types: seen_input_types} = builder, type) when is_atom(type) do
    %{builder | seen_input_types: MapSet.put(seen_input_types, type)}
  end

  @doc """
  Checks if a type has been seen for input schema generation.

  ## Parameters

  - `builder` - The current SchemaBuilder
  - `type` - The type module to check

  ## Returns

  `true` if the input type has been seen, `false` otherwise.
  """
  @spec input_seen?(t(), module()) :: boolean()
  def input_seen?(%{seen_input_types: seen_input_types}, type) when is_atom(type) do
    MapSet.member?(seen_input_types, type)
  end

  @doc """
  Converts the builder's schemas to an OpenAPI components object.

  ## Parameters

  - `builder` - The current SchemaBuilder

  ## Returns

  A map suitable for the `components` section of an OpenAPI spec:

      %{
        schemas: %{
          "PostAttributes" => %{...},
          "PostResponse" => %{...},
          ...
        }
      }

  ## Examples

      iex> builder = AshOaskit.SchemaBuilder.new()
      ...> builder = AshOaskit.SchemaBuilder.add_schema(builder, "Post", %{type: :object})
      ...> components = AshOaskit.SchemaBuilder.to_components(builder)
      ...> Map.has_key?(components.schemas, "Post")
      true
  """
  @spec to_components(t()) :: map()
  def to_components(%{schemas: schemas}) do
    validate_refs!(%{components: %{schemas: schemas}}, schemas)
    %{schemas: schemas}
  end

  @doc false
  @spec validate_refs!(term(), map()) :: :ok
  defdelegate validate_refs!(document, schemas), to: AshOaskit.Schemas.References, as: :validate!

  @doc """
  Gets the OpenAPI version from the builder.

  ## Parameters

  - `builder` - The current SchemaBuilder

  ## Returns

  The OpenAPI version string ("3.0" or "3.1").
  """
  @spec version(t()) :: String.t()
  def version(%{version: version}), do: version

  @doc """
  Gets a schema by name from the builder.

  ## Parameters

  - `builder` - The current SchemaBuilder
  - `name` - The schema name to retrieve

  ## Returns

  The schema map if found, `nil` otherwise.
  """
  @spec get_schema(t(), String.t()) :: map() | nil
  def get_schema(%{schemas: schemas}, name) when is_binary(name) do
    Map.get(schemas, name)
  end

  @doc """
  Lists all schema names in the builder.

  ## Parameters

  - `builder` - The current SchemaBuilder

  ## Returns

  A list of schema name strings.
  """
  @spec schema_names(t()) :: [String.t()]
  def schema_names(%{schemas: schemas}) do
    Map.keys(schemas)
  end

  @doc """
  Returns the count of schemas in the builder.

  ## Parameters

  - `builder` - The current SchemaBuilder

  ## Returns

  The number of schemas.
  """
  @spec schema_count(t()) :: non_neg_integer()
  def schema_count(%{schemas: schemas}) do
    map_size(schemas)
  end

  @doc """
  Adds all schemas for a resource to the builder.

  This includes:
  - Attributes schema (`{Resource}Attributes`)
  - Response schema (`{Resource}Response`)
  - Relationships schema if the resource has relationships
  - Action-derived input schemas (`{Resource}{Action}Input`)

  ## Options

  - `:input_actions` - List of `{action_name, route}` tuples to derive
    input schemas from (route may be `nil`). Defaults to the resource's
    create and update actions.

  ## Parameters

  - `builder` - The current SchemaBuilder
  - `resource` - The Ash resource module
  - `opts` - Options (see above)

  ## Returns

  Updated SchemaBuilder with all resource schemas added.
  """
  @spec add_resource_schemas(t(), module(), keyword()) :: t()
  def add_resource_schemas(builder, resource, opts \\ [])

  def add_resource_schemas(%{} = builder, resource, opts) when is_atom(resource) do
    builder_opts = [
      mark_seen_fn: &mark_seen/2,
      reserve_resource_name_fn: &reserve_resource_name/2,
      add_schema_fn: &add_schema/3,
      has_schema_fn: &has_schema?/2,
      seen_fn: &seen?/2
    ]

    ResourceSchemas.add_resource_schemas(builder, resource, Keyword.merge(builder_opts, opts))
  end

  @doc "Adds the recursive filter component for a resource."
  @spec add_filter_schema(t(), module(), String.t(), function()) :: t()
  def add_filter_schema(builder, resource, name, add_schema_fn) do
    add_schema_fn.(
      builder,
      "#{name}Filter",
      AshOaskit.FilterBuilder.build_filter_schema(resource,
        recursive?: true,
        version: builder.version
      )
    )
  end

  defp reserve_resource_name(%{resource_names: resource_names} = builder, resource) do
    name = resource_schema_name(resource)

    case Map.get(resource_names, name) do
      nil ->
        builder = %{builder | resource_names: Map.put(resource_names, name, resource)}
        reserve_resource_components(builder, resource, name)

      ^resource ->
        builder

      existing_resource ->
        raise ArgumentError,
              "cannot generate OpenAPI component #{inspect(name)}: " <>
                "#{inspect(existing_resource)} and #{inspect(resource)} resolve to the same " <>
                "resource name; configure distinct AshJsonApi resource types"
    end
  end

  @doc false
  @spec reserve_schema_name(t(), String.t(), term()) :: t()
  def reserve_schema_name(builder, name, owner) do
    owners = Map.get(builder, :schema_owners, %{})

    case Map.fetch(owners, name) do
      {:ok, ^owner} ->
        builder

      {:ok, existing} ->
        raise ArgumentError,
              "OpenAPI component #{inspect(name)} conflicts between #{inspect(existing)} and #{inspect(owner)}"

      :error ->
        if Map.has_key?(builder.schemas, name) do
          raise ArgumentError,
                "OpenAPI component #{inspect(name)} for #{inspect(owner)} conflicts with an existing schema"
        end

        Map.put(builder, :schema_owners, Map.put(owners, name, owner))
    end
  end

  defp reserve_resource_components(builder, resource, name) do
    suffixes = ~w(Attributes Resource Response CollectionResponse Filter)

    suffixes =
      if AshOaskit.SchemaBuilder.RelationshipSchemas.has_relationships?(resource),
        do: ["Relationships" | suffixes],
        else: suffixes

    Enum.reduce(suffixes, builder, fn suffix, acc ->
      reserve_schema_name(acc, name <> suffix, {resource, suffix})
    end)
  end

  @doc """
  Generates the schema name for a resource.

  Extracts the last part of the module name (e.g., `MyApp.Blog.Post` -> `Post`).

  ## Parameters

  - `resource` - The Ash resource module

  ## Returns

  The schema name string.

  ## Examples

      iex> AshOaskit.SchemaBuilder.resource_schema_name(MyApp.Blog.Post)
      "Post"
  """
  @spec resource_schema_name(module()) :: String.t()
  def resource_schema_name(resource) when is_atom(resource) do
    ResourceSchemas.resource_schema_name(resource)
  end
end
