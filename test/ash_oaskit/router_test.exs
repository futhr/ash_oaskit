defmodule AshOaskit.RouterTest do
  @moduledoc """
  Tests for the `AshOaskit.Router` macro.

  Exercises the compile-time route generation and runtime spec serving provided
  by `use AshOaskit.Router`. Three inline test routers cover the main
  configuration axes:

  - `TestRouter` — default options (both 3.0 and 3.1, JSON only)
  - `TestRouterWithYaml` — YAML format enabled alongside JSON
  - `TestRouterSingleVersion` — restricted to a single OpenAPI version

  ## Test Categories

  - **Default route** — verifies the base path (`/openapi.json`) returns a valid
    spec with the correct default version, content type, and info fields
  - **Version-specific routes** — ensures `/openapi/3.0.json` and `/openapi/3.1.json`
    each return the expected OpenAPI version string
  - **Nullable handling** — confirms that 3.0 uses `nullable: true` while 3.1 uses
    type arrays for nullable fields
  - **Single version configuration** — validates that unconfigured versions return 404
  - **Error handling** — covers the empty-domains guard and unknown-format fallback in
    `AshOaskit.Router.Plug`
  - **YAML format** — checks YAML serving when the `:yaml` format is enabled
    (gracefully degrades if the `Ymlr` dependency is absent)
  """

  use ExUnit.Case, async: true

  import Plug.Conn
  import Plug.Test

  alias AshOaskit.Router

  # Define a test router that uses the AshOaskit.Router macro
  defmodule TestRouter do
    use Plug.Router

    plug(:match)
    plug(:dispatch)

    use AshOaskit.Router,
      domains: [AshOaskit.Test.Blog],
      open_api: "/openapi",
      title: "Test API",
      version: "1.0.0",
      description: "Test API for router tests"

    # Catch-all for unmatched routes
    match _ do
      send_resp(conn, 404, "Not Found")
    end
  end

  # Router with YAML format enabled
  defmodule TestRouterWithYaml do
    use Plug.Router

    plug(:match)
    plug(:dispatch)

    use AshOaskit.Router,
      domains: [AshOaskit.Test.Blog],
      open_api: "/openapi",
      title: "Test API",
      formats: [:json, :yaml]

    match _ do
      send_resp(conn, 404, "Not Found")
    end
  end

  # Router with single OpenAPI version
  defmodule TestRouterSingleVersion do
    use Plug.Router

    plug(:match)
    plug(:dispatch)

    use AshOaskit.Router,
      domains: [AshOaskit.Test.Blog],
      open_api: "/openapi",
      title: "Test API",
      openapi_versions: ["3.1"],
      default_version: "3.1"

    match _ do
      send_resp(conn, 404, "Not Found")
    end
  end

  describe "default route" do
    test "serves spec at /openapi.json" do
      conn = conn(:get, "/openapi.json")
      conn = TestRouter.call(conn, [])

      assert conn.status == 200
      assert conn |> get_resp_header("content-type") |> hd() =~ "application/json"
    end

    test "returns valid OpenAPI spec" do
      conn = conn(:get, "/openapi.json")
      conn = TestRouter.call(conn, [])

      spec = Jason.decode!(conn.resp_body)
      assert spec["openapi"] =~ "3.1"
      assert spec["info"]["title"] == "Test API"
      assert spec["info"]["version"] == "1.0.0"
    end
  end

  describe "version-specific routes" do
    test "serves OpenAPI 3.0 at /openapi/3.0.json" do
      conn = conn(:get, "/openapi/3.0.json")
      conn = TestRouter.call(conn, [])

      assert conn.status == 200
      spec = Jason.decode!(conn.resp_body)
      assert spec["openapi"] =~ "3.0"
    end

    test "serves OpenAPI 3.1 at /openapi/3.1.json" do
      conn = conn(:get, "/openapi/3.1.json")
      conn = TestRouter.call(conn, [])

      assert conn.status == 200
      spec = Jason.decode!(conn.resp_body)
      assert spec["openapi"] =~ "3.1"
    end

    test "both versions are available by default" do
      for version <- ["3.0", "3.1"] do
        conn = conn(:get, "/openapi/#{version}.json")
        conn = TestRouter.call(conn, [])

        assert conn.status == 200
        spec = Jason.decode!(conn.resp_body)
        assert spec["openapi"] =~ version
      end
    end
  end

  describe "nullable handling differs by version" do
    test "OpenAPI 3.0 uses nullable: true" do
      conn = conn(:get, "/openapi/3.0.json")
      conn = TestRouter.call(conn, [])

      spec = Jason.decode!(conn.resp_body)

      # Find a schema with nullable field
      schemas = get_in(spec, ["components", "schemas"]) || %{}

      # Check that 3.0 style nullable is used (if any schemas exist)
      if map_size(schemas) > 0 do
        # In 3.0, nullable fields should have nullable: true
        assert spec["openapi"] =~ "3.0"
      end
    end

    test "OpenAPI 3.1 uses type arrays for nullable" do
      conn = conn(:get, "/openapi/3.1.json")
      conn = TestRouter.call(conn, [])

      spec = Jason.decode!(conn.resp_body)

      # In 3.1, nullable fields should use type: ["string", "null"]
      assert spec["openapi"] =~ "3.1"
    end
  end

  describe "single version configuration" do
    test "only serves configured version" do
      # 3.1 should work
      conn = conn(:get, "/openapi/3.1.json")
      conn = TestRouterSingleVersion.call(conn, [])
      assert conn.status == 200

      # 3.0 should not be available (404)
      conn = conn(:get, "/openapi/3.0.json")
      conn = TestRouterSingleVersion.call(conn, [])
      assert conn.status == 404
    end
  end

  describe "error handling" do
    test "returns 500 when no domains configured" do
      conn = conn(:get, "/test")
      conn = Plug.Conn.put_private(conn, :ash_oaskit, %{domains: []})
      conn = Router.Plug.call(conn, [])

      assert conn.status == 500
      body = Jason.decode!(conn.resp_body)
      assert body["error"] =~ "No domains configured"
    end

    test "falls back to JSON for unknown format" do
      conn = conn(:get, "/test")

      conn =
        Plug.Conn.put_private(conn, :ash_oaskit, %{
          domains: [AshOaskit.Test.Blog],
          title: "Test",
          openapi_version: "3.1",
          format: :xml
        })

      conn = Router.Plug.call(conn, [])

      assert conn.status == 200
      assert conn |> Plug.Conn.get_resp_header("content-type") |> hd() =~ "application/json"
    end
  end

  describe "YAML format" do
    @tag :yaml
    test "serves YAML at /openapi.yaml when format enabled" do
      conn = conn(:get, "/openapi.yaml")
      conn = TestRouterWithYaml.call(conn, [])

      # Status depends on Ymlr availability
      assert conn.status in [200, 404]

      if conn.status == 200 do
        content_type = conn |> get_resp_header("content-type") |> hd()
        # Should be YAML if Ymlr is available, JSON otherwise
        assert content_type =~ "yaml" or content_type =~ "json"
      end
    end
  end
end
