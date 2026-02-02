defmodule AshOaskit.ResourceIdentifier do
  @moduledoc """
  Generates JSON:API resource identifier schemas for OpenAPI specifications.

  This module provides functions to build resource identifier objects,
  which are used in relationship linkage data. Resource identifiers
  contain just the `type` and `id` of a resource, optionally with `meta`.

  ## Resource Identifier Structure

  A resource identifier object contains:
  - `type` - The type of the resource (required)
  - `id` - The unique identifier of the resource (required)
  - `meta` - Optional non-standard meta information

  ```json
  {
    "type": "posts",
    "id": "1",
    "meta": {
      "created_at": "2024-01-01T00:00:00Z"
    }
  }
  ```

  ## Relationship Linkage

  Resource identifiers are used in relationship data:

  ### To-One Relationship
  ```json
  {
    "data": {"type": "author", "id": "1"}
  }
  ```

  ### To-Many Relationship
  ```json
  {
    "data": [
      {"type": "comment", "id": "1"},
      {"type": "comment", "id": "2"}
    ]
  }
  ```

  ## OpenAPI Version Differences

  - **OpenAPI 3.1**: Uses `type: ["object", "null"]` for nullable to-one
  - **OpenAPI 3.0**: Uses `nullable: true` for nullable to-one

  ## Usage

      # Build a resource identifier schema
      AshOaskit.ResourceIdentifier.build_identifier_schema("posts")

      # Build a nullable identifier (for optional to-one relationships)
      AshOaskit.ResourceIdentifier.build_nullable_identifier_schema("author", version: "3.1")

      # Build linkage for to-many relationship
      AshOaskit.ResourceIdentifier.build_to_many_linkage_schema("comments")
  """

  import AshOaskit.Schemas.Nullable, only: [make_nullable_oneof: 2]

  @doc """
  Builds a resource identifier object schema.

  ## Options

  - `:version` - OpenAPI version ("3.1" or "3.0"). Defaults to "3.1".
  - `:include_meta` - Whether to include optional meta field. Defaults to true.

  ## Examples

      iex> AshOaskit.ResourceIdentifier.build_identifier_schema("posts")
      %{
        type: :object,
        required: ["type", "id"],
        properties: %{
          type: %{type: :string, enum: ["posts"]},
          id: %{type: :string},
          meta: %{type: :object, additionalProperties: true}
        }
      }
  """
  @spec build_identifier_schema(String.t(), keyword()) :: map()
  def build_identifier_schema(resource_type, opts \\ []) do
    include_meta = Keyword.get(opts, :include_meta, true)

    properties = %{
      type: %{
        type: :string,
        enum: [resource_type],
        description: "Resource type"
      },
      id: %{
        type: :string,
        description: "Resource identifier"
      }
    }

    properties =
      if include_meta do
        Map.put(properties, :meta, %{
          type: :object,
          additionalProperties: true,
          description: "Non-standard meta information about the resource identifier"
        })
      else
        properties
      end

    %{
      type: :object,
      required: ["type", "id"],
      properties: properties,
      description: "Resource identifier for #{resource_type}"
    }
  end

  @doc """
  Builds a nullable resource identifier schema for optional to-one relationships.

  ## Options

  - `:version` - OpenAPI version ("3.1" or "3.0"). Defaults to "3.1".
  - `:include_meta` - Whether to include optional meta field. Defaults to true.

  ## Examples

      iex> schema =
      ...>   AshOaskit.ResourceIdentifier.build_nullable_identifier_schema("author", version: "3.1")
      ...>
      ...> Map.has_key?(schema, :oneOf)
      true
      iex> length(schema[:oneOf])
      2
  """
  @spec build_nullable_identifier_schema(String.t(), keyword()) :: map()
  def build_nullable_identifier_schema(resource_type, opts \\ []) do
    version = Keyword.get(opts, :version, "3.1")
    identifier = build_identifier_schema(resource_type, opts)

    schema = make_nullable_oneof(identifier, version)

    if version == "3.1" do
      Map.put(schema, :description, "Resource identifier for #{resource_type} (nullable)")
    else
      schema
    end
  end

  @doc """
  Builds a to-one relationship linkage schema.

  To-one relationships can be null (when the relationship doesn't exist)
  or a single resource identifier.

  ## Options

  - `:version` - OpenAPI version ("3.1" or "3.0"). Defaults to "3.1".
  - `:required` - Whether the relationship is required. Defaults to false.
  - `:include_meta` - Whether to include meta in identifiers. Defaults to true.

  ## Examples

      AshOaskit.ResourceIdentifier.build_to_one_linkage_schema("author")
      # => %{
      #      oneOf: [
      #        %{type: :null},
      #        %{...resource_identifier...}
      #      ]
      #    }
  """
  @spec build_to_one_linkage_schema(String.t(), keyword()) :: map()
  def build_to_one_linkage_schema(resource_type, opts \\ []) do
    required = Keyword.get(opts, :required, false)

    if required do
      build_identifier_schema(resource_type, opts)
    else
      build_nullable_identifier_schema(resource_type, opts)
    end
  end

  @doc """
  Builds a to-many relationship linkage schema.

  To-many relationships are represented as arrays of resource identifiers.

  ## Options

  - `:version` - OpenAPI version ("3.1" or "3.0"). Defaults to "3.1".
  - `:include_meta` - Whether to include meta in identifiers. Defaults to true.

  ## Examples

      AshOaskit.ResourceIdentifier.build_to_many_linkage_schema("comments")
      # => %{
      #      type: :array,
      #      items: %{...resource_identifier...}
      #    }
  """
  @spec build_to_many_linkage_schema(String.t(), keyword()) :: map()
  def build_to_many_linkage_schema(resource_type, opts \\ []) do
    identifier = build_identifier_schema(resource_type, opts)

    %{
      type: :array,
      items: identifier,
      description: "Array of #{resource_type} resource identifiers"
    }
  end

  @doc """
  Builds a complete relationship object schema with data and links.

  The relationship object contains:
  - `data` - Resource linkage (to-one or to-many)
  - `links` - Relationship links (self, related)
  - `meta` - Optional relationship meta

  ## Options

  - `:version` - OpenAPI version ("3.1" or "3.0"). Defaults to "3.1".
  - `:cardinality` - `:to_one` or `:to_many`. Defaults to `:to_one`.
  - `:include_links` - Whether to include links. Defaults to true.
  - `:include_meta` - Whether to include meta. Defaults to true.

  ## Examples

      AshOaskit.ResourceIdentifier.build_relationship_object_schema("author",
        cardinality: :to_one
      )
      # => %{
      #      type: :object,
      #      properties: %{
      #        data: %{...to_one_linkage...},
      #        links: %{...relationship_links...},
      #        meta: %{...meta...}
      #      }
      #    }
  """
  @spec build_relationship_object_schema(String.t(), keyword()) :: map()
  def build_relationship_object_schema(resource_type, opts \\ []) do
    version = Keyword.get(opts, :version, "3.1")
    cardinality = Keyword.get(opts, :cardinality, :to_one)
    include_links = Keyword.get(opts, :include_links, true)
    include_meta = Keyword.get(opts, :include_meta, true)

    data_schema =
      case cardinality do
        :to_many -> build_to_many_linkage_schema(resource_type, opts)
        _ -> build_to_one_linkage_schema(resource_type, opts)
      end

    properties = %{
      data: data_schema
    }

    properties =
      if include_links do
        Map.put(properties, :links, build_relationship_links_schema(version))
      else
        properties
      end

    properties =
      if include_meta do
        Map.put(properties, :meta, %{
          type: :object,
          additionalProperties: true,
          description: "Non-standard meta information about the relationship"
        })
      else
        properties
      end

    %{
      type: :object,
      properties: properties,
      description: "Relationship object for #{resource_type}"
    }
  end

  @doc """
  Builds a relationships object schema containing multiple relationships.

  ## Options

  - `:version` - OpenAPI version ("3.1" or "3.0"). Defaults to "3.1".

  ## Examples

      relationships = [
        {"author", :to_one},
        {"comments", :to_many}
      ]

      AshOaskit.ResourceIdentifier.build_relationships_object_schema(relationships)
      # => %{
      #      type: :object,
      #      properties: %{
      #        "author" => %{...to_one_relationship...},
      #        "comments" => %{...to_many_relationship...}
      #      }
      #    }
  """
  @spec build_relationships_object_schema(list({String.t(), atom()}), keyword()) :: map()
  def build_relationships_object_schema(relationships, opts \\ []) do
    properties =
      Map.new(relationships, fn {name, cardinality} ->
        {name,
         build_relationship_object_schema(name, Keyword.put(opts, :cardinality, cardinality))}
      end)

    %{
      type: :object,
      properties: properties,
      description: "Resource relationships"
    }
  end

  @doc """
  Builds resource linkage data schema for relationship requests.

  This is used in request bodies when modifying relationships.

  ## Options

  - `:version` - OpenAPI version ("3.1" or "3.0"). Defaults to "3.1".
  - `:cardinality` - `:to_one` or `:to_many`. Determines single vs array.

  ## Examples

      iex> schema =
      ...>   AshOaskit.ResourceIdentifier.build_linkage_data_schema("comments",
      ...>     cardinality: :to_many
      ...>   )
      ...>
      ...> schema[:type]
      :object
      iex> "data" in schema[:required]
      true
  """
  @spec build_linkage_data_schema(String.t(), keyword()) :: map()
  def build_linkage_data_schema(resource_type, opts \\ []) do
    cardinality = Keyword.get(opts, :cardinality, :to_one)

    data_schema =
      case cardinality do
        :to_many -> build_to_many_linkage_schema(resource_type, opts)
        _ -> build_to_one_linkage_schema(resource_type, opts)
      end

    %{
      type: :object,
      required: ["data"],
      properties: %{
        data: data_schema
      },
      description: "Relationship linkage data for #{resource_type}"
    }
  end

  @doc """
  Builds component schemas for resource identifiers.

  Generates reusable schema definitions for the components section.

  ## Options

  - `:version` - OpenAPI version ("3.1" or "3.0"). Defaults to "3.1".
  - `:name_prefix` - Prefix for schema names. Defaults to "".

  ## Examples

      iex> AshOaskit.ResourceIdentifier.build_identifier_component_schemas("Post")
      %{
        "PostIdentifier" => %{...},
        "PostRelationshipLinks" => %{...}
      }
  """
  @spec build_identifier_component_schemas(String.t(), keyword()) :: map()
  def build_identifier_component_schemas(resource_name, opts \\ []) do
    version = Keyword.get(opts, :version, "3.1")
    prefix = Keyword.get(opts, :name_prefix, "")
    resource_type = String.downcase(resource_name)

    %{
      "#{prefix}#{resource_name}Identifier" => build_identifier_schema(resource_type, opts),
      "#{prefix}#{resource_name}IdentifierArray" =>
        build_to_many_linkage_schema(resource_type, opts),
      "#{prefix}RelationshipLinks" => build_relationship_links_schema(version)
    }
  end

  @doc """
  Builds generic resource identifier schemas.

  These can be used when the specific resource type isn't known
  or for polymorphic relationships.

  ## Options

  - `:version` - OpenAPI version ("3.1" or "3.0"). Defaults to "3.1".

  ## Examples

      iex> AshOaskit.ResourceIdentifier.build_generic_identifier_schema()
      %{
        type: :object,
        required: ["type", "id"],
        properties: %{
          type: %{type: :string},
          id: %{type: :string},
          meta: %{...}
        }
      }
  """
  @spec build_generic_identifier_schema(keyword()) :: map()
  def build_generic_identifier_schema(_opts \\ []) do
    %{
      type: :object,
      required: ["type", "id"],
      properties: %{
        type: %{
          type: :string,
          description: "Resource type"
        },
        id: %{
          type: :string,
          description: "Resource identifier"
        },
        meta: %{
          type: :object,
          additionalProperties: true,
          description: "Non-standard meta information"
        }
      },
      description: "Generic resource identifier"
    }
  end

  @doc """
  Builds a polymorphic identifier schema for relationships
  that can reference multiple resource types.

  ## Examples

      iex> AshOaskit.ResourceIdentifier.build_polymorphic_identifier_schema(["posts", "comments"])
      %{
        type: :object,
        required: ["type", "id"],
        properties: %{
          type: %{type: :string, enum: ["posts", "comments"]},
          id: %{type: :string}
        }
      }
  """
  @spec build_polymorphic_identifier_schema(list(String.t()), keyword()) :: map()
  def build_polymorphic_identifier_schema(resource_types, _opts \\ []) do
    %{
      type: :object,
      required: ["type", "id"],
      properties: %{
        type: %{
          type: :string,
          enum: resource_types,
          description: "Resource type (one of: #{Enum.join(resource_types, ", ")})"
        },
        id: %{
          type: :string,
          description: "Resource identifier"
        },
        meta: %{
          type: :object,
          additionalProperties: true,
          description: "Non-standard meta information"
        }
      },
      description: "Polymorphic resource identifier"
    }
  end

  @spec build_relationship_links_schema(String.t()) :: map()
  defp build_relationship_links_schema(_version) do
    %{
      type: :object,
      properties: %{
        self: %{
          type: :string,
          format: :uri,
          description: "URL for the relationship itself"
        },
        related: %{
          type: :string,
          format: :uri,
          description: "URL for the related resource(s)"
        }
      },
      description: "Relationship navigation links"
    }
  end
end
