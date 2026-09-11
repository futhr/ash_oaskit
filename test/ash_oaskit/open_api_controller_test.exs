defmodule AshOaskit.OpenApiControllerTest do
  use ExUnit.Case, async: true
  import Plug.Conn
  import Plug.Test

  defmodule ReportController do
    @behaviour AshOaskit.OpenApiController
    use Phoenix.Controller, formats: [:json], layouts: []
    use Oaskit.Controller
    plug(Oaskit.Plugs.ValidateRequest)
    use_operation(:create, "create_report")

    @report_schema %{
      "type" => "object",
      "required" => ["name"],
      "properties" => %{"name" => %{"type" => "string"}}
    }

    @impl AshOaskit.OpenApiController
    def openapi_operations do
      %{
        create: %{
          operationId: "create_report",
          requestBody: %{
            required: true,
            content: %{"application/json" => %{schema: @report_schema}}
          },
          responses: %{
            "200" => %{
              description: "Created report",
              content: %{"application/json" => %{schema: @report_schema}}
            }
          }
        }
      }
    end

    @spec create(Plug.Conn.t(), map()) :: Plug.Conn.t()
    def create(conn, _) do
      %{"name" => name} = body_params(conn)
      json(conn, %{"name" => name})
    end
  end

  defmodule Router do
    use Phoenix.Router

    pipeline :api do
      plug(Oaskit.Plugs.SpecProvider, spec: AshOaskit.OpenApiControllerTest.ApiSpec)
    end

    scope "/api" do
      pipe_through :api
      post "/reports", ReportController, :create
    end
  end

  defmodule ApiSpec do
    use AshOaskit, domains: [AshOaskit.Test.SimpleDomain], router: Router, cache: false
  end

  test "the documented explicit controller contract validates requests and responses" do
    spec = ApiSpec.spec()
    assert spec["paths"]["/api/reports"]["post"]["operationId"] == "create_report"
    assert {operations, _} = Oaskit.build_spec!(ApiSpec, responses: true, cache: false)
    assert Map.has_key?(operations, "create_report")

    valid = request(%{"name" => "Q3"})
    assert valid.status == 200
    assert Oaskit.Test.valid_response(ApiSpec, valid, 200) == %{"name" => "Q3"}

    for payload <- [%{}, %{"name" => 42}] do
      invalid = request(payload)
      assert invalid.status == 422
      assert invalid.halted
    end

    assert_raise RuntimeError, ~r/invalid response returned by operation "create_report"/, fn ->
      Oaskit.Test.valid_response(
        ApiSpec,
        %{valid | resp_body: Jason.encode!(%{"name" => 42})},
        200
      )
    end
  end

  defp request(payload) do
    :post
    |> conn("/api/reports", Jason.encode!(payload))
    |> put_req_header("content-type", "application/json")
    |> Plug.Parsers.call(Plug.Parsers.init(parsers: [:json], json_decoder: Jason))
    |> Router.call([])
  end
end
