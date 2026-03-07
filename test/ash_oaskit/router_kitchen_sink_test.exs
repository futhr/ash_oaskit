defmodule AshOaskit.RouterKitchenSinkTest do
  @moduledoc """
  Kitchen sink test for `AshOaskit.Router` in a Phoenix Router context.

  Exercises a realistic Phoenix Router setup with multiple domains, pipelines,
  scopes, and `use AshOaskit.Router` generating OpenAPI spec routes alongside
  regular application routes.
  """

  use ExUnit.Case, async: true

  import Plug.Test

  # Phoenix Router with AshOaskit.Router — realistic multi-domain setup
  defmodule PhoenixRouter do
    use Phoenix.Router

    use AshOaskit.Router,
      domains: [AshOaskit.Test.Blog, AshOaskit.Test.Lab],
      open_api: "/docs/openapi",
      title: "KitchenSink API",
      version: "2.0.0",
      description: "Multi-domain kitchen sink test"

    pipeline :api do
      plug(:accepts, ["json"])
    end

    scope "/api" do
      pipe_through(:api)

      get "/health", AshOaskit.RouterKitchenSinkTest.HealthPlug, :index
    end
  end

  # Minimal plug to serve as a Phoenix controller stand-in
  defmodule HealthPlug do
    @behaviour Plug

    @impl true
    def init(opts), do: opts

    @impl true
    def call(conn, _) do
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, Jason.encode!(%{status: "ok"}))
    end
  end

  defp call_router(method, path) do
    conn = conn(method, path)
    PhoenixRouter.call(conn, PhoenixRouter.init([]))
  end

  describe "Phoenix Router default route" do
    test "serves spec at /docs/openapi.json" do
      conn = call_router(:get, "/docs/openapi.json")

      assert conn.status == 200
      assert hd(Plug.Conn.get_resp_header(conn, "content-type")) =~ "application/json"
    end

    test "returns valid OpenAPI spec with correct info" do
      conn = call_router(:get, "/docs/openapi.json")
      spec = Jason.decode!(conn.resp_body)

      assert spec["info"]["title"] == "KitchenSink API"
      assert spec["info"]["version"] == "2.0.0"
      assert spec["info"]["description"] == "Multi-domain kitchen sink test"
    end

    test "default route serves OpenAPI 3.1 by default" do
      conn = call_router(:get, "/docs/openapi.json")
      spec = Jason.decode!(conn.resp_body)

      assert spec["openapi"] =~ "3.1"
    end
  end

  describe "Phoenix Router version-specific routes" do
    test "serves OpenAPI 3.0 at /docs/openapi/3.0.json" do
      conn = call_router(:get, "/docs/openapi/3.0.json")

      assert conn.status == 200

      spec = Jason.decode!(conn.resp_body)
      assert spec["openapi"] =~ "3.0"
    end

    test "serves OpenAPI 3.1 at /docs/openapi/3.1.json" do
      conn = call_router(:get, "/docs/openapi/3.1.json")

      assert conn.status == 200

      spec = Jason.decode!(conn.resp_body)
      assert spec["openapi"] =~ "3.1"
    end
  end

  describe "Phoenix Router multi-domain spec" do
    test "includes paths from multiple domains" do
      conn = call_router(:get, "/docs/openapi.json")
      spec = Jason.decode!(conn.resp_body)
      paths = Map.keys(spec["paths"] || %{})

      # Blog domain resources should generate paths
      assert paths != []
    end
  end

  describe "Phoenix Router coexistence" do
    test "non-spec routes still work" do
      conn = call_router(:get, "/api/health")

      assert conn.status == 200
      assert Jason.decode!(conn.resp_body) == %{"status" => "ok"}
    end

    test "unknown routes raise NoRouteError" do
      assert_raise Phoenix.Router.NoRouteError, fn ->
        call_router(:get, "/nonexistent")
      end
    end
  end
end
