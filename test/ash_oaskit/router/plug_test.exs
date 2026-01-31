defmodule AshOaskit.Router.PlugTest do
  @moduledoc """
  Tests for the AshOaskit.Router.Plug module.

  This module tests the Plug that serves OpenAPI specifications via HTTP.
  The plug is used internally by the `AshOaskit.Router` macro to handle
  requests to the OpenAPI endpoint.

  ## Test Categories

  - **Initialization** - Verifies `init/1` passes options through unchanged
  - **JSON serving** - Tests that specs are served as JSON with correct content type
  - **YAML serving** - Tests YAML output when Ymlr is available
  - **Format fallback** - Verifies unknown formats fall back to JSON
  - **Error handling** - Tests 500 response when no domains are configured
  - **Spec generation** - Tests the `generate_spec/1` helper function

  ## How It Works

  The plug reads configuration from `conn.private[:ash_oaskit]` which is set
  by the Router macro. It generates the spec on each request using the configured
  domains and version, then serializes to the requested format.
  """

  use ExUnit.Case, async: true

  alias AshOaskit.Router.Plug, as: RouterPlug
  alias AshOaskit.Test.Blog

  describe "Router.Plug request handling" do
    test "init returns opts unchanged" do
      assert RouterPlug.init(foo: :bar) == [foo: :bar]
    end

    test "serves JSON spec by default" do
      conn =
        :get
        |> Plug.Test.conn("/openapi")
        |> Plug.Conn.put_private(:ash_oaskit, %{
          domains: [Blog],
          title: "Test API",
          openapi_version: "3.1",
          format: :json
        })
        |> RouterPlug.call([])

      assert conn.status == 200
      [content_type] = Plug.Conn.get_resp_header(conn, "content-type")
      assert content_type =~ "application/json"
      body = Jason.decode!(conn.resp_body)
      assert body["openapi"] == "3.1.0" or body["openapi"] == "3.1"
    end

    test "falls back to JSON for unknown format" do
      conn =
        :get
        |> Plug.Test.conn("/openapi")
        |> Plug.Conn.put_private(:ash_oaskit, %{
          domains: [Blog],
          openapi_version: "3.1",
          format: :xml
        })
        |> RouterPlug.call([])

      assert conn.status == 200
      [content_type] = Plug.Conn.get_resp_header(conn, "content-type")
      assert content_type =~ "application/json"
    end

    test "returns 500 when no domains configured" do
      conn =
        :get
        |> Plug.Test.conn("/openapi")
        |> Plug.Conn.put_private(:ash_oaskit, %{domains: []})
        |> RouterPlug.call([])

      assert conn.status == 500
      body = Jason.decode!(conn.resp_body)
      assert body["error"] =~ "No domains"
    end

    test "serves YAML when Ymlr is available" do
      if Code.ensure_loaded?(Ymlr) do
        conn =
          :get
          |> Plug.Test.conn("/openapi")
          |> Plug.Conn.put_private(:ash_oaskit, %{
            domains: [Blog],
            openapi_version: "3.1",
            format: :yaml
          })
          |> RouterPlug.call([])

        assert conn.status == 200
        [content_type] = Plug.Conn.get_resp_header(conn, "content-type")
        assert content_type =~ "yaml"
      end
    end

    test "generate_spec uses default spec builder" do
      config = %{domains: [Blog], openapi_version: "3.1"}
      spec = RouterPlug.generate_spec(config)
      assert is_map(spec)
      assert Map.has_key?(spec, "paths")
    end
  end
end
