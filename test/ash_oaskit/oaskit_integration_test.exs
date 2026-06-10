defmodule AshOaskit.OaskitIntegrationTest do
  @moduledoc """
  Integration tests for serving spec modules through the oaskit stack.

  Covers the `use AshOaskit.Router` spec-module mode (JSON serving via
  `Oaskit.SpecController`, multi-version routes, Redoc UI, response
  headers) in both Plug.Router and Phoenix.Router, plus the
  `Oaskit.Plugs.SpecProvider` pipeline pattern.
  """

  use ExUnit.Case, async: true

  import Plug.Conn
  import Plug.Test

  defmodule ApiSpec do
    @moduledoc false
    use AshOaskit,
      domains: [AshOaskit.Test.Blog],
      title: "Integration API",
      api_version: "1.2.3"
  end

  defmodule ApiSpec30 do
    @moduledoc false
    use AshOaskit,
      domains: [AshOaskit.Test.Blog],
      version: "3.0",
      title: "Integration API"
  end

  defmodule SpecModeRouter do
    use Plug.Router

    plug(:match)
    plug(:dispatch)

    use AshOaskit.Router,
      spec: AshOaskit.OaskitIntegrationTest.ApiSpec,
      open_api: "/openapi",
      redoc: "/redoc"

    match _ do
      send_resp(conn, 404, "Not Found")
    end
  end

  defmodule MultiVersionRouter do
    use Plug.Router

    plug(:match)
    plug(:dispatch)

    use AshOaskit.Router,
      spec: [
        {"3.1", AshOaskit.OaskitIntegrationTest.ApiSpec},
        {"3.0", AshOaskit.OaskitIntegrationTest.ApiSpec30}
      ],
      open_api: "/openapi"

    match _ do
      send_resp(conn, 404, "Not Found")
    end
  end

  defmodule HeadersRouter do
    use Plug.Router

    plug(:match)
    plug(:dispatch)

    use AshOaskit.Router,
      spec: AshOaskit.OaskitIntegrationTest.ApiSpec,
      open_api: "/openapi",
      resp_headers: %{"access-control-allow-origin" => "*"}

    match _ do
      send_resp(conn, 404, "Not Found")
    end
  end

  defmodule PhoenixSpecRouter do
    use Phoenix.Router

    use AshOaskit.Router,
      spec: AshOaskit.OaskitIntegrationTest.ApiSpec,
      open_api: "/openapi",
      redoc: "/redoc"
  end

  defmodule ProviderPipeline do
    use Plug.Router

    plug(Oaskit.Plugs.SpecProvider, spec: AshOaskit.OaskitIntegrationTest.ApiSpec)
    plug(:match)
    plug(:dispatch)

    get "/openapi.json" do
      # credo:disable-for-next-line Credo.Check.Design.AliasUsage
      Oaskit.SpecController.call(conn, Oaskit.SpecController.init(:show))
    end

    match _ do
      send_resp(conn, 404, "Not Found")
    end
  end

  describe "Plug.Router spec mode" do
    test "serves the spec module as JSON" do
      conn = SpecModeRouter.call(conn(:get, "/openapi.json"), [])

      assert conn.status == 200
      assert conn |> get_resp_header("content-type") |> hd() =~ "application/json"

      spec = JSV.Codec.decode!(conn.resp_body)
      assert spec["openapi"] == "3.1.0"
      assert spec["info"]["title"] == "Integration API"
      assert spec["info"]["version"] == "1.2.3"
    end

    test "?pretty=1 pretty-prints the JSON" do
      conn = SpecModeRouter.call(conn(:get, "/openapi.json?pretty=1"), [])

      assert conn.status == 200
      assert conn.resp_body =~ "\n"
    end

    test "serves the Redoc UI pointing at the spec endpoint" do
      conn = SpecModeRouter.call(conn(:get, "/redoc"), [])

      assert conn.status == 200
      assert conn |> get_resp_header("content-type") |> hd() =~ "text/html"
      assert conn.resp_body =~ "Redoc.init"
      assert conn.resp_body =~ "/openapi.json"
    end

    test "the spec is cached after the first request" do
      SpecModeRouter.call(conn(:get, "/openapi.json"), [])

      key = {:ash_oaskit_cache, ApiSpec, nil}
      assert :persistent_term.get(key, :missing) != :missing
    end
  end

  describe "multi-version spec mode" do
    test "serves the first entry at the base path" do
      conn = MultiVersionRouter.call(conn(:get, "/openapi.json"), [])

      assert JSV.Codec.decode!(conn.resp_body)["openapi"] == "3.1.0"
    end

    test "serves each version at its suffix" do
      conn31 = MultiVersionRouter.call(conn(:get, "/openapi/3.1.json"), [])
      conn30 = MultiVersionRouter.call(conn(:get, "/openapi/3.0.json"), [])

      assert JSV.Codec.decode!(conn31.resp_body)["openapi"] == "3.1.0"
      assert JSV.Codec.decode!(conn30.resp_body)["openapi"] == "3.0.3"
    end
  end

  describe "response headers" do
    test "resp_headers are applied to the JSON endpoint" do
      conn = HeadersRouter.call(conn(:get, "/openapi.json"), [])

      assert get_resp_header(conn, "access-control-allow-origin") == ["*"]
    end
  end

  describe "Phoenix.Router spec mode" do
    test "serves the spec module as JSON" do
      conn = PhoenixSpecRouter.call(conn(:get, "/openapi.json"), [])

      assert conn.status == 200
      assert JSV.Codec.decode!(conn.resp_body)["info"]["title"] == "Integration API"
    end

    test "serves the Redoc UI" do
      conn = PhoenixSpecRouter.call(conn(:get, "/redoc"), [])

      assert conn.status == 200
      assert conn.resp_body =~ "Redoc.init"
    end
  end

  describe "SpecProvider pipeline" do
    test "SpecController :show serves the provided spec module" do
      conn = ProviderPipeline.call(conn(:get, "/openapi.json"), [])

      assert conn.status == 200
      assert JSV.Codec.decode!(conn.resp_body)["info"]["title"] == "Integration API"
    end
  end

  describe "option validation" do
    test "passing both :spec and :domains raises" do
      assert_raise ArgumentError, ~r/either :spec or :domains/, fn ->
        defmodule BothModesRouter do
          use Plug.Router

          plug(:match)
          plug(:dispatch)

          use AshOaskit.Router,
            spec: AshOaskit.OaskitIntegrationTest.ApiSpec,
            domains: [AshOaskit.Test.Blog],
            open_api: "/openapi"
        end
      end
    end

    test "passing a non-module :spec raises" do
      assert_raise ArgumentError, ~r/spec module or a list/, fn ->
        defmodule BadSpecRouter do
          use Plug.Router

          plug(:match)
          plug(:dispatch)

          use AshOaskit.Router,
            spec: "not a module",
            open_api: "/openapi"
        end
      end
    end
  end
end
