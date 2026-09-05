defmodule AshOaskit.SpecBuilder.DefaultTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias AshOaskit.SpecBuilder.Default

  test "forwards customization, metadata, and resource scope independently of the OAS version" do
    for version <- ["3.0", "3.1"] do
      spec =
        Default.spec(version, %{
          domains: [AshOaskit.Test.SimpleDomain],
          version: "2.0.0",
          resource_scope: :routed,
          contact: %{name: "Support"},
          external_docs: %{url: "https://example.com/docs"},
          security: [],
          modify_open_api: fn spec -> Map.put(spec, "x-customized", true) end
        })

      assert spec["openapi"] =~ version
      assert spec["info"]["version"] == "2.0.0"
      assert spec["info"]["contact"]["name"] == "Support"
      assert spec["externalDocs"]["url"] == "https://example.com/docs"
      assert spec["security"] == []
      assert spec["components"]["schemas"] == %{}
      assert spec["x-customized"]
    end
  end
end
