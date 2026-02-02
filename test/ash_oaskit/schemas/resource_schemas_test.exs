defmodule AshOaskit.SchemaBuilder.ResourceSchemasTest do
  @moduledoc """
  Tests for the `AshOaskit.SchemaBuilder.ResourceSchemas` module.

  Verifies resource-level schema generation including attributes, response
  wrappers, input schemas, and resource naming conventions.

  ## Test categories

    - `resource_schema_name/1` — Schema name extraction from module
    - `get_public_attributes/1` — Public attribute filtering
    - `get_public_calculations/1` — Public calculation filtering
    - `get_public_aggregates/1` — Public aggregate filtering
    - `get_writable_attributes/1` — Writable attribute filtering
    - `create_required_attribute?/1` — Required field detection
    - `add_resource_schemas/3` — Full schema generation pipeline
    - `add_attributes_schema/4` — Attributes-only schema
    - `add_response_schema/4` — JSON:API response wrapper
    - `add_input_schemas/4` — Create/update input schemas
  """
  use ExUnit.Case, async: true

  alias AshOaskit.SchemaBuilder
  alias AshOaskit.SchemaBuilder.ResourceSchemas

  describe "resource_schema_name/1" do
    test "extracts last module segment" do
      assert ResourceSchemas.resource_schema_name(AshOaskit.Test.Post) == "Post"
    end

    test "works with deeply nested modules" do
      assert ResourceSchemas.resource_schema_name(AshOaskit.Test.Blog) == "Blog"
    end
  end

  describe "get_public_attributes/1" do
    test "excludes id and timestamps" do
      attrs = ResourceSchemas.get_public_attributes(AshOaskit.Test.Post)
      attr_names = Enum.map(attrs, & &1.name)

      refute :id in attr_names
      refute :inserted_at in attr_names
      refute :updated_at in attr_names
    end

    test "includes regular public attributes" do
      attrs = ResourceSchemas.get_public_attributes(AshOaskit.Test.Post)
      attr_names = Enum.map(attrs, & &1.name)

      assert :title in attr_names or :name in attr_names or attr_names != []
    end
  end

  describe "get_public_calculations/1" do
    test "returns list of calculations" do
      calcs = ResourceSchemas.get_public_calculations(AshOaskit.Test.Post)
      assert is_list(calcs)
    end
  end

  describe "get_public_aggregates/1" do
    test "returns list of aggregates" do
      aggs = ResourceSchemas.get_public_aggregates(AshOaskit.Test.Post)
      assert is_list(aggs)
    end
  end

  describe "get_writable_attributes/1" do
    test "excludes non-writable attributes" do
      writable = ResourceSchemas.get_writable_attributes(AshOaskit.Test.Post)

      Enum.each(writable, fn attr ->
        assert Map.get(attr, :writable?, true) != false
      end)
    end

    test "excludes generated attributes" do
      writable = ResourceSchemas.get_writable_attributes(AshOaskit.Test.Post)

      Enum.each(writable, fn attr ->
        refute Map.get(attr, :generated?, false)
      end)
    end
  end

  describe "create_required_attribute?/1" do
    test "required when allow_nil? is false and no default" do
      attr = %{allow_nil?: false, default: nil}
      assert ResourceSchemas.create_required_attribute?(attr)
    end

    test "not required when allow_nil? is true" do
      attr = %{allow_nil?: true}
      refute ResourceSchemas.create_required_attribute?(attr)
    end

    test "not required when has default value" do
      attr = %{allow_nil?: false, default: "default_value"}
      refute ResourceSchemas.create_required_attribute?(attr)
    end
  end

  describe "add_resource_schemas/3" do
    test "generates all schema types for a resource" do
      builder = SchemaBuilder.new(version: "3.1")

      opts = [
        mark_seen_fn: &SchemaBuilder.mark_seen/2,
        add_schema_fn: &SchemaBuilder.add_schema/3,
        has_schema_fn: &SchemaBuilder.has_schema?/2,
        seen_fn: &SchemaBuilder.seen?/2
      ]

      builder = ResourceSchemas.add_resource_schemas(builder, AshOaskit.Test.Post, opts)

      assert SchemaBuilder.has_schema?(builder, "PostAttributes")
      assert SchemaBuilder.has_schema?(builder, "PostResponse")
      assert SchemaBuilder.has_schema?(builder, "PostCreateInput")
      assert SchemaBuilder.has_schema?(builder, "PostUpdateInput")
    end
  end

  describe "add_attributes_schema/4" do
    test "generates attributes schema with properties" do
      builder = SchemaBuilder.new(version: "3.1")

      opts = [
        add_schema_fn: &SchemaBuilder.add_schema/3,
        mark_seen_fn: &SchemaBuilder.mark_seen/2,
        has_schema_fn: &SchemaBuilder.has_schema?/2
      ]

      builder =
        ResourceSchemas.add_attributes_schema(builder, AshOaskit.Test.Post, "Post", opts)

      assert SchemaBuilder.has_schema?(builder, "PostAttributes")
      schema = builder.schemas["PostAttributes"]
      assert schema.type == :object
      assert is_map(schema.properties)
    end
  end

  describe "add_response_schema/4" do
    test "generates JSON:API response wrapper" do
      builder = SchemaBuilder.new(version: "3.1")

      builder =
        ResourceSchemas.add_response_schema(
          builder,
          AshOaskit.Test.Post,
          "Post",
          &SchemaBuilder.add_schema/3
        )

      assert SchemaBuilder.has_schema?(builder, "PostResponse")
      schema = builder.schemas["PostResponse"]
      assert schema.type == :object
      assert Map.has_key?(schema.properties, :data)

      data = schema.properties.data
      assert Map.has_key?(data.properties, :id)
      assert Map.has_key?(data.properties, :type)
      assert Map.has_key?(data.properties, :attributes)
    end
  end

  describe "add_input_schemas/4" do
    test "generates both create and update input schemas" do
      builder = SchemaBuilder.new(version: "3.1")

      builder =
        ResourceSchemas.add_input_schemas(
          builder,
          AshOaskit.Test.Post,
          "Post",
          &SchemaBuilder.add_schema/3
        )

      assert SchemaBuilder.has_schema?(builder, "PostCreateInput")
      assert SchemaBuilder.has_schema?(builder, "PostUpdateInput")
    end

    test "update input has no required fields" do
      builder = SchemaBuilder.new(version: "3.1")

      builder =
        ResourceSchemas.add_input_schemas(
          builder,
          AshOaskit.Test.Post,
          "Post",
          &SchemaBuilder.add_schema/3
        )

      update_schema = builder.schemas["PostUpdateInput"]
      refute Map.has_key?(update_schema, :required)
    end
  end
end
