defmodule AshOaskit.Router.PlugTest do
  @moduledoc false

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
      assert conn.resp_body =~ "openapi"
    end

    test "generate_spec uses default spec builder" do
      config = %{domains: [Blog], openapi_version: "3.1"}
      spec = RouterPlug.generate_spec(config)
      assert is_map(spec)
      assert Map.has_key?(spec, "paths")
    end
  end
end
