defmodule AshOaskitTest do
  @moduledoc false

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
      assert result["openapi"] == "3.0.3"
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
