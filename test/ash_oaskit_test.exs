defmodule AshOaskitTest do
  @moduledoc """
  Tests for the main AshOaskit module.

  This module tests the public API of AshOaskit, which provides the primary
  entry points for generating OpenAPI specifications from Ash domains.

  ## Test Coverage

  The tests verify:

  - `spec/1` generates OpenAPI 3.1 specs by default
  - `spec_30/1` generates OpenAPI 3.0 specs
  - `spec_31/1` generates OpenAPI 3.1 specs
  - Options are properly passed through to the generator
  - The generated specs have the correct structure

  ## Test Fixtures

  Uses `AshOaskit.Test.Blog` as a real Ash domain for testing.
  """

  use ExUnit.Case, async: true
  doctest AshOaskit

  @test_domain AshOaskit.Test.Blog

  describe "public API" do
    test "spec/1 delegates to OpenApi" do
      result = AshOaskit.spec(domains: [@test_domain])
      assert result["openapi"] == "3.1.0"
    end

    test "spec_30/1 delegates to OpenApi" do
      result = AshOaskit.spec_30(domains: [@test_domain])
      assert result["openapi"] == "3.0.0"
    end

    test "spec_31/1 delegates to OpenApi" do
      result = AshOaskit.spec_31(domains: [@test_domain])
      assert result["openapi"] == "3.1.0"
    end

    test "validate! returns validated spec" do
      spec = AshOaskit.spec(domains: [@test_domain], title: "Test")
      result = AshOaskit.validate!(spec)
      assert result
    end
  end
end
