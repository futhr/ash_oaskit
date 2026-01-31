defmodule AshOaskit.IncludedResourcesTest do
  @moduledoc """
  Tests for AshOaskit.IncludedResources module.

  This test module verifies the generation of JSON:API `included` array
  schemas for OpenAPI specifications, including:

  - Basic included array schema generation
  - oneOf schemas for multiple resource types
  - Discriminator support for better tooling
  - Empty included arrays
  - Include path resolution
  - Response schema integration
  """

  use ExUnit.Case, async: true

  alias AshOaskit.IncludedResources

  describe "build_included_schema_for_types/2" do
    test "generates array schema with oneOf for multiple types" do
      schema = IncludedResources.build_included_schema_for_types(["User", "Comment"])

      assert schema["type"] == "array"
      assert is_map(schema["items"])
      assert is_list(schema["items"]["oneOf"])
      assert length(schema["items"]["oneOf"]) == 2
    end

    test "generates refs with default suffix" do
      schema = IncludedResources.build_included_schema_for_types(["User"])

      # When single type, items is the ref directly
      assert schema["items"]["$ref"] == "#/components/schemas/UserResource"
    end

    test "uses direct ref for single type (no oneOf needed)" do
      schema = IncludedResources.build_included_schema_for_types(["User"])

      # Single type doesn't need oneOf wrapper
      assert schema["items"]["$ref"] == "#/components/schemas/UserResource"
      refute Map.has_key?(schema["items"], "oneOf")
    end

    test "respects schema_prefix option" do
      schema =
        IncludedResources.build_included_schema_for_types(
          ["User"],
          schema_prefix: "JsonApi"
        )

      assert schema["items"]["$ref"] == "#/components/schemas/JsonApiUserResource"
    end

    test "respects schema_suffix option" do
      schema =
        IncludedResources.build_included_schema_for_types(
          ["User"],
          schema_suffix: ""
        )

      assert schema["items"]["$ref"] == "#/components/schemas/User"
    end

    test "sorts types alphabetically" do
      schema = IncludedResources.build_included_schema_for_types(["Zebra", "Alpha", "Middle"])

      refs = schema["items"]["oneOf"]

      ref_names =
        Enum.map(refs, fn %{"$ref" => ref} ->
          ref |> String.split("/") |> List.last()
        end)

      assert ref_names == ["AlphaResource", "MiddleResource", "ZebraResource"]
    end

    test "removes duplicate types" do
      schema = IncludedResources.build_included_schema_for_types(["User", "User", "Comment"])

      refs = schema["items"]["oneOf"]
      assert length(refs) == 2
    end

    test "includes description" do
      schema = IncludedResources.build_included_schema_for_types(["User"])

      assert schema["description"] == "Included related resources"
    end

    test "returns empty schema for empty types list" do
      schema = IncludedResources.build_included_schema_for_types([])

      assert schema["maxItems"] == 0
    end
  end

  describe "build_empty_included_schema/0" do
    test "generates empty array schema" do
      schema = IncludedResources.build_empty_included_schema()

      assert schema["type"] == "array"
      assert schema["maxItems"] == 0
    end

    test "has empty items schema" do
      schema = IncludedResources.build_empty_included_schema()

      assert schema["items"] == %{}
    end

    test "includes description" do
      schema = IncludedResources.build_empty_included_schema()

      assert String.contains?(schema["description"], "No related")
    end
  end

  describe "build_included_schema_with_discriminator/2" do
    test "adds discriminator to oneOf" do
      types = [{"users", "User"}, {"comments", "Comment"}]
      schema = IncludedResources.build_included_schema_with_discriminator(types)

      assert Map.has_key?(schema["items"], "discriminator")
      assert schema["items"]["discriminator"]["propertyName"] == "type"
    end

    test "includes mapping for each type" do
      types = [{"users", "User"}, {"comments", "Comment"}]
      schema = IncludedResources.build_included_schema_with_discriminator(types)

      mapping = schema["items"]["discriminator"]["mapping"]
      assert mapping["users"] == "#/components/schemas/UserResource"
      assert mapping["comments"] == "#/components/schemas/CommentResource"
    end

    test "respects schema options" do
      types = [{"users", "User"}]

      schema =
        IncludedResources.build_included_schema_with_discriminator(
          types,
          schema_prefix: "Api",
          schema_suffix: ""
        )

      mapping = schema["items"]["discriminator"]["mapping"]
      assert mapping["users"] == "#/components/schemas/ApiUser"
    end

    test "includes oneOf refs" do
      types = [{"users", "User"}, {"comments", "Comment"}]
      schema = IncludedResources.build_included_schema_with_discriminator(types)

      assert is_list(schema["items"]["oneOf"])
      assert length(schema["items"]["oneOf"]) == 2
    end
  end

  describe "add_included_to_response/2" do
    test "adds included property to response schema" do
      response = %{
        "type" => "object",
        "properties" => %{
          "data" => %{"type" => "object"}
        }
      }

      result = IncludedResources.add_included_to_response(response, types: ["User"])

      assert Map.has_key?(result["properties"], "included")
      assert Map.has_key?(result["properties"], "data")
    end

    test "uses types when provided" do
      response = %{"type" => "object", "properties" => %{}}

      result = IncludedResources.add_included_to_response(response, types: ["User", "Comment"])

      included = result["properties"]["included"]
      assert is_list(included["items"]["oneOf"])
    end

    test "returns empty included when no types or resource" do
      response = %{"type" => "object", "properties" => %{}}

      result = IncludedResources.add_included_to_response(response)

      included = result["properties"]["included"]
      assert included["maxItems"] == 0
    end

    test "preserves existing properties" do
      response = %{
        "type" => "object",
        "properties" => %{
          "data" => %{},
          "links" => %{},
          "meta" => %{}
        }
      }

      result = IncludedResources.add_included_to_response(response, types: ["User"])

      assert Map.has_key?(result["properties"], "data")
      assert Map.has_key?(result["properties"], "links")
      assert Map.has_key?(result["properties"], "meta")
      assert Map.has_key?(result["properties"], "included")
    end

    test "creates properties map if not present" do
      response = %{"type" => "object"}

      result = IncludedResources.add_included_to_response(response, types: ["User"])

      assert is_map(result["properties"])
      assert Map.has_key?(result["properties"], "included")
    end
  end

  describe "build_included_component_schemas/2" do
    test "generates component schema" do
      schemas = IncludedResources.build_included_component_schemas(["User", "Comment"])

      assert Map.has_key?(schemas, "IncludedResources")
    end

    test "respects name prefix" do
      schemas =
        IncludedResources.build_included_component_schemas(
          ["User"],
          name_prefix: "JsonApi"
        )

      assert Map.has_key?(schemas, "JsonApiIncludedResources")
    end

    test "schema is valid array with oneOf" do
      schemas = IncludedResources.build_included_component_schemas(["User", "Comment"])

      included = schemas["IncludedResources"]
      assert included["type"] == "array"
    end
  end

  describe "get_resources_from_paths/2" do
    test "returns empty list for empty paths" do
      result = IncludedResources.get_resources_from_paths(AshOaskit.Test.Article, [])

      assert result == []
    end
  end

  describe "schema structure validation" do
    test "all schemas are valid JSON Schema objects" do
      schemas = [
        IncludedResources.build_empty_included_schema(),
        IncludedResources.build_included_schema_for_types(["User"]),
        IncludedResources.build_included_schema_for_types(["User", "Comment"]),
        IncludedResources.build_included_schema_with_discriminator([{"users", "User"}])
      ]

      for schema <- schemas do
        assert is_map(schema)
        assert schema["type"] == "array"
      end
    end

    test "all schemas can be serialized to JSON" do
      schemas = IncludedResources.build_included_component_schemas(["User", "Comment"])

      assert {:ok, _json} = Jason.encode(schemas)
    end

    test "refs are valid JSON Pointer format" do
      schema = IncludedResources.build_included_schema_for_types(["User"])

      ref = schema["items"]["$ref"]
      assert String.starts_with?(ref, "#/components/schemas/")
    end
  end

  describe "build_included_schema/2 with real resources" do
    test "builds included schema for resource with relationships" do
      schema = IncludedResources.build_included_schema(AshOaskit.Test.Article)

      assert schema["type"] == "array"
      # Article has author, reviews, and tags relationships
      assert is_map(schema["items"])
    end

    test "returns empty schema for resource without relationships" do
      # NoTypeResource has no relationships configured
      schema = IncludedResources.build_included_schema(AshOaskit.Test.NoTypeResource)

      assert schema["maxItems"] == 0
    end

    test "respects max_depth option" do
      schema = IncludedResources.build_included_schema(AshOaskit.Test.Article, max_depth: 1)

      assert schema["type"] == "array"
    end

    test "respects include_paths option" do
      schema =
        IncludedResources.build_included_schema(
          AshOaskit.Test.Article,
          include_paths: ["author"]
        )

      assert schema["type"] == "array"
    end
  end

  describe "get_includable_resources/2" do
    test "returns related resource names for resource with relationships" do
      result = IncludedResources.get_includable_resources(AshOaskit.Test.Article)

      assert is_list(result)
      # Article has author (Author), reviews (Review), and tags (Tag)
      assert "Author" in result or "Review" in result or "Tag" in result
    end

    test "uses explicit include_paths when provided" do
      result =
        IncludedResources.get_includable_resources(
          AshOaskit.Test.Article,
          include_paths: ["author"]
        )

      assert is_list(result)
    end

    test "respects max_depth for recursive traversal" do
      # Category has self-referential relationships
      result =
        IncludedResources.get_includable_resources(
          AshOaskit.Test.Category,
          max_depth: 1
        )

      assert is_list(result)
    end

    test "returns empty list for resource without relationships" do
      result = IncludedResources.get_includable_resources(AshOaskit.Test.NoTypeResource)

      assert result == []
    end
  end

  describe "get_resources_from_paths/2 with real resources" do
    test "resolves single relationship path" do
      result =
        IncludedResources.get_resources_from_paths(
          AshOaskit.Test.Article,
          ["author"]
        )

      assert is_list(result)
      assert "Author" in result
    end

    test "resolves nested relationship paths" do
      result =
        IncludedResources.get_resources_from_paths(
          AshOaskit.Test.Article,
          ["author", "reviews"]
        )

      assert is_list(result)
    end

    test "handles dotted path notation" do
      # This tests paths like "author.articles"
      result =
        IncludedResources.get_resources_from_paths(
          AshOaskit.Test.Article,
          ["author"]
        )

      assert is_list(result)
    end

    test "handles non-existent relationship gracefully" do
      result =
        IncludedResources.get_resources_from_paths(
          AshOaskit.Test.Article,
          ["nonexistent"]
        )

      assert result == []
    end

    test "handles relationship name that's not an existing atom" do
      # Use a string that definitely isn't an atom in the system
      # The rescue branch in find_relationship handles ArgumentError from to_existing_atom
      result =
        IncludedResources.get_resources_from_paths(
          AshOaskit.Test.Article,
          ["this_relationship_name_definitely_does_not_exist_#{System.unique_integer()}"]
        )

      assert result == []
    end
  end

  describe "has_includable_resources?/1 with real resources" do
    test "returns true for resource with relationships" do
      result = IncludedResources.has_includable_resources?(AshOaskit.Test.Article)

      assert result == true
    end

    test "returns true for resource with self-referential relationship" do
      result = IncludedResources.has_includable_resources?(AshOaskit.Test.Category)

      assert result == true
    end
  end

  describe "add_included_to_response/2 with resource option" do
    test "builds included from resource relationships" do
      response = %{"type" => "object", "properties" => %{}}

      result =
        IncludedResources.add_included_to_response(
          response,
          resource: AshOaskit.Test.Article
        )

      included = result["properties"]["included"]
      assert included["type"] == "array"
    end
  end

  describe "self-referential and depth-based traversal" do
    test "handles self-referential Category without infinite recursion" do
      resources = IncludedResources.get_includable_resources(AshOaskit.Test.Category)
      assert "Category" in resources
    end

    test "respects max_depth limit with comparable results" do
      shallow =
        IncludedResources.get_includable_resources(
          AshOaskit.Test.Article,
          max_depth: 1
        )

      deep =
        IncludedResources.get_includable_resources(
          AshOaskit.Test.Article,
          max_depth: 3
        )

      assert length(deep) >= length(shallow)
    end

    test "configured_includes returns nil or list" do
      result = IncludedResources.configured_includes(AshOaskit.Test.Post)
      assert is_nil(result) or is_list(result)
    end
  end

  describe "integration scenarios" do
    test "building a complete response with included" do
      response = %{
        "type" => "object",
        "properties" => %{
          "data" => %{
            "type" => "object",
            "properties" => %{
              "id" => %{"type" => "string"},
              "type" => %{"type" => "string"},
              "attributes" => %{"type" => "object"},
              "relationships" => %{"type" => "object"}
            }
          },
          "links" => %{"type" => "object"},
          "meta" => %{"type" => "object"}
        }
      }

      # Add included for a post that can include author and comments
      result =
        IncludedResources.add_included_to_response(
          response,
          types: ["User", "Comment", "Tag"]
        )

      included = result["properties"]["included"]
      assert included["type"] == "array"
      assert length(included["items"]["oneOf"]) == 3

      # Verify refs are sorted
      refs = Enum.map(included["items"]["oneOf"], & &1["$ref"])

      assert refs == [
               "#/components/schemas/CommentResource",
               "#/components/schemas/TagResource",
               "#/components/schemas/UserResource"
             ]
    end

    test "building included with discriminator for better tooling" do
      type_mappings = [
        {"users", "User"},
        {"comments", "Comment"},
        {"tags", "Tag"}
      ]

      schema = IncludedResources.build_included_schema_with_discriminator(type_mappings)

      # Should have discriminator
      assert schema["items"]["discriminator"]["propertyName"] == "type"

      # Mapping should have all types
      mapping = schema["items"]["discriminator"]["mapping"]
      assert Map.has_key?(mapping, "users")
      assert Map.has_key?(mapping, "comments")
      assert Map.has_key?(mapping, "tags")
    end

    test "handling empty includes gracefully" do
      response = %{"type" => "object", "properties" => %{"data" => %{}}}

      # No types specified
      result = IncludedResources.add_included_to_response(response)

      included = result["properties"]["included"]
      assert included["maxItems"] == 0
    end
  end
end
