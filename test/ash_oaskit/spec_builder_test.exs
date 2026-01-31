defmodule AshOaskit.SpecBuilderTest do
  @moduledoc """
  Tests for the `AshOaskit.SpecBuilder` behaviour and its integration with
  `AshOaskit.Router`.

  Defines two inline spec builders to exercise the customisation surface:

  - `CustomSpecBuilder` — adds a vendor extension (`x-custom`) and a
    `bearerAuth` security scheme to every generated spec
  - `FeatureFlagSpecBuilder` — conditionally injects `x-features` based on
    an `:api_version` option, demonstrating option pass-through

  Two test routers wire these builders into the Router macro so the full
  request path (HTTP request -> Router -> Plug -> SpecBuilder -> spec) is
  covered end-to-end.

  ## Test Categories

  - **SpecBuilder.Default** — verifies the zero-configuration builder produces
    a standard spec without vendor extensions and correctly forwards all
    info-level options (title, version, description, servers)
  - **Custom spec_builder with Router** — confirms that a custom builder's
    additions (extensions, security schemes) appear in the served JSON for
    both OpenAPI 3.0 and 3.1 routes
  - **Default spec_builder with Router** — ensures that omitting the
    `:spec_builder` option falls back to `SpecBuilder.Default`
  - **Router.Plug.generate_spec/1** — unit-tests the low-level generation
    function directly, verifying builder selection without HTTP round-trips
  """

  use ExUnit.Case, async: true

  import Plug.Conn
  import Plug.Test

  alias AshOaskit.Router
  alias AshOaskit.SpecBuilder

  # Custom SpecBuilder for testing
  defmodule CustomSpecBuilder do
    @behaviour AshOaskit.SpecBuilder

    @impl true
    def spec(openapi_version, opts) do
      spec =
        AshOaskit.spec(
          domains: opts[:domains],
          version: openapi_version,
          title: opts[:title]
        )

      spec
      |> Map.put("x-custom", "test-value")
      |> put_in(["components", "securitySchemes"], %{
        "bearerAuth" => %{"type" => "http", "scheme" => "bearer"}
      })
    end
  end

  # SpecBuilder that adds feature flags based on custom option
  defmodule FeatureFlagSpecBuilder do
    @behaviour AshOaskit.SpecBuilder

    @impl true
    def spec(openapi_version, opts) do
      api_version = opts[:api_version] || :default

      spec =
        AshOaskit.spec(
          domains: opts[:domains],
          version: openapi_version,
          title: opts[:title]
        )

      add_feature_flags(spec, api_version)
    end

    defp add_feature_flags(spec, :v1), do: Map.put(spec, "x-features", %{"legacy" => true})
    defp add_feature_flags(spec, :v2), do: Map.put(spec, "x-features", %{"modern" => true})
    defp add_feature_flags(spec, _), do: spec
  end

  defmodule TestRouterWithCustomBuilder do
    use Plug.Router

    plug(:match)
    plug(:dispatch)

    use AshOaskit.Router,
      spec_builder: CustomSpecBuilder,
      domains: [AshOaskit.Test.Blog],
      open_api: "/openapi",
      title: "Custom API"

    match _ do
      send_resp(conn, 404, "Not Found")
    end
  end

  defmodule TestRouterWithDefaultBuilder do
    use Plug.Router

    plug(:match)
    plug(:dispatch)

    # No spec_builder option - should use Default
    use AshOaskit.Router,
      domains: [AshOaskit.Test.Blog],
      open_api: "/openapi",
      title: "Default API"

    match _ do
      send_resp(conn, 404, "Not Found")
    end
  end

  describe "SpecBuilder.Default" do
    test "generates spec without customization" do
      config = %{
        domains: [AshOaskit.Test.Blog],
        title: "Test API",
        version: "1.0.0"
      }

      spec = SpecBuilder.Default.spec("3.1", config)

      assert spec["openapi"] =~ "3.1"
      assert spec["info"]["title"] == "Test API"
      refute Map.has_key?(spec, "x-custom")
    end

    test "passes through all options" do
      config = %{
        domains: [AshOaskit.Test.Blog],
        title: "My API",
        version: "2.0.0",
        description: "Test description",
        servers: [%{url: "https://api.example.com"}]
      }

      spec = SpecBuilder.Default.spec("3.0", config)

      assert spec["openapi"] =~ "3.0"
      assert spec["info"]["title"] == "My API"
      assert spec["info"]["version"] == "2.0.0"
      assert spec["info"]["description"] == "Test description"
    end
  end

  describe "custom spec_builder with Router" do
    test "uses custom builder to generate spec" do
      conn = conn(:get, "/openapi.json")
      conn = TestRouterWithCustomBuilder.call(conn, [])

      assert conn.status == 200
      spec = Jason.decode!(conn.resp_body)

      # Custom extension added by CustomSpecBuilder
      assert spec["x-custom"] == "test-value"

      # Security schemes added by CustomSpecBuilder
      assert get_in(spec, ["components", "securitySchemes", "bearerAuth"])
      assert get_in(spec, ["components", "securitySchemes", "bearerAuth", "type"]) == "http"
    end

    test "custom builder works with OpenAPI 3.0" do
      conn = conn(:get, "/openapi/3.0.json")
      conn = TestRouterWithCustomBuilder.call(conn, [])

      assert conn.status == 200
      spec = Jason.decode!(conn.resp_body)

      assert spec["openapi"] =~ "3.0"
      assert spec["x-custom"] == "test-value"
    end

    test "custom builder works with OpenAPI 3.1" do
      conn = conn(:get, "/openapi/3.1.json")
      conn = TestRouterWithCustomBuilder.call(conn, [])

      assert conn.status == 200
      spec = Jason.decode!(conn.resp_body)

      assert spec["openapi"] =~ "3.1"
      assert spec["x-custom"] == "test-value"
    end
  end

  describe "default spec_builder with Router" do
    test "uses Default builder when spec_builder not specified" do
      conn = conn(:get, "/openapi.json")
      conn = TestRouterWithDefaultBuilder.call(conn, [])

      assert conn.status == 200
      spec = Jason.decode!(conn.resp_body)

      # Should NOT have custom extensions
      refute Map.has_key?(spec, "x-custom")

      # Should have standard spec
      assert spec["info"]["title"] == "Default API"
    end
  end

  describe "Router.Plug.generate_spec/1" do
    test "uses custom spec_builder when provided" do
      config = %{
        spec_builder: CustomSpecBuilder,
        domains: [AshOaskit.Test.Blog],
        title: "Test",
        openapi_version: "3.1"
      }

      spec = Router.Plug.generate_spec(config)

      assert spec["x-custom"] == "test-value"
    end

    test "falls back to Default when spec_builder not provided" do
      config = %{
        domains: [AshOaskit.Test.Blog],
        title: "Test",
        openapi_version: "3.1"
      }

      spec = Router.Plug.generate_spec(config)

      refute Map.has_key?(spec, "x-custom")
    end
  end
end
