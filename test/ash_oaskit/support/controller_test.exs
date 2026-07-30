defmodule AshOaskit.ControllerTest do
  @moduledoc false

  use AshOaskit.ConnCase, async: false

  alias AshOaskit.Controller

  describe "spec/2" do
    test "returns JSON response with OpenAPI spec" do
      conn =
        put_private(conn(:get, "/api/openapi.json"), :ash_oaskit,
          domains: [AshOaskit.Test.SimpleDomain]
        )

      result = call_controller(:spec, conn)

      assert result.status == 200
      assert get_resp_header(result, "content-type") == ["application/json; charset=utf-8"]

      body = Jason.decode!(result.resp_body)
      assert body["openapi"] == "3.1.0"
    end

    test "uses domains from conn.private" do
      conn =
        put_private(conn(:get, "/api/openapi.json"), :ash_oaskit,
          domains: [AshOaskit.Test.SimpleDomain],
          title: "My API"
        )

      result = call_controller(:spec, conn)
      body = Jason.decode!(result.resp_body)

      assert body["info"]["title"] == "My API"
    end

    test "merges route options with application config" do
      conn =
        put_private(conn(:get, "/api/openapi.json"), :ash_oaskit,
          domains: [AshOaskit.Test.SimpleDomain],
          api_version: "2.0.0"
        )

      result = call_controller(:spec, conn)
      body = Jason.decode!(result.resp_body)

      assert body["info"]["version"] == "2.0.0"
    end

    test "pretty-prints JSON output" do
      conn =
        put_private(conn(:get, "/api/openapi.json"), :ash_oaskit,
          domains: [AshOaskit.Test.SimpleDomain]
        )

      result = call_controller(:spec, conn)

      # Pretty-printed JSON has newlines
      assert String.contains?(result.resp_body, "\n")
    end
  end

  describe "spec_30/2" do
    test "forces OpenAPI 3.0 version" do
      conn =
        put_private(conn(:get, "/api/openapi-3.0.json"), :ash_oaskit,
          domains: [AshOaskit.Test.SimpleDomain]
        )

      result = call_controller(:spec_30, conn)
      body = Jason.decode!(result.resp_body)

      assert body["openapi"] == "3.0.3"
    end

    test "overrides version from route options" do
      conn =
        put_private(conn(:get, "/api/openapi.json"), :ash_oaskit,
          domains: [AshOaskit.Test.SimpleDomain],
          version: "3.1"
        )

      result = call_controller(:spec_30, conn)
      body = Jason.decode!(result.resp_body)

      assert body["openapi"] == "3.0.3"
    end

    test "returns 200 status" do
      conn =
        put_private(conn(:get, "/api/openapi-3.0.json"), :ash_oaskit,
          domains: [AshOaskit.Test.SimpleDomain]
        )

      result = call_controller(:spec_30, conn)

      assert result.status == 200
    end
  end

  describe "spec_31/2" do
    test "forces OpenAPI 3.1 version" do
      conn =
        put_private(conn(:get, "/api/openapi-3.1.json"), :ash_oaskit,
          domains: [AshOaskit.Test.SimpleDomain]
        )

      result = call_controller(:spec_31, conn)
      body = Jason.decode!(result.resp_body)

      assert body["openapi"] == "3.1.0"
    end

    test "overrides version from route options" do
      conn =
        put_private(conn(:get, "/api/openapi.json"), :ash_oaskit,
          domains: [AshOaskit.Test.SimpleDomain],
          version: "3.0"
        )

      result = call_controller(:spec_31, conn)
      body = Jason.decode!(result.resp_body)

      assert body["openapi"] == "3.1.0"
    end

    test "returns 200 status" do
      conn =
        put_private(conn(:get, "/api/openapi-3.1.json"), :ash_oaskit,
          domains: [AshOaskit.Test.SimpleDomain]
        )

      result = call_controller(:spec_31, conn)

      assert result.status == 200
    end
  end

  describe "get_options/1 (via spec behavior)" do
    test "filters out nil values from options" do
      conn =
        put_private(conn(:get, "/api/openapi.json"), :ash_oaskit,
          domains: [AshOaskit.Test.SimpleDomain]
        )

      result = call_controller(:spec, conn)
      body = Jason.decode!(result.resp_body)

      # Info should not have nil values
      Enum.each(body["info"], fn {_, value} ->
        refute is_nil(value)
      end)
    end

    test "raises when domains not configured" do
      conn = conn(:get, "/api/openapi.json")

      assert_raise ArgumentError, ~r/at least one domain must be specified/, fn ->
        call_controller(:spec, conn)
      end
    end

    test "prefers route options over application config" do
      # Route option should override app config
      conn =
        put_private(conn(:get, "/api/openapi.json"), :ash_oaskit,
          domains: [AshOaskit.Test.SimpleDomain],
          title: "Route Title"
        )

      result = call_controller(:spec, conn)
      body = Jason.decode!(result.resp_body)

      assert body["info"]["title"] == "Route Title"
    end
  end

  defp call_controller(action, conn) do
    apply(Controller, action, [conn, %{}])
  end
end
