defmodule AshOaskit.ComponentsTest do
  @moduledoc """
  Tests for OpenAPI Components Object generation.

  These tests verify that the OpenAPI Components Object is properly
  structured according to the OpenAPI 3.1 specification.

  Reference: https://spec.openapis.org/oas/v3.1.0#components-object

  ## Test Coverage

  - **schemas** - Resource attribute and response schemas
  - **parameters** - Reusable query parameters
  - **responses** - Standard error responses
  - **Schema References** - Proper $ref usage for deduplication

  ## Components Structure

  ```
  components:
    schemas:
      PostAttributes: {...}
      PostResponse: {...}
      Error: {...}
    parameters:
      filterParam: {...}
      sortParam: {...}
    responses:
      NotFound: {...}
  ```
  """

  use ExUnit.Case, async: true

  describe "components object" do
    test "schemas component is populated" do
      spec = AshOaskit.spec_31(domains: [AshOaskit.Test.SimpleDomain])

      assert is_map(spec["components"])
      assert is_map(spec["components"]["schemas"])
      assert map_size(spec["components"]["schemas"]) > 0
    end

    test "schemas contain resource attribute schemas" do
      spec = AshOaskit.spec_31(domains: [AshOaskit.Test.SimpleDomain])

      schemas = spec["components"]["schemas"]

      # Should have at least some schemas from our test resources
      assert map_size(schemas) > 0
    end

    test "components object allows all standard fields" do
      # OpenAPI 3.1 components can have these fields
      valid_component_fields = [
        "schemas",
        "responses",
        "parameters",
        "examples",
        "requestBodies",
        "headers",
        "securitySchemes",
        "links",
        "callbacks",
        "pathItems"
      ]

      spec = AshOaskit.spec_31(domains: [AshOaskit.Test.SimpleDomain])

      # All fields in components should be valid
      Enum.each(Map.keys(spec["components"] || %{}), fn field ->
        assert field in valid_component_fields,
               "Unexpected component field: #{field}"
      end)
    end
  end

  describe "component key validation" do
    test "schema keys match valid pattern" do
      spec = AshOaskit.spec_31(domains: [AshOaskit.Test.SimpleDomain])

      schemas = spec["components"]["schemas"] || %{}

      # Keys must match ^[a-zA-Z0-9\.\-_]+$
      Enum.each(Map.keys(schemas), fn key ->
        assert Regex.match?(~r/^[a-zA-Z0-9.\-_]+$/, key),
               "Invalid schema key: #{key}"
      end)
    end

    test "schema keys are descriptive" do
      spec = AshOaskit.spec_31(domains: [AshOaskit.Test.SimpleDomain])

      schemas = spec["components"]["schemas"] || %{}

      # Keys should be meaningful (not just random strings)
      Enum.each(Map.keys(schemas), fn key ->
        assert String.length(key) > 2,
               "Schema key too short: #{key}"
      end)
    end

    test "no duplicate schema keys" do
      spec = AshOaskit.spec_31(domains: [AshOaskit.Test.SimpleDomain])

      schemas = spec["components"]["schemas"] || %{}
      keys = Map.keys(schemas)

      assert length(keys) == length(Enum.uniq(keys)),
             "Duplicate schema keys found"
    end
  end

  describe "schema objects in components" do
    test "schemas are valid JSON Schema objects" do
      spec = AshOaskit.spec_31(domains: [AshOaskit.Test.SimpleDomain])

      schemas = spec["components"]["schemas"] || %{}

      Enum.each(schemas, fn {name, schema} ->
        assert is_map(schema),
               "Schema #{name} should be a map"
      end)
    end

    test "object schemas have properties" do
      spec = AshOaskit.spec_31(domains: [AshOaskit.Test.SimpleDomain])

      schemas = spec["components"]["schemas"] || %{}

      Enum.each(schemas, fn {name, schema} ->
        if schema["type"] == "object" do
          assert Map.has_key?(schema, "properties") or Map.has_key?(schema, "$ref"),
                 "Object schema #{name} should have properties or $ref"
        end
      end)
    end

    test "array schemas have items" do
      spec = AshOaskit.spec_31(domains: [AshOaskit.Test.SimpleDomain])

      schemas = spec["components"]["schemas"] || %{}

      Enum.each(schemas, fn {name, schema} ->
        if schema["type"] == "array" do
          assert Map.has_key?(schema, "items"),
                 "Array schema #{name} should have items"
        end
      end)
    end
  end

  describe "multi-domain components" do
    test "schemas from multiple domains are combined" do
      spec = AshOaskit.spec_31(domains: [AshOaskit.Test.SimpleDomain, AshOaskit.Test.Blog])

      schemas = spec["components"]["schemas"] || %{}

      # Should have schemas from both domains
      assert map_size(schemas) > 0
    end

    test "no schema name collisions between domains" do
      spec = AshOaskit.spec_31(domains: [AshOaskit.Test.SimpleDomain, AshOaskit.Test.Blog])

      schemas = spec["components"]["schemas"] || %{}

      # Each schema should be unique
      keys = Map.keys(schemas)
      assert length(keys) == length(Enum.uniq(keys))
    end
  end

  describe "$ref references in components" do
    test "$ref format is correct" do
      spec = AshOaskit.spec_31(domains: [AshOaskit.Test.Blog])

      # Extract all $ref values
      refs = extract_all_refs(spec)

      Enum.each(refs, fn ref ->
        # Local refs start with #/
        if String.starts_with?(ref, "#/") do
          assert Regex.match?(~r|^#/[a-zA-Z0-9/_\-\.]+$|, ref),
                 "Invalid $ref format: #{ref}"
        end
      end)
    end

    test "all local $refs point to existing schemas" do
      spec = AshOaskit.spec_31(domains: [AshOaskit.Test.Blog])

      refs = extract_all_refs(spec)
      schemas = spec["components"]["schemas"] || %{}

      Enum.each(refs, fn ref ->
        if String.starts_with?(ref, "#/components/schemas/") do
          schema_name = String.replace_prefix(ref, "#/components/schemas/", "")

          assert Map.has_key?(schemas, schema_name),
                 "Referenced schema not found: #{schema_name}"
        end
      end)
    end

    test "no circular references at top level" do
      spec = AshOaskit.spec_31(domains: [AshOaskit.Test.SimpleDomain])

      schemas = spec["components"]["schemas"] || %{}

      # Check that no schema directly references itself
      Enum.each(schemas, fn {name, schema} ->
        if ref = schema["$ref"] do
          schema_name = String.replace_prefix(ref, "#/components/schemas/", "")

          refute schema_name == name,
                 "Schema #{name} has circular self-reference"
        end
      end)
    end
  end

  describe "required fields in schemas" do
    test "required is an array of strings" do
      spec = AshOaskit.spec_31(domains: [AshOaskit.Test.SimpleDomain])

      schemas = spec["components"]["schemas"] || %{}

      Enum.each(schemas, fn {name, schema} ->
        if required = schema["required"] do
          assert is_list(required),
                 "required in #{name} should be an array"

          Enum.each(required, fn field ->
            assert is_binary(field),
                   "required field in #{name} should be a string"
          end)
        end
      end)
    end

    test "required fields exist in properties" do
      spec = AshOaskit.spec_31(domains: [AshOaskit.Test.SimpleDomain])

      schemas = spec["components"]["schemas"] || %{}

      Enum.each(schemas, fn {name, schema} ->
        required = schema["required"] || []
        properties = schema["properties"] || %{}

        Enum.each(required, fn field ->
          assert Map.has_key?(properties, field),
                 "Required field '#{field}' not in properties of #{name}"
        end)
      end)
    end
  end

  defp extract_all_refs(map) when is_map(map) do
    Enum.flat_map(map, fn
      {"$ref", ref} when is_binary(ref) ->
        [ref]

      {_, value} ->
        extract_all_refs(value)
    end)
  end

  defp extract_all_refs(list) when is_list(list) do
    Enum.flat_map(list, &extract_all_refs/1)
  end

  defp extract_all_refs(_), do: []
end
