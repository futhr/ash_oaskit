defmodule AshOaskit.SchemaBuilder.DocumentSchemas do
  @moduledoc "Builds JSON:API resource objects and member/collection document components."
  import AshOaskit.Core.SchemaRef, only: [schema_ref: 1]
  alias AshOaskit.IncludedResources
  alias AshOaskit.ResponseLinks
  alias AshOaskit.ResponseMeta
  alias AshOaskit.SchemaBuilder.RelationshipSchemas

  @doc "Adds resource, member response, and collection response schemas to a builder."
  @spec add_response_schema(map(), module(), String.t(), function()) :: map()
  def add_response_schema(builder, resource, schema_name, add_schema_fn) do
    json_api_type = RelationshipSchemas.get_json_api_type(resource)

    data_schema = %{
      type: :object,
      properties: %{
        id: %{type: :string},
        type: %{type: :string, enum: [json_api_type]},
        attributes: schema_ref("#{schema_name}Attributes"),
        links: ResponseLinks.build_resource_links_schema(),
        meta: ResponseMeta.build_resource_meta_schema()
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
      required: ["data"],
      properties: %{
        data: data_schema,
        links: ResponseLinks.build_document_links_schema(version: builder.version),
        meta: ResponseMeta.build_resource_meta_schema(),
        jsonapi: ResponseMeta.build_jsonapi_object_schema(supported_versions: ["1.0"]),
        included: IncludedResources.build_included_schema(resource)
      }
    }

    collection_schema =
      put_in(response_schema, [:properties, :data], %{
        type: :array,
        items: schema_ref("#{schema_name}Resource")
      })

    collection_schema =
      collection_schema
      |> put_in(
        [:properties, :links],
        ResponseLinks.build_collection_links_schema(version: builder.version)
      )
      |> put_in([:properties, :meta], ResponseMeta.build_ash_page_meta_schema())

    builder
    |> add_schema_fn.("#{schema_name}Resource", data_schema)
    |> add_schema_fn.("#{schema_name}Response", response_schema)
    |> add_schema_fn.("#{schema_name}CollectionResponse", collection_schema)
  end
end
