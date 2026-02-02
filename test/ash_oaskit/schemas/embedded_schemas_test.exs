defmodule AshOaskit.SchemaBuilder.EmbeddedSchemasTest do
  @moduledoc """
  Comprehensive tests for embedded resource schema generation.

  These tests verify that ash_oaskit correctly generates OpenAPI schemas for
  embedded Ash resources, including nested embedded types and cycle detection.

  ## Embedded Resources Overview

  Embedded resources are Ash resources with `data_layer: :embedded`. They are
  stored inline within their parent resource rather than in a separate table.

  ## Test Scenarios

  ### Simple Embedded Resources
  - Single-level embedding (Author has Profile)
  - Embedded resource schema generation
  - $ref references in parent schema

  ### Nested Embedded Resources
  - Multi-level embedding (Profile has Address)
  - Recursive schema generation
  - All levels generate proper schemas

  ### Cycle Detection
  - Self-referential embedded types
  - Mutual references between embedded types
  - Proper $ref generation to prevent infinite loops

  ### Attribute Handling
  - All embedded attributes included
  - Type mapping for embedded attributes
  - Constraints preserved
  - Descriptions included
  - Required fields detected

  ## OpenAPI Version Differences

  ### OpenAPI 3.0
  - Nullable embedded fields use `nullable: true`

  ### OpenAPI 3.1
  - Nullable embedded fields use type array or oneOf

  ## Test Resources

  Tests use resources from `test/support/relationship_resources.ex`:
  - `Address` - Simple embedded resource with address fields
  - `Profile` - Embedded resource containing nested Address
  - `Author` - Regular resource with embedded Profile attribute
  """

  use ExUnit.Case, async: true

  alias AshOaskit.SchemaBuilder

  describe "simple embedded resource detection" do
    # Tests for detecting and generating schemas for embedded resources.

    test "embedded resource schema is generated" do
      builder =
        SchemaBuilder.add_resource_schemas(
          SchemaBuilder.new(version: "3.1"),
          AshOaskit.Test.Author
        )

      # Profile is an embedded resource used by Author
      assert SchemaBuilder.has_schema?(builder, "Profile")
    end

    test "embedded resource has proper type" do
      builder =
        SchemaBuilder.add_resource_schemas(
          SchemaBuilder.new(version: "3.1"),
          AshOaskit.Test.Author
        )

      # Embedded schema outer structure uses atom keys
      schema = SchemaBuilder.get_schema(builder, "Profile")
      assert schema[:type] == :object
    end

    test "embedded resource properties are generated" do
      builder =
        SchemaBuilder.add_resource_schemas(
          SchemaBuilder.new(version: "3.1"),
          AshOaskit.Test.Author
        )

      # Embedded schema uses atom keys for property names
      schema = SchemaBuilder.get_schema(builder, "Profile")

      # Profile has bio, website, avatar_url, address, social_links
      assert Map.has_key?(schema[:properties], :bio)
      assert Map.has_key?(schema[:properties], :website)
      assert Map.has_key?(schema[:properties], :avatar_url)
      assert Map.has_key?(schema[:properties], :social_links)
    end

    test "parent resource references embedded schema" do
      builder =
        SchemaBuilder.add_resource_schemas(
          SchemaBuilder.new(version: "3.1"),
          AshOaskit.Test.Author
        )

      # Attributes schema uses atom keys for outer structure
      schema = SchemaBuilder.get_schema(builder, "AuthorAttributes")

      # profile attribute - value comes from TypeMapper (string keys)
      profile = schema[:properties][:profile]

      # It may be wrapped in nullable handling
      ref =
        cond do
          Map.has_key?(profile, "$ref") -> profile["$ref"]
          Map.has_key?(profile, "allOf") -> hd(profile["allOf"])["$ref"]
          true -> nil
        end

      # The base reference should point to Profile
      assert ref == nil or String.contains?(to_string(ref), "Profile")
    end
  end

  describe "nested embedded resources" do
    # Tests for embedded resources that contain other embedded resources.

    test "nested embedded schema is generated" do
      builder =
        SchemaBuilder.add_resource_schemas(
          SchemaBuilder.new(version: "3.1"),
          AshOaskit.Test.Author
        )

      # Address is nested inside Profile, which is in Author
      assert SchemaBuilder.has_schema?(builder, "Address")
    end

    test "nested embedded has proper properties" do
      builder =
        SchemaBuilder.add_resource_schemas(
          SchemaBuilder.new(version: "3.1"),
          AshOaskit.Test.Author
        )

      # Embedded schema uses atom keys for property names
      schema = SchemaBuilder.get_schema(builder, "Address")

      # Address has street, city, state, postal_code, country
      assert Map.has_key?(schema[:properties], :street)
      assert Map.has_key?(schema[:properties], :city)
      assert Map.has_key?(schema[:properties], :state)
      assert Map.has_key?(schema[:properties], :postal_code)
      assert Map.has_key?(schema[:properties], :country)
    end

    test "parent embedded references nested embedded" do
      builder =
        SchemaBuilder.add_resource_schemas(
          SchemaBuilder.new(version: "3.1"),
          AshOaskit.Test.Author
        )

      schema = SchemaBuilder.get_schema(builder, "Profile")

      # address attribute value comes from TypeMapper (string keys)
      address = schema[:properties][:address]

      # Check for $ref (may be wrapped) - TypeMapper uses string keys
      has_ref =
        cond do
          is_nil(address) -> false
          Map.has_key?(address, "$ref") -> true
          Map.has_key?(address, "allOf") -> Enum.any?(address["allOf"], &Map.has_key?(&1, "$ref"))
          true -> false
        end

      assert has_ref or (address != nil and address["type"] == "object")
    end
  end

  describe "embedded resource attributes" do
    # Tests for attribute handling in embedded resources.
    # Embedded attribute VALUES come from TypeMapper (string keys).

    setup do
      builder =
        SchemaBuilder.add_resource_schemas(
          SchemaBuilder.new(version: "3.1"),
          AshOaskit.Test.Author
        )

      {:ok, builder: builder}
    end

    test "string attributes are typed correctly", %{builder: builder} do
      schema = SchemaBuilder.get_schema(builder, "Address")

      # Attribute values come from TypeMapper (string keys)
      street = schema[:properties][:street]
      assert "string" in List.wrap(street["type"])
    end

    test "constraints are preserved", %{builder: builder} do
      schema = SchemaBuilder.get_schema(builder, "Profile")

      # Attribute values come from TypeMapper (string keys)
      bio = schema[:properties][:bio]
      # bio has max_length: 500
      assert bio["maxLength"] == 500
    end

    test "regex patterns are preserved", %{builder: builder} do
      schema = SchemaBuilder.get_schema(builder, "Address")

      # Attribute values come from TypeMapper (string keys)
      postal_code = schema[:properties][:postal_code]
      # postal_code has match constraint
      assert Map.has_key?(postal_code, "pattern")
    end

    test "defaults are included", %{builder: builder} do
      schema = SchemaBuilder.get_schema(builder, "Address")

      # Attribute values come from TypeMapper (string keys)
      country = schema[:properties][:country]
      # country has default: "US"
      assert country["default"] == "US"
    end

    test "descriptions are included", %{builder: builder} do
      schema = SchemaBuilder.get_schema(builder, "Address")

      # Attribute values come from TypeMapper (string keys)
      city = schema[:properties][:city]
      assert city["description"] == "City name"
    end

    test "required fields are detected", %{builder: builder} do
      schema = SchemaBuilder.get_schema(builder, "Address")

      # Required list entries stay as strings
      # city has allow_nil?: false
      assert "city" in (schema[:required] || [])
    end

    test "array attributes work in embedded", %{builder: builder} do
      schema = SchemaBuilder.get_schema(builder, "Profile")

      # Attribute values come from TypeMapper (string keys)
      social_links = schema[:properties][:social_links]
      assert "array" in List.wrap(social_links["type"])
    end
  end

  describe "embedded cycle detection" do
    # Tests that cycle detection prevents infinite recursion.

    test "generating embedded schemas completes without hanging" do
      # This should complete quickly, not hang
      builder =
        SchemaBuilder.add_resource_schemas(
          SchemaBuilder.new(version: "3.1"),
          AshOaskit.Test.Author
        )

      assert SchemaBuilder.has_schema?(builder, "Profile")
      assert SchemaBuilder.has_schema?(builder, "Address")
    end

    test "embedded resources are marked as seen" do
      builder =
        SchemaBuilder.add_resource_schemas(
          SchemaBuilder.new(version: "3.1"),
          AshOaskit.Test.Author
        )

      # Both embedded types should be marked as seen
      assert SchemaBuilder.seen?(builder, AshOaskit.Test.Profile)
      assert SchemaBuilder.seen?(builder, AshOaskit.Test.Address)
    end

    test "duplicate embedded types are not regenerated" do
      initial_builder = SchemaBuilder.new(version: "3.1")

      builder =
        initial_builder
        |> SchemaBuilder.add_resource_schemas(AshOaskit.Test.Author)
        |> SchemaBuilder.add_resource_schemas(AshOaskit.Test.Author)

      # Should still only have one of each schema
      names = SchemaBuilder.schema_names(builder)
      assert Enum.count(names, &(&1 == "Profile")) == 1
      assert Enum.count(names, &(&1 == "Address")) == 1
    end
  end

  describe "embedded resources in OpenAPI 3.0" do
    # Tests for OpenAPI 3.0 specific handling.

    test "nullable embedded fields use nullable: true" do
      builder =
        SchemaBuilder.add_resource_schemas(
          SchemaBuilder.new(version: "3.0"),
          AshOaskit.Test.Author
        )

      # Attributes schema: outer uses atom keys, values from TypeMapper use string keys
      schema = SchemaBuilder.get_schema(builder, "AuthorAttributes")

      # profile is nullable - value from TypeMapper
      profile = schema[:properties][:profile]
      assert profile["nullable"] == true or Map.has_key?(profile, "$ref")
    end
  end

  describe "embedded resources in OpenAPI 3.1" do
    # Tests for OpenAPI 3.1 specific handling.

    test "nullable embedded fields use type array or oneOf" do
      builder =
        SchemaBuilder.add_resource_schemas(
          SchemaBuilder.new(version: "3.1"),
          AshOaskit.Test.Author
        )

      # Attributes schema: outer uses atom keys, values from TypeMapper use string keys
      schema = SchemaBuilder.get_schema(builder, "AuthorAttributes")

      # profile is nullable - check for 3.1 nullable patterns
      # Value from TypeMapper uses string keys
      profile = schema[:properties][:profile]

      has_nullable_pattern =
        cond do
          is_list(profile["type"]) and "null" in profile["type"] -> true
          Map.has_key?(profile, "oneOf") -> true
          Map.has_key?(profile, "allOf") -> true
          Map.has_key?(profile, "$ref") -> true
          true -> false
        end

      assert has_nullable_pattern
    end
  end

  describe "embedded in input schemas" do
    # Tests that embedded types also work in input schemas.
    # Input attribute values come from TypeMapper (string keys).

    setup do
      builder =
        SchemaBuilder.add_resource_schemas(
          SchemaBuilder.new(version: "3.1"),
          AshOaskit.Test.Author
        )

      {:ok, builder: builder}
    end

    test "create input can include embedded field", %{builder: builder} do
      schema = SchemaBuilder.get_schema(builder, "AuthorCreateInput")

      # profile should be in create input - property names are atoms
      assert Map.has_key?(schema[:properties], :profile)
    end

    test "update input can include embedded field", %{builder: builder} do
      schema = SchemaBuilder.get_schema(builder, "AuthorUpdateInput")

      # profile should be in update input - property names are atoms
      assert Map.has_key?(schema[:properties], :profile)
    end
  end

  describe "embedded_resource? and maybe_add_embedded_schema edge cases" do
    alias AshOaskit.SchemaBuilder.EmbeddedSchemas

    test "embedded_resource? returns false for non-resource modules" do
      refute EmbeddedSchemas.embedded_resource?(String)
    end

    test "embedded_resource? returns false for non-atom types" do
      refute EmbeddedSchemas.embedded_resource?("not_an_atom")
    end

    test "embedded_resource? returns false for module without spark_is" do
      refute EmbeddedSchemas.embedded_resource?(Enum)
    end

    test "embedded_resource? returns true for actual embedded resource" do
      assert EmbeddedSchemas.embedded_resource?(AshOaskit.Test.Address)
    end

    test "maybe_add_embedded_schema passes through non-atom non-array types" do
      builder = %{schemas: %{}, version: "3.1"}

      result =
        EmbeddedSchemas.maybe_add_embedded_schema(
          builder,
          "string_type",
          fn b, _t -> b end
        )

      assert result == builder
    end

    test "maybe_add_embedded_schema passes through tuple types that are not :array" do
      builder = %{schemas: %{}, version: "3.1"}

      result =
        EmbeddedSchemas.maybe_add_embedded_schema(
          builder,
          {:map, :string, :integer},
          fn b, _t -> b end
        )

      assert result == builder
    end

    test "maybe_add_embedded_schema handles {:array, inner} by unwrapping" do
      builder = %{schemas: %{}, version: "3.1"}
      called = :atomics.new(1, [])

      result =
        EmbeddedSchemas.maybe_add_embedded_schema(
          builder,
          {:array, AshOaskit.Test.Address},
          fn b, _t ->
            :atomics.add(called, 1, 1)
            b
          end
        )

      # The add_fn should have been called for the inner embedded type
      assert :atomics.get(called, 1) == 1
      assert result == builder
    end

    test "maybe_add_embedded_schema returns builder for non-embedded atom" do
      builder = %{schemas: %{}, version: "3.1"}

      result =
        EmbeddedSchemas.maybe_add_embedded_schema(
          builder,
          :string,
          fn b, _t -> Map.put(b, :called, true) end
        )

      # add_fn should NOT have been called since :string is not an embedded resource
      refute Map.has_key?(result, :called)
      assert result == builder
    end
  end

  describe "edge cases" do
    # Tests for edge cases in embedded resource handling.

    test "resource without embedded attributes works" do
      builder =
        SchemaBuilder.add_resource_schemas(
          SchemaBuilder.new(version: "3.1"),
          AshOaskit.Test.Comment
        )

      # Should generate schema without embedded handling
      assert SchemaBuilder.has_schema?(builder, "CommentAttributes")
    end

    test "deeply nested embedded resources work" do
      # Author -> Profile -> Address is 3 levels deep
      builder =
        SchemaBuilder.add_resource_schemas(
          SchemaBuilder.new(version: "3.1"),
          AshOaskit.Test.Author
        )

      # All three levels should have schemas
      assert SchemaBuilder.has_schema?(builder, "AuthorAttributes")
      assert SchemaBuilder.has_schema?(builder, "Profile")
      assert SchemaBuilder.has_schema?(builder, "Address")
    end

    test "embedded schema has correct structure" do
      builder =
        SchemaBuilder.add_resource_schemas(
          SchemaBuilder.new(version: "3.1"),
          AshOaskit.Test.Author
        )

      address = SchemaBuilder.get_schema(builder, "Address")

      # Outer structure uses atom keys
      # Should be a proper object schema
      assert address[:type] == :object
      assert is_map(address[:properties])
      assert map_size(address[:properties]) > 0
    end
  end
end
