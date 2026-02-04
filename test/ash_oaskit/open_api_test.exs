defmodule AshOaskit.OpenApiTest do
  @moduledoc """
  Tests for the AshOaskit.OpenApi module.

  This module tests the core OpenAPI specification generation,
  including version routing, option handling, and output structure.

  ## Test Coverage

  - **Version Handling** - Tests for 3.0 and 3.1 version strings
  - **Option Validation** - Ensures required options are checked
  - **Info Section** - Tests title, version, description propagation
  - **Servers** - Tests server configuration and defaults
  - **Struct Conversion** - Tests to_map/1 for struct handling

  ## Test Fixtures

  Uses `AshOaskit.Test.Blog` as a real Ash domain for testing.
  """

  use ExUnit.Case, async: true
  doctest AshOaskit.OpenApi

  alias AshOaskit.OpenApi

  # Use a real test domain
  @test_domain AshOaskit.Test.Blog

  describe "spec/1" do
    test "requires domains option" do
      assert_raise ArgumentError, ~r/at least one domain/, fn ->
        OpenApi.spec([])
      end
    end

    test "raises on unsupported version" do
      assert_raise ArgumentError, ~r/Unsupported OpenAPI version/i, fn ->
        OpenApi.spec(domains: [@test_domain], version: "2.0")
      end
    end

    test "accepts 3.0 version string" do
      result = OpenApi.spec(domains: [@test_domain], version: "3.0")
      assert result["openapi"] == "3.0.3"
    end

    test "accepts 3.0.0 version string" do
      result = OpenApi.spec(domains: [@test_domain], version: "3.0.0")
      assert result["openapi"] == "3.0.3"
    end

    test "accepts 3.0.3 version string" do
      result = OpenApi.spec(domains: [@test_domain], version: "3.0.3")
      assert result["openapi"] == "3.0.3"
    end

    test "accepts 3.1 version string" do
      result = OpenApi.spec(domains: [@test_domain], version: "3.1")
      assert result["openapi"] == "3.1.0"
    end

    test "accepts 3.1.0 version string" do
      result = OpenApi.spec(domains: [@test_domain], version: "3.1.0")
      assert result["openapi"] == "3.1.0"
    end

    test "defaults to 3.1" do
      result = OpenApi.spec(domains: [@test_domain])
      assert result["openapi"] == "3.1.0"
    end

    test "includes info section with title" do
      result = OpenApi.spec(domains: [@test_domain], title: "My API")
      assert result["info"]["title"] == "My API"
    end

    test "includes api_version in info" do
      result = OpenApi.spec(domains: [@test_domain], api_version: "2.0.0")
      assert result["info"]["version"] == "2.0.0"
    end

    test "includes description in info" do
      result = OpenApi.spec(domains: [@test_domain], description: "API description")
      assert result["info"]["description"] == "API description"
    end

    test "includes servers" do
      servers = [%{"url" => "https://api.example.com"}]
      result = OpenApi.spec(domains: [@test_domain], servers: servers)
      assert result["servers"] == servers
    end

    test "includes default server when not specified" do
      result = OpenApi.spec(domains: [@test_domain])
      assert result["servers"] == [%{"url" => "/"}]
    end
  end

  describe "spec_30/1" do
    test "generates OpenAPI 3.0 spec" do
      result = OpenApi.spec_30(domains: [@test_domain])
      assert result["openapi"] == "3.0.3"
    end
  end

  describe "spec_31/1" do
    test "generates OpenAPI 3.1 spec" do
      result = OpenApi.spec_31(domains: [@test_domain])
      assert result["openapi"] == "3.1.0"
    end
  end

  describe "to_map/1" do
    test "passes through maps unchanged" do
      input = %{"openapi" => "3.1.0"}
      assert OpenApi.to_map(input) == input
    end

    test "converts struct to map via JSON roundtrip" do
      # Generate a spec and validate it to get an Oaskit struct
      spec = OpenApi.spec(domains: [@test_domain])
      {:ok, validated} = Oaskit.SpecValidator.validate(spec)

      result = OpenApi.to_map(validated)

      assert is_map(result)
      refute is_struct(result)
      assert result["openapi"] == "3.1.0"
      assert is_binary(result["info"]["title"])
    end
  end

  describe "validate/1" do
    test "returns ok tuple for valid spec" do
      spec = OpenApi.spec(domains: [@test_domain])
      assert {:ok, %Oaskit.Spec.OpenAPI{}} = OpenApi.validate(spec)
    end

    test "returns error tuple for invalid spec" do
      assert {:error, _} = OpenApi.validate(%{"invalid" => true})
    end
  end

  describe "validate!/1" do
    test "returns struct for valid spec" do
      spec = OpenApi.spec(domains: [@test_domain])
      assert %Oaskit.Spec.OpenAPI{} = OpenApi.validate!(spec)
    end

    test "raises for invalid spec" do
      assert_raise Oaskit.SpecValidator.Error, fn ->
        OpenApi.validate!(%{"openapi" => "3.1.0", "info" => %{}, "paths" => %{}})
      end
    end
  end
end
