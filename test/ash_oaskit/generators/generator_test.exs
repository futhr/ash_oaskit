defmodule AshOaskit.Generators.GeneratorTest do
  @moduledoc """
  Tests for the AshOaskit.Generators.Generator module.

  This module tests the main OpenAPI specification generator that orchestrates
  all builders (info, paths, schemas, components) into a complete spec.

  ## Test Categories

  - **Hook application** - `modify_open_api` function and MFA callbacks
  - **Version routing** - Dispatching to V30 or V31 generators
  - **Option forwarding** - Title, version, servers, and other configuration
  - **Complete generation** - End-to-end spec generation from Ash domains

  ## Why These Tests Matter

  The Generator is the central orchestrator. It must correctly combine output
  from InfoBuilder, PathBuilder, SchemaBuilder, and version-specific generators
  while applying user-defined hooks in the right order.
  """

  use ExUnit.Case, async: true

  alias AshOaskit.Generators.Generator

  describe "generate/2 with modify_open_api hook" do
    test "applies function hook" do
      spec =
        Generator.generate([AshOaskit.Test.Blog],
          version: "3.1",
          title: "Test",
          modify_open_api: fn s -> Map.put(s, "x-modified", true) end
        )

      assert spec["x-modified"] == true
    end

    test "applies MFA hook" do
      spec =
        Generator.generate([AshOaskit.Test.Blog],
          version: "3.1",
          title: "Test",
          modify_open_api: {Map, :put, ["x-mfa", "applied"]}
        )

      assert spec["x-mfa"] == "applied"
    end

    test "ignores invalid hook values" do
      spec =
        Generator.generate([AshOaskit.Test.Blog],
          version: "3.1",
          title: "Test",
          modify_open_api: :invalid
        )

      assert spec["openapi"] =~ "3.1"
    end

    test "generates without hook" do
      spec =
        Generator.generate([AshOaskit.Test.Blog],
          version: "3.1",
          title: "Test"
        )

      assert spec["openapi"] =~ "3.1"
    end
  end

  describe "generate/2 with router option" do
    test "includes controller tags when router is provided" do
      defmodule FakeController do
        @behaviour AshOaskit.OpenApiController

        @impl true
        def openapi_operations do
          %{
            index: %{
              "summary" => "Test",
              "responses" => %{"200" => %{"description" => "OK"}}
            }
          }
        end

        @impl true
        def openapi_tag, do: "FakeTag"
      end

      defmodule FakeRouter do
        @spec __routes__() :: [map()]
        def __routes__ do
          [%{path: "/fake", verb: :get, plug: FakeController, plug_opts: :index}]
        end
      end

      spec =
        Generator.generate([AshOaskit.Test.Blog],
          version: "3.1",
          title: "Test",
          router: FakeRouter
        )

      tag_names = Enum.map(spec["tags"] || [], & &1["name"])
      assert "FakeTag" in tag_names
    end
  end

  describe "build_components/2" do
    test "builds schemas for 3.0 version" do
      components = Generator.build_components([AshOaskit.Test.Blog], version: "3.0")
      schemas = components["schemas"]
      assert is_map(schemas)
      assert map_size(schemas) > 0
    end

    test "builds schemas for 3.1 version" do
      components = Generator.build_components([AshOaskit.Test.Blog], version: "3.1")
      schemas = components["schemas"]
      assert is_map(schemas)
      assert map_size(schemas) > 0
    end
  end
end
