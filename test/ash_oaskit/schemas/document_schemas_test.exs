defmodule AshOaskit.SchemaBuilder.DocumentSchemasTest do
  use ExUnit.Case, async: true
  alias AshOaskit.SchemaBuilder
  alias AshOaskit.SchemaBuilder.DocumentSchemas

  test "resource objects and document envelopes remain separate" do
    builder =
      DocumentSchemas.add_response_schema(
        SchemaBuilder.new(),
        AshOaskit.Test.Post,
        "Post",
        &SchemaBuilder.add_schema/3
      )

    resource = SchemaBuilder.get_schema(builder, "PostResource")
    member = SchemaBuilder.get_schema(builder, "PostResponse")
    collection = SchemaBuilder.get_schema(builder, "PostCollectionResponse")
    assert member.properties.data == resource
    assert collection.properties.data.items == %{"$ref" => "#/components/schemas/PostResource"}
    assert Map.has_key?(member.properties, :jsonapi)
    refute Map.has_key?(resource.properties, :data)
  end
end
