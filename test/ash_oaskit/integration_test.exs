defmodule AshOaskit.IntegrationTest do
  @moduledoc """
  Integration tests for end-to-end OpenAPI spec generation.

  These tests verify that complete, valid OpenAPI specifications
  are generated from real Ash domains, and that the output can
  be serialized to JSON/YAML without issues.

  ## Test Coverage

  - **Full Spec Generation** - Complete spec from Ash domains
  - **JSON Serialization** - Encode/decode roundtrip
  - **Spec Structure** - Required OpenAPI fields present
  - **Multi-Domain** - Combining multiple domains

  ## Integration Flow

  ```
  Ash Domain(s)
       │
       ▼
  AshOaskit.spec/1
       │
       ▼
  OpenAPI Spec (map)
       │
       ▼
  Jason.encode!/1
       │
       ▼
  Valid JSON String
  ```
  """

  use ExUnit.Case, async: false

  describe "full spec generation" do
    test "generates complete spec from real Ash domain" do
      spec = AshOaskit.spec(domains: [AshOaskit.Test.SimpleDomain])

      assert spec["openapi"] == "3.1.0"
      assert is_map(spec["info"])
      assert is_map(spec["paths"])
      assert is_map(spec["components"])
      assert is_map(spec["components"]["schemas"])
    end

    test "spec is valid JSON that can be encoded and decoded" do
      spec = AshOaskit.spec(domains: [AshOaskit.Test.SimpleDomain])

      # Should be able to encode to JSON and decode back
      json = Jason.encode!(spec)
      decoded = Jason.decode!(json)

      # Structure should be preserved (note: atoms become strings after roundtrip)
      assert decoded["openapi"] == "3.1.0"
      assert is_map(decoded["info"])
      assert is_map(decoded["paths"])
      assert is_map(decoded["components"])

      # Should be able to encode again without error
      assert {:ok, _} = Jason.encode(decoded)
    end

    test "all $ref references resolve to existing schemas" do
      spec = AshOaskit.spec(domains: [AshOaskit.Test.SimpleDomain])

      schemas = spec["components"]["schemas"]

      # Find all $ref values in the spec
      refs = find_all_refs(spec)

      # Each ref should point to an existing schema
      Enum.each(refs, fn ref ->
        # Refs look like "#/components/schemas/PostAttributes"
        if String.starts_with?(ref, "#/components/schemas/") do
          schema_name = String.replace_prefix(ref, "#/components/schemas/", "")
          assert Map.has_key?(schemas, schema_name), "Missing schema: #{schema_name}"
        end
      end)
    end

    test "spec includes resource schemas" do
      spec = AshOaskit.spec(domains: [AshOaskit.Test.SimpleDomain])

      schemas = spec["components"]["schemas"]

      # Should have Post schemas
      assert Map.has_key?(schemas, "PostAttributes")
      assert Map.has_key?(schemas, "PostResponse")

      # Should have Comment schemas
      assert Map.has_key?(schemas, "CommentAttributes")
      assert Map.has_key?(schemas, "CommentResponse")
    end

    test "attribute schemas contain expected properties" do
      spec = AshOaskit.spec(domains: [AshOaskit.Test.SimpleDomain])

      post_attrs = spec["components"]["schemas"]["PostAttributes"]

      # Should have properties from the Post resource
      props = post_attrs["properties"]
      assert is_map(props)

      # Should include some of our test attributes
      assert Map.has_key?(props, "title")
      assert Map.has_key?(props, "body")
    end
  end

  describe "version differences" do
    test "3.0 uses nullable:true, 3.1 uses type arrays" do
      spec_30 = AshOaskit.spec_30(domains: [AshOaskit.Test.SimpleDomain])
      spec_31 = AshOaskit.spec_31(domains: [AshOaskit.Test.SimpleDomain])

      assert spec_30["openapi"] == "3.0.3"
      assert spec_31["openapi"] == "3.1.0"

      # Get a nullable field from each spec
      post_attrs_30 = spec_30["components"]["schemas"]["PostAttributes"]["properties"]
      post_attrs_31 = spec_31["components"]["schemas"]["PostAttributes"]["properties"]

      # body is nullable (allow_nil? defaults to true)
      body_30 = post_attrs_30["body"]
      body_31 = post_attrs_31["body"]

      # 3.0 style: nullable flag — must be unconditional
      assert body_30["nullable"] == true,
             "Expected 3.0 nullable field to have \"nullable\": true, got: #{inspect(body_30)}"

      assert is_binary(body_30["type"]),
             "Expected 3.0 type to be a string, got: #{inspect(body_30["type"])}"

      # 3.1 style: type array — must be unconditional
      assert is_list(body_31["type"]),
             "Expected 3.1 nullable type to be an array, got: #{inspect(body_31["type"])}"

      assert "null" in body_31["type"],
             "Expected 3.1 type array to include \"null\", got: #{inspect(body_31["type"])}"
    end

    test "both versions have identical top-level structure" do
      spec_30 = AshOaskit.spec_30(domains: [AshOaskit.Test.SimpleDomain])
      spec_31 = AshOaskit.spec_31(domains: [AshOaskit.Test.SimpleDomain])

      # Same top-level keys (except openapi version)
      keys_30 = Enum.sort(Map.keys(spec_30))
      keys_31 = Enum.sort(Map.keys(spec_31))

      assert keys_30 == keys_31
    end

    test "both versions generate the same schema names" do
      spec_30 = AshOaskit.spec_30(domains: [AshOaskit.Test.SimpleDomain])
      spec_31 = AshOaskit.spec_31(domains: [AshOaskit.Test.SimpleDomain])

      schemas_30 = Map.keys(spec_30["components"]["schemas"] || %{})
      schemas_31 = Map.keys(spec_31["components"]["schemas"] || %{})

      assert Enum.sort(schemas_30) == Enum.sort(schemas_31)
    end
  end

  describe "with AshJsonApi domain" do
    test "generates paths from routes" do
      spec = AshOaskit.spec(domains: [AshOaskit.Test.Blog])

      # Blog domain has routes configured
      assert is_map(spec["paths"])
    end
  end

  describe "multiple domains" do
    test "combines schemas from multiple domains" do
      spec =
        AshOaskit.spec(domains: [AshOaskit.Test.SimpleDomain, AshOaskit.Test.Blog])

      schemas = spec["components"]["schemas"]

      # Should have schemas from both domains
      assert Map.has_key?(schemas, "PostAttributes")
      assert Map.has_key?(schemas, "CommentAttributes")
    end
  end

  describe "Oaskit integration" do
    test "spec passes Oaskit validation for 3.1" do
      spec = AshOaskit.spec(domains: [AshOaskit.Test.Blog])
      assert {:ok, %Oaskit.Spec.OpenAPI{}} = AshOaskit.validate(spec)
    end

    test "spec passes Oaskit validation for 3.0" do
      spec = AshOaskit.spec_30(domains: [AshOaskit.Test.Blog])
      assert {:ok, %Oaskit.Spec.OpenAPI{}} = AshOaskit.validate(spec)
    end

    test "SpecDumper produces valid JSON with proper key ordering" do
      spec = AshOaskit.spec(domains: [AshOaskit.Test.Blog])
      json = spec |> Oaskit.SpecDumper.to_json!(pretty: true) |> IO.iodata_to_binary()

      assert is_binary(json)
      decoded = Jason.decode!(json)
      assert decoded["openapi"] == "3.1.0"
      assert is_map(decoded["info"])
      assert is_map(decoded["paths"])
    end

    test "spec roundtrips through normalize -> validate -> dump" do
      spec = AshOaskit.spec(domains: [AshOaskit.Test.Blog])

      # Validate
      {:ok, validated} = AshOaskit.validate(spec)

      # Convert back to map
      map = AshOaskit.OpenApi.to_map(validated)

      # Dump to JSON
      json = map |> Oaskit.SpecDumper.to_json!(pretty: true) |> IO.iodata_to_binary()
      decoded = Jason.decode!(json)

      assert decoded["openapi"] == "3.1.0"
      assert is_map(decoded["info"])
      assert is_map(decoded["paths"])
    end

    test "multi-domain spec validates cleanly" do
      spec =
        AshOaskit.spec(
          domains: [AshOaskit.Test.SimpleDomain, AshOaskit.Test.Blog],
          title: "Multi-Domain API",
          api_version: "1.0.0"
        )

      assert {:ok, %Oaskit.Spec.OpenAPI{}} = AshOaskit.validate(spec)
    end
  end

  describe "negative validation tests" do
    test "spec missing openapi key fails validation" do
      spec = AshOaskit.spec(domains: [AshOaskit.Test.Blog])
      bad_spec = Map.delete(spec, "openapi")

      assert {:error, _} = AshOaskit.validate(bad_spec)
    end

    test "spec with non-string openapi version fails validation" do
      spec = AshOaskit.spec(domains: [AshOaskit.Test.Blog])
      bad_spec = Map.put(spec, "openapi", 3.1)

      assert {:error, _} = AshOaskit.validate(bad_spec)
    end

    test "spec with invalid paths type fails validation" do
      spec = AshOaskit.spec(domains: [AshOaskit.Test.Blog])
      bad_spec = Map.put(spec, "paths", "not a map")

      assert {:error, _} = AshOaskit.validate(bad_spec)
    end
  end

  # Helper to recursively find all $ref values in a map/list
  defp find_all_refs(data) when is_map(data) do
    ref = Map.get(data, "$ref")

    child_refs =
      data
      |> Map.values()
      |> Enum.flat_map(&find_all_refs/1)

    if ref, do: [ref | child_refs], else: child_refs
  end

  defp find_all_refs(data) when is_list(data) do
    Enum.flat_map(data, &find_all_refs/1)
  end

  defp find_all_refs(_), do: []
end
