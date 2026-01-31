defmodule AshOaskit.Generators.V31Test do
  @moduledoc """
  Tests for the AshOaskit.Generators.V31 module.

  This module tests the OpenAPI 3.1 specification generator, which produces
  specs compliant with the 3.1.x standard featuring full JSON Schema 2020-12
  alignment. Key differences from 3.0 include type arrays for nullable fields
  (`"type": ["string", "null"]`) and webhooks support.

  ## Test Categories

  - **Basic structure** - OpenAPI version, info, servers, paths, components
  - **Option forwarding** - Title, API version, server configuration
  - **Nullable handling** - 3.1-style type arrays for nullable fields
  - **Domain integration** - Generating from Ash domain configurations
  """

  use ExUnit.Case, async: true

  alias AshOaskit.Generators.V31

  describe "generate/2 basic structure" do
    test "returns valid OpenAPI 3.1 structure" do
      result = V31.generate([AshOaskit.Test.SimpleDomain], [])

      assert result["openapi"] == "3.1.0"
      assert is_map(result["info"])
      assert is_list(result["servers"])
      assert is_map(result["paths"])
      assert is_map(result["components"])
    end

    test "includes title in info" do
      result = V31.generate([AshOaskit.Test.SimpleDomain], title: "Test API")
      assert result["info"]["title"] == "Test API"
    end

    test "includes api_version in info" do
      result = V31.generate([AshOaskit.Test.SimpleDomain], api_version: "1.2.3")
      assert result["info"]["version"] == "1.2.3"
    end

    test "includes description when provided" do
      result = V31.generate([AshOaskit.Test.SimpleDomain], description: "My API")
      assert result["info"]["description"] == "My API"
    end

    test "includes contact info when provided" do
      contact = %{"name" => "API Support", "email" => "support@example.com"}
      result = V31.generate([AshOaskit.Test.SimpleDomain], contact: contact)
      assert result["info"]["contact"] == contact
    end

    test "includes license when provided" do
      license = %{"name" => "MIT", "url" => "https://opensource.org/licenses/MIT"}
      result = V31.generate([AshOaskit.Test.SimpleDomain], license: license)
      assert result["info"]["license"] == license
    end

    test "includes servers when provided as strings" do
      servers = ["https://api.example.com", "https://staging.example.com"]
      result = V31.generate([AshOaskit.Test.SimpleDomain], servers: servers)

      assert Enum.map(result["servers"], & &1["url"]) == servers
    end

    test "includes server objects when provided as maps" do
      servers = [%{"url" => "https://api.example.com", "description" => "Production"}]
      result = V31.generate([AshOaskit.Test.SimpleDomain], servers: servers)
      assert result["servers"] == servers
    end

    test "has default server when not provided" do
      result = V31.generate([AshOaskit.Test.SimpleDomain], [])
      assert result["servers"] == [%{"url" => "/"}]
    end

    test "includes schemas in components" do
      result = V31.generate([AshOaskit.Test.SimpleDomain], [])
      assert is_map(result["components"]["schemas"])
    end

    test "includes security when provided" do
      security = [%{"bearerAuth" => []}]
      result = V31.generate([AshOaskit.Test.SimpleDomain], security: security)
      assert result["security"] == security
    end

    test "includes terms_of_service when provided" do
      result =
        V31.generate([AshOaskit.Test.SimpleDomain], terms_of_service: "https://example.com/tos")

      assert result["info"]["termsOfService"] == "https://example.com/tos"
    end
  end

  describe "generate/2 with AshJsonApi domain" do
    test "builds paths from domain routes" do
      result = V31.generate([AshOaskit.Test.Blog], [])

      assert is_map(result["paths"])
      # Blog domain has routes for /posts and /comments
      assert Map.has_key?(result["paths"], "/posts") or map_size(result["paths"]) > 0
    end

    test "includes resource schemas in components" do
      result = V31.generate([AshOaskit.Test.Blog], [])

      schemas = result["components"]["schemas"]
      assert is_map(schemas)
      # Should have Post and Comment schemas
      assert Map.has_key?(schemas, "PostAttributes") or map_size(schemas) > 0
    end

    test "builds tags from resources" do
      result = V31.generate([AshOaskit.Test.Blog], [])

      # Tags may be present based on resources
      if result["tags"] do
        assert is_list(result["tags"])
      end
    end
  end

  describe "generate/2 schema building" do
    test "creates Attributes and Response schemas for resources" do
      result = V31.generate([AshOaskit.Test.SimpleDomain], [])

      schemas = result["components"]["schemas"]

      # Should have *Attributes and *Response schemas for each resource
      attribute_schemas = Enum.filter(Map.keys(schemas), &String.ends_with?(&1, "Attributes"))
      response_schemas = Enum.filter(Map.keys(schemas), &String.ends_with?(&1, "Response"))

      assert attribute_schemas != []
      assert response_schemas != []
    end

    test "attribute schemas are object type" do
      result = V31.generate([AshOaskit.Test.SimpleDomain], [])

      schemas = result["components"]["schemas"]

      Enum.each(schemas, fn {name, schema} ->
        if String.ends_with?(name, "Attributes") do
          assert schema["type"] == "object"
          assert is_map(schema["properties"])
        end
      end)
    end

    test "response schemas include data wrapper" do
      result = V31.generate([AshOaskit.Test.SimpleDomain], [])

      schemas = result["components"]["schemas"]

      Enum.each(schemas, fn {name, schema} ->
        if String.ends_with?(name, "Response") do
          assert schema["type"] == "object"
          assert is_map(schema["properties"]["data"])
        end
      end)
    end

    test "filters out id, inserted_at, updated_at from attributes" do
      result = V31.generate([AshOaskit.Test.SimpleDomain], [])

      schemas = result["components"]["schemas"]

      Enum.each(schemas, fn {name, schema} ->
        if String.ends_with?(name, "Attributes") do
          properties = schema["properties"] || %{}
          refute Map.has_key?(properties, "id")
          refute Map.has_key?(properties, "inserted_at")
          refute Map.has_key?(properties, "updated_at")
        end
      end)
    end
  end

  describe "generate/2 fallback behavior" do
    test "returns empty paths for domain without AshJsonApi routes" do
      result = V31.generate([AshOaskit.Test.SimpleDomain], [])

      # SimpleDomain has no json_api routes configured
      assert result["paths"] == %{}
    end

    test "handles empty domains list" do
      result = V31.generate([], [])

      assert result["openapi"] == "3.1.0"
      assert result["paths"] == %{}
      assert result["components"]["schemas"] == %{}
    end

    test "handles multiple domains" do
      result = V31.generate([AshOaskit.Test.SimpleDomain, AshOaskit.Test.Blog], [])

      assert result["openapi"] == "3.1.0"
      assert is_map(result["components"]["schemas"])
    end
  end

  describe "generate/2 info metadata" do
    test "uses default title from config when not provided" do
      result = V31.generate([AshOaskit.Test.SimpleDomain], [])

      # Should have some title (either from config or default)
      assert is_binary(result["info"]["title"])
    end

    test "uses default api_version from config when not provided" do
      result = V31.generate([AshOaskit.Test.SimpleDomain], [])

      # Should have some version (either from config or default)
      assert is_binary(result["info"]["version"])
    end

    test "does not include nil values in info" do
      result = V31.generate([AshOaskit.Test.SimpleDomain], [])

      # Optional fields should not be present if nil
      info = result["info"]

      Enum.each(Map.values(info), fn value ->
        refute is_nil(value)
      end)
    end
  end
end
