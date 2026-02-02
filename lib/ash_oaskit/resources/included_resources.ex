defmodule AshOaskit.IncludedResources do
  @moduledoc """
  Generates schemas for the `included` array in JSON:API responses.

  This module provides functions to build the `included` member schema
  for compound documents. The `included` array contains resource objects
  that are related to the primary data but were not specifically requested.

  ## Included Resources Structure

  The `included` member is a flat array containing resource objects:

  ```json
  {
    "data": {...},
    "included": [
      {"type": "users", "id": "1", "attributes": {...}},
      {"type": "comments", "id": "1", "attributes": {...}},
      {"type": "comments", "id": "2", "attributes": {...}}
    ]
  }
  ```

  ## Schema Generation

  When multiple resource types can appear in `included`, we use `oneOf`:

  ```yaml
  included:
    type: array
    items:
      oneOf:
        - $ref: '#/components/schemas/UserResource'
        - $ref: '#/components/schemas/CommentResource'
  ```

  ## Include Relationships

  The includable resources are determined by:
  1. Direct relationships on the primary resource
  2. Nested relationships (e.g., `comments.author`)
  3. Configured `includes` in AshJsonApi DSL

  ## Usage

      # Build included array schema for a resource
      AshOaskit.IncludedResources.build_included_schema(Post)

      # Build with explicit includable types
      AshOaskit.IncludedResources.build_included_schema_for_types(["User", "Comment"])

      # Get all includable resources for a resource
      AshOaskit.IncludedResources.get_includable_resources(Post)
  """

  import AshOaskit.Core.SchemaRef, only: [schema_ref: 1, schema_ref_path: 1]

  alias AshOaskit.Config

  @doc """
  Builds the `included` array schema for a resource.

  Analyzes the resource's relationships to determine what types
  can appear in the included array.

  ## Options

  - `:version` - OpenAPI version ("3.1" or "3.0"). Defaults to "3.1".
  - `:max_depth` - Maximum relationship depth to include. Defaults to 2.
  - `:schema_prefix` - Prefix for schema references. Defaults to "".

  ## Examples

      iex> AshOaskit.IncludedResources.build_included_schema(Post)
      %{
        type: :array,
        items: %{
          oneOf: [
            %{"$ref" => "#/components/schemas/UserResource"},
            %{"$ref" => "#/components/schemas/CommentResource"}
          ]
        }
      }
  """
  @spec build_included_schema(module(), keyword()) :: map()
  def build_included_schema(resource, opts \\ []) do
    includable_types = get_includable_resources(resource, opts)

    if Enum.empty?(includable_types) do
      build_empty_included_schema()
    else
      build_included_schema_for_types(includable_types, opts)
    end
  end

  @doc """
  Builds the `included` array schema for explicit resource types.

  ## Options

  - `:version` - OpenAPI version ("3.1" or "3.0"). Defaults to "3.1".
  - `:schema_prefix` - Prefix for schema references. Defaults to "".
  - `:schema_suffix` - Suffix for schema references. Defaults to "Resource".

  ## Examples

      iex> AshOaskit.IncludedResources.build_included_schema_for_types(["User", "Comment"])
      %{
        type: :array,
        items: %{
          oneOf: [
            %{"$ref" => "#/components/schemas/UserResource"},
            %{"$ref" => "#/components/schemas/CommentResource"}
          ]
        }
      }
  """
  @spec build_included_schema_for_types(list(String.t()), keyword()) :: map()
  def build_included_schema_for_types(resource_types, opts \\ [])

  def build_included_schema_for_types([], _opts), do: build_empty_included_schema()

  def build_included_schema_for_types(resource_types, opts) do
    prefix = Keyword.get(opts, :schema_prefix, "")
    suffix = Keyword.get(opts, :schema_suffix, "Resource")

    refs =
      resource_types
      |> Enum.uniq()
      |> Enum.sort()
      |> Enum.map(fn type ->
        schema_ref("#{prefix}#{type}#{suffix}")
      end)

    if length(refs) == 1 do
      %{
        type: :array,
        items: hd(refs),
        description: "Included related resources"
      }
    else
      %{
        type: :array,
        items: %{
          oneOf: refs
        },
        description: "Included related resources"
      }
    end
  end

  @doc """
  Builds an empty included array schema.

  Used when there are no includable relationships.

  ## Examples

      iex> AshOaskit.IncludedResources.build_empty_included_schema()
      %{
        type: :array,
        items: %{},
        maxItems: 0
      }
  """
  @spec build_empty_included_schema() :: map()
  def build_empty_included_schema do
    %{
      type: :array,
      items: %{},
      maxItems: 0,
      description: "No related resources to include"
    }
  end

  @doc """
  Gets all includable resource types for a resource.

  Traverses relationships to find all resource types that could
  potentially appear in the `included` array.

  ## Options

  - `:max_depth` - Maximum relationship depth. Defaults to 2.
  - `:include_paths` - Explicit include paths to follow. If nil, follows all relationships.

  ## Examples

      iex> AshOaskit.IncludedResources.get_includable_resources(Post)
      ["User", "Comment", "Tag"]
  """
  @spec get_includable_resources(module(), keyword()) :: list(String.t())
  def get_includable_resources(resource, opts \\ []) do
    max_depth = Keyword.get(opts, :max_depth, 2)
    include_paths = Keyword.get(opts, :include_paths)

    if include_paths do
      get_resources_from_paths(resource, include_paths)
    else
      get_all_related_resources(resource, max_depth)
    end
  end

  @doc """
  Gets resource types from explicit include paths.

  ## Examples

      iex> AshOaskit.IncludedResources.get_resources_from_paths(Post, [
      ...>   "author",
      ...>   "comments",
      ...>   "comments.author"
      ...> ])
      ["User", "Comment"]
  """
  @spec get_resources_from_paths(module(), list(String.t())) :: list(String.t())
  def get_resources_from_paths(resource, paths) do
    paths
    |> Enum.flat_map(fn path ->
      resolve_path_to_resource(resource, String.split(path, "."))
    end)
    |> Enum.uniq()
  end

  @doc """
  Builds an included schema with discriminator for better tooling support.

  The discriminator helps OpenAPI tools understand which schema to use
  based on the `type` field.

  ## Options

  - `:version` - OpenAPI version ("3.1" or "3.0"). Defaults to "3.1".
  - `:schema_prefix` - Prefix for schema references. Defaults to "".
  - `:schema_suffix` - Suffix for schema references. Defaults to "Resource".

  ## Examples

      iex> types = [{"users", "User"}, {"comments", "Comment"}]
      ...> AshOaskit.IncludedResources.build_included_schema_with_discriminator(types)
      %{
        type: :array,
        items: %{
          oneOf: [...],
          discriminator: %{
            propertyName: "type",
            mapping: %{
              "users" => "#/components/schemas/UserResource",
              "comments" => "#/components/schemas/CommentResource"
            }
          }
        }
      }
  """
  @spec build_included_schema_with_discriminator(list({String.t(), String.t()}), keyword()) ::
          map()
  def build_included_schema_with_discriminator(type_mappings, opts \\ []) do
    prefix = Keyword.get(opts, :schema_prefix, "")
    suffix = Keyword.get(opts, :schema_suffix, "Resource")

    {refs, mapping} =
      Enum.reduce(type_mappings, {[], %{}}, fn {json_api_type, schema_name},
                                               {refs_acc, mapping_acc} ->
        ref_path = schema_ref_path("#{prefix}#{schema_name}#{suffix}")

        {
          [schema_ref("#{prefix}#{schema_name}#{suffix}") | refs_acc],
          Map.put(mapping_acc, json_api_type, ref_path)
        }
      end)

    refs = Enum.reverse(refs)

    %{
      type: :array,
      items: %{
        oneOf: refs,
        discriminator: %{
          propertyName: "type",
          mapping: mapping
        }
      },
      description: "Included related resources"
    }
  end

  @doc """
  Adds the included schema to a response schema.

  ## Options

  - `:resource` - The primary resource to determine includable types.
  - `:types` - Explicit list of includable type names.
  - `:version` - OpenAPI version.

  ## Examples

      iex> response = %{type: :object, properties: %{data: %{}}}
      ...>
      ...> AshOaskit.IncludedResources.add_included_to_response(response,
      ...>   types: ["User", "Comment"]
      ...> )
      %{
        type: :object,
        properties: %{
          data: %{},
          included: %{...}
        }
      }
  """
  @spec add_included_to_response(map(), keyword()) :: map()
  def add_included_to_response(response_schema, opts \\ []) do
    resource = Keyword.get(opts, :resource)
    types = Keyword.get(opts, :types)

    included_schema =
      cond do
        types != nil -> build_included_schema_for_types(types, opts)
        resource != nil -> build_included_schema(resource, opts)
        true -> build_empty_included_schema()
      end

    properties = Map.get(response_schema, :properties, %{})
    updated_properties = Map.put(properties, :included, included_schema)

    Map.put(response_schema, :properties, updated_properties)
  end

  @doc """
  Builds component schemas for the included array.

  Returns schemas that can be added to components/schemas.

  ## Options

  - `:version` - OpenAPI version.
  - `:name_prefix` - Prefix for schema names.

  ## Examples

      iex> AshOaskit.IncludedResources.build_included_component_schemas(["User", "Comment"])
      %{
        "IncludedResources" => %{...}
      }
  """
  @spec build_included_component_schemas(list(String.t()), keyword()) :: map()
  def build_included_component_schemas(resource_types, opts \\ []) do
    prefix = Keyword.get(opts, :name_prefix, "")

    %{
      "#{prefix}IncludedResources" => build_included_schema_for_types(resource_types, opts)
    }
  end

  @doc """
  Checks if a resource has any includable relationships.

  ## Examples

      iex> AshOaskit.IncludedResources.has_includable_resources?(Post)
      true
  """
  @spec has_includable_resources?(module()) :: boolean()
  def has_includable_resources?(resource) do
    relationships = get_relationships(resource)
    not Enum.empty?(relationships)
  end

  @doc """
  Gives the configured includes for a resource from AshJsonApi DSL.

  ## Examples

      iex> AshOaskit.IncludedResources.configured_includes(Post)
      ["author", "comments", "comments.author"]
  """
  @spec configured_includes(module()) :: list(String.t()) | nil
  def configured_includes(resource) do
    Config.includes(resource)
  end

  # Private helper functions

  @spec get_all_related_resources(module(), non_neg_integer()) :: list(String.t())
  defp get_all_related_resources(resource, max_depth) do
    resource
    |> get_related_resources_recursive(max_depth, %{})
    |> Map.keys()
  end

  @spec get_related_resources_recursive(module(), non_neg_integer(), map()) :: map()
  defp get_related_resources_recursive(_resource, 0, seen), do: seen

  defp get_related_resources_recursive(resource, depth, seen) do
    relationships = get_relationships(resource)

    Enum.reduce(relationships, seen, fn rel, acc ->
      destination = get_relationship_destination(rel)

      if destination && not Map.has_key?(acc, destination) do
        name = resource_name(destination)
        updated = Map.put(acc, name, true)
        get_related_resources_recursive(destination, depth - 1, updated)
      else
        acc
      end
    end)
  end

  @spec resolve_path_to_resource(module(), list(String.t())) :: list(String.t())
  defp resolve_path_to_resource(_resource, []), do: []

  defp resolve_path_to_resource(resource, [rel_name | rest]) do
    relationships = get_relationships(resource)

    case find_relationship(relationships, rel_name) do
      nil ->
        []

      rel ->
        destination = get_relationship_destination(rel)

        if destination do
          name = resource_name(destination)

          if Enum.empty?(rest) do
            [name]
          else
            [name | resolve_path_to_resource(destination, rest)]
          end
        else
          []
        end
    end
  end

  @spec get_relationships(module()) :: list(map())
  defp get_relationships(resource) do
    Ash.Resource.Info.relationships(resource)
  end

  @spec get_relationship_destination(map()) :: module() | nil
  defp get_relationship_destination(rel) do
    Map.get(rel, :destination)
  end

  @spec find_relationship(list(map()), String.t()) :: map() | nil
  defp find_relationship(relationships, name) do
    Enum.find(relationships, fn rel -> to_string(rel.name) == name end)
  end

  @spec resource_name(module()) :: String.t()
  defp resource_name(resource) do
    resource
    |> Module.split()
    |> List.last()
  end
end
