defmodule AshOaskit.SchemaBuilder.RelationshipSchemas do
  @moduledoc """
  Relationship schema building for JSON:API responses.

  This module handles the generation of OpenAPI schemas for Ash resource
  relationships. JSON:API relationships include resource linkage (id/type)
  and optional links for navigation.

  ## Overview

  In JSON:API, relationships are represented with:

  - **data** - Resource identifier(s) containing `id` and `type`
  - **links** - Optional `self` and `related` URLs for navigation

  ## Cardinality Handling

  The schema structure differs based on relationship cardinality:

  | Relationship Type | Cardinality | Schema |
  |-------------------|-------------|--------|
  | `belongs_to` | `:one` | Single identifier (nullable) |
  | `has_one` | `:one` | Single identifier (nullable) |
  | `has_many` | `:many` | Array of identifiers |
  | `many_to_many` | `:many` | Array of identifiers |

  ## Nullable Handling by Version

  For to-one relationships, null values are handled differently by version:

  - **OpenAPI 3.0**: Uses `"nullable": true` on the identifier schema
  - **OpenAPI 3.1**: Uses `oneOf` with the identifier and `{"type": "null"}`

  ## Cycle Detection

  When building relationship schemas, the module checks if the destination
  resource has been seen. If not, it triggers schema generation for that
  resource to ensure all referenced schemas exist in the spec.

  ## Usage

      # Build a relationship schema
      {schema, builder} = RelationshipSchemas.build_relationship_schema(builder, rel)

      # Add all relationships for a resource
      builder = RelationshipSchemas.add_relationships_schema(builder, resource, "Post")
  """

  import AshOaskit.Schemas.Nullable, only: [make_nullable_oneof: 2]

  @doc """
  Adds the relationships schema for a resource if it has any.

  Creates a schema containing all public relationships with their
  data (resource linkage) and links properties.

  ## Parameters

  - `builder` - The SchemaBuilder accumulator
  - `resource` - The Ash resource module
  - `schema_name` - Base name for the schema
  - `add_schema_fn` - Function to add schemas to builder

  ## Returns

  Updated builder with relationships schema added (if resource has relationships).
  """
  @spec add_relationships_schema(map(), module(), String.t(), keyword()) :: map()
  def add_relationships_schema(builder, resource, schema_name, opts) do
    add_schema_fn = Keyword.fetch!(opts, :add_schema_fn)
    seen_fn = Keyword.fetch!(opts, :seen_fn)
    add_resource_schemas_fn = Keyword.fetch!(opts, :add_resource_schemas_fn)

    relationships = get_public_relationships(resource)

    if Enum.empty?(relationships) do
      builder
    else
      {properties, builder} =
        Enum.reduce(relationships, {%{}, builder}, fn rel, {props, bldr} ->
          {rel_schema, bldr} =
            build_relationship_schema(bldr, rel, seen_fn, add_resource_schemas_fn)

          {Map.put(props, rel.name, rel_schema), bldr}
        end)

      schema = %{
        type: :object,
        properties: properties
      }

      add_schema_fn.(builder, "#{schema_name}Relationships", schema)
    end
  end

  @doc """
  Builds a relationship schema with data and links.

  Creates a JSON:API compliant relationship object schema that includes
  the resource linkage (data) and navigation links.

  ## Parameters

  - `builder` - The SchemaBuilder accumulator
  - `relationship` - The relationship struct from Ash.Resource.Info

  ## Returns

  A tuple of `{relationship_schema, updated_builder}`.

  ## Example Output

  For a to-many relationship:

      {
        %{
          "type" => "object",
          "properties" => %{
            "data" => %{
              "type" => "array",
              "items" => %{
                "type" => "object",
                "properties" => %{
                  "id" => %{"type" => "string"},
                  "type" => %{"type" => "string", "enum" => ["posts"]}
                },
                "required" => ["id", "type"]
              }
            },
            "links" => %{...}
          }
        },
        builder
      }
  """
  @spec build_relationship_schema(map(), map(), function(), function()) :: {map(), map()}
  def build_relationship_schema(builder, relationship, seen_fn, add_resource_schemas_fn) do
    rel_resource = relationship.destination
    rel_type = get_json_api_type(rel_resource)
    cardinality = relationship_cardinality(relationship)

    # Resource identifier schema
    identifier_schema = %{
      type: :object,
      properties: %{
        id: %{type: :string},
        type: %{type: :string, enum: [rel_type]}
      },
      required: ["id", "type"]
    }

    # Data schema based on cardinality
    data_schema =
      case cardinality do
        :many ->
          %{
            type: :array,
            items: identifier_schema
          }

        :one ->
          make_nullable_oneof(identifier_schema, builder.version)
      end

    # Relationship object with data and links
    rel_schema = %{
      type: :object,
      properties: %{
        data: data_schema,
        links: %{
          type: :object,
          properties: %{
            related: %{type: :string, format: :uri},
            self: %{type: :string, format: :uri}
          }
        }
      }
    }

    # Ensure destination resource schemas exist
    builder =
      if seen_fn.(builder, rel_resource) do
        builder
      else
        add_resource_schemas_fn.(builder, rel_resource)
      end

    {rel_schema, builder}
  end

  @doc """
  Determines if a relationship is to-many or to-one.

  Checks the `cardinality` field first (Ash 3.x), falling back to
  relationship type for compatibility.

  ## Parameters

  - `rel` - The relationship struct

  ## Returns

  `:one` or `:many`.

  ## Examples

      iex> RelationshipSchemas.relationship_cardinality(%{cardinality: :many})
      :many

      iex> RelationshipSchemas.relationship_cardinality(%{type: :belongs_to})
      :one
  """
  @spec relationship_cardinality(map()) :: :one | :many
  def relationship_cardinality(rel) do
    case Map.get(rel, :cardinality) do
      :many -> :many
      :one -> :one
      nil -> if Map.get(rel, :type) in [:has_many, :many_to_many], do: :many, else: :one
    end
  end

  @doc """
  Gets public (non-private) relationships for a resource.

  ## Parameters

  - `resource` - The Ash resource module

  ## Returns

  List of public relationship structs.
  """
  @spec get_public_relationships(module()) :: [map()]
  def get_public_relationships(resource) do
    resource
    |> Ash.Resource.Info.relationships()
    |> Enum.reject(fn rel -> Map.get(rel, :private?, false) end)
  end

  @doc """
  Checks if a resource has any public relationships.

  ## Parameters

  - `resource` - The Ash resource module

  ## Returns

  `true` if the resource has relationships, `false` otherwise.
  """
  @spec has_relationships?(module()) :: boolean()
  def has_relationships?(resource) do
    not Enum.empty?(get_public_relationships(resource))
  end

  @doc """
  Gets the JSON:API type for a resource.

  Uses the configured type from AshJsonApi if available,
  otherwise derives from the module name.

  ## Parameters

  - `resource` - The Ash resource module

  ## Returns

  The JSON:API type string.

  ## Examples

      iex> RelationshipSchemas.get_json_api_type(MyApp.BlogPost)
      # From AshJsonApi config or derived from module name
      "blog_posts"
  """
  @spec get_json_api_type(module()) :: String.t()
  def get_json_api_type(resource) do
    case AshJsonApi.Resource.Info.type(resource) do
      nil -> resource |> Module.split() |> List.last() |> Macro.underscore()
      type -> type
    end
  end
end
