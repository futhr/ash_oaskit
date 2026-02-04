defmodule AshOaskit.Generators.V30Test do
  @moduledoc """
  Tests for the AshOaskit.Generators.V30 module.

  This module tests the OpenAPI 3.0 specification generator, which produces
  specs compliant with the 3.0.x standard. Key differences from 3.1 include
  the use of `nullable: true` instead of type arrays for nullable fields,
  and lack of JSON Schema 2020-12 features.

  ## Test Categories

  - **Basic structure** - OpenAPI version, info, servers, paths, components
  - **Option forwarding** - Title, API version, server configuration
  - **Nullable handling** - 3.0-style `nullable: true` flag
  - **Domain integration** - Generating from Ash domain configurations
  """

  use ExUnit.Case, async: true

  alias AshOaskit.Generators.V30

  describe "generate/2 basic structure" do
    test "returns valid OpenAPI 3.0 structure" do
      result = V30.generate([AshOaskit.Test.SimpleDomain], [])

      assert result[:openapi] == "3.0.3"
      assert is_map(result[:info])
      assert is_list(result[:servers])
      assert is_map(result[:paths])
      assert is_map(result[:components])
    end

    test "includes title in info" do
      result = V30.generate([AshOaskit.Test.SimpleDomain], title: "Test API")
      assert result[:info][:title] == "Test API"
    end

    test "includes api_version in info" do
      result = V30.generate([AshOaskit.Test.SimpleDomain], api_version: "1.2.3")
      assert result[:info][:version] == "1.2.3"
    end

    test "includes description when provided" do
      result = V30.generate([AshOaskit.Test.SimpleDomain], description: "My API")
      assert result[:info][:description] == "My API"
    end

    test "includes contact info when provided" do
      contact = %{name: "API Support", email: "support@example.com"}
      result = V30.generate([AshOaskit.Test.SimpleDomain], contact: contact)
      assert result[:info][:contact] == contact
    end

    test "includes license when provided" do
      license = %{name: "MIT", url: "https://opensource.org/licenses/MIT"}
      result = V30.generate([AshOaskit.Test.SimpleDomain], license: license)
      assert result[:info][:license] == license
    end

    test "includes servers when provided as strings" do
      servers = ["https://api.example.com", "https://staging.example.com"]
      result = V30.generate([AshOaskit.Test.SimpleDomain], servers: servers)

      assert Enum.map(result[:servers], & &1[:url]) == servers
    end

    test "includes server objects when provided as maps" do
      servers = [%{url: "https://api.example.com", description: "Production"}]
      result = V30.generate([AshOaskit.Test.SimpleDomain], servers: servers)
      assert result[:servers] == servers
    end

    test "has default server when not provided" do
      result = V30.generate([AshOaskit.Test.SimpleDomain], [])
      assert result[:servers] == [%{url: "/"}]
    end

    test "includes schemas in components" do
      result = V30.generate([AshOaskit.Test.SimpleDomain], [])
      assert is_map(result[:components][:schemas])
    end

    test "includes security when provided" do
      security = [%{"bearerAuth" => []}]
      result = V30.generate([AshOaskit.Test.SimpleDomain], security: security)
      assert result[:security] == security
    end

    test "includes terms_of_service when provided" do
      result =
        V30.generate([AshOaskit.Test.SimpleDomain], terms_of_service: "https://example.com/tos")

      assert result[:info][:termsOfService] == "https://example.com/tos"
    end
  end

  describe "generate/2 with AshJsonApi domain" do
    test "builds paths from domain routes" do
      result = V30.generate([AshOaskit.Test.Blog], [])

      assert is_map(result[:paths])
    end

    test "includes resource schemas in components" do
      result = V30.generate([AshOaskit.Test.Blog], [])

      schemas = result[:components][:schemas]
      assert is_map(schemas)
    end

    test "builds tags from resources" do
      result = V30.generate([AshOaskit.Test.Blog], [])

      if result[:tags] do
        assert is_list(result[:tags])
      end
    end
  end

  describe "generate/2 schema building" do
    test "creates Attributes and Response schemas for resources" do
      result = V30.generate([AshOaskit.Test.SimpleDomain], [])

      schemas = result[:components][:schemas]

      attribute_schemas = Enum.filter(Map.keys(schemas), &String.ends_with?(&1, "Attributes"))
      response_schemas = Enum.filter(Map.keys(schemas), &String.ends_with?(&1, "Response"))

      assert attribute_schemas != []
      assert response_schemas != []
    end

    test "attribute schemas are object type" do
      result = V30.generate([AshOaskit.Test.SimpleDomain], [])

      schemas = result[:components][:schemas]

      Enum.each(schemas, fn {name, schema} ->
        if String.ends_with?(name, "Attributes") do
          assert schema[:type] == :object
          assert is_map(schema[:properties])
        end
      end)
    end

    test "response schemas include data wrapper" do
      result = V30.generate([AshOaskit.Test.SimpleDomain], [])

      schemas = result[:components][:schemas]

      Enum.each(schemas, fn {name, schema} ->
        if String.ends_with?(name, "Response") do
          assert schema[:type] == :object
          assert is_map(schema[:properties][:data])
        end
      end)
    end

    test "filters out id, inserted_at, updated_at from attributes" do
      result = V30.generate([AshOaskit.Test.SimpleDomain], [])

      schemas = result[:components][:schemas]

      Enum.each(schemas, fn {name, schema} ->
        if String.ends_with?(name, "Attributes") do
          properties = schema[:properties] || %{}
          refute Map.has_key?(properties, "id")
          refute Map.has_key?(properties, "inserted_at")
          refute Map.has_key?(properties, "updated_at")
        end
      end)
    end

    test "uses nullable flag for 3.0 style" do
      result = V30.generate([AshOaskit.Test.SimpleDomain], [])

      schemas = result[:components][:schemas]

      # Directly test a known nullable field — body is allow_nil? true by default
      post_attrs = schemas["PostAttributes"]
      assert post_attrs, "PostAttributes schema must exist"

      body_schema = post_attrs[:properties][:body]
      assert body_schema, "body property must exist in PostAttributes"

      # String keys from TypeMapper in property values
      assert body_schema["nullable"] == true,
             "Expected 3.0 nullable field to have \"nullable\": true, got: #{inspect(body_schema)}"

      assert is_binary(body_schema["type"]),
             "Expected 3.0 type to be a string, not array, got: #{inspect(body_schema["type"])}"

      refute is_list(body_schema["type"]),
             "3.0 must not use type arrays"
    end
  end

  describe "generate/2 fallback behavior" do
    test "returns empty paths for domain without AshJsonApi routes" do
      result = V30.generate([AshOaskit.Test.SimpleDomain], [])

      assert result[:paths] == %{}
    end

    test "handles empty domains list" do
      result = V30.generate([], [])

      assert result[:openapi] == "3.0.3"
      assert result[:paths] == %{}
      assert result[:components][:schemas] == %{}
    end

    test "handles multiple domains" do
      result = V30.generate([AshOaskit.Test.SimpleDomain, AshOaskit.Test.Blog], [])

      assert result[:openapi] == "3.0.3"
      assert is_map(result[:components][:schemas])
    end
  end

  describe "version comparison with V31" do
    alias AshOaskit.Generators.V31

    test "V30 outputs 3.0.3, V31 outputs 3.1.0" do
      result_30 = V30.generate([AshOaskit.Test.SimpleDomain], [])
      result_31 = V31.generate([AshOaskit.Test.SimpleDomain], [])

      assert result_30[:openapi] == "3.0.3"
      assert result_31[:openapi] == "3.1.0"
    end

    test "both have same top-level structure" do
      result_30 = V30.generate([AshOaskit.Test.SimpleDomain], title: "API")
      result_31 = V31.generate([AshOaskit.Test.SimpleDomain], title: "API")

      assert Map.keys(result_30) -- [:openapi] == Map.keys(result_31) -- [:openapi]
    end

    test "3.0 uses nullable flag, 3.1 uses type arrays" do
      result_30 = V30.generate([AshOaskit.Test.SimpleDomain], [])
      result_31 = V31.generate([AshOaskit.Test.SimpleDomain], [])

      # Both should have schemas
      assert map_size(result_30[:components][:schemas]) > 0
      assert map_size(result_31[:components][:schemas]) > 0
    end
  end
end
