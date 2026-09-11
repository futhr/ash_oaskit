# Request Validation with Oaskit

A spec module (`use AshOaskit`) implements the `Oaskit` behaviour, which
unlocks oaskit's request validation machinery. This guide is honest about
the scope: **what is validated, by whom, and where oaskit's plugs apply.**

## Who validates what

| Routes | Validated by |
|--------|--------------|
| Ash-served routes (`AshJsonApi.Router`) | AshJsonApi itself — actions validate their inputs, the JSON:API layer checks document structure |
| Hand-written Phoenix controllers | `Oaskit.Plugs.ValidateRequest` against your spec module |

`Oaskit.Plugs.ValidateRequest` resolves operations through the
`operation` macro from `use Oaskit.Controller`, which requires a Phoenix
controller per route. AshJsonApi serves its routes through a forwarded
plug router without per-route Phoenix controllers, so **ValidateRequest
cannot intercept Ash-served routes** — and it does not need to: Ash
already validates those requests at the action layer.

Where the integration shines is hybrid APIs: hand-written endpoints
documented in the same spec as your Ash routes get full request
validation against the schemas you declare.

## Setting up validation for hand-written controllers

1. Provide the spec module to the pipeline:

```elixir
# router.ex
pipeline :api do
  plug :accepts, ["json"]
  plug Oaskit.Plugs.SpecProvider, spec: MyAppWeb.ApiSpec
end

scope "/api", MyAppWeb do
  pipe_through :api

  post "/reports", ReportController, :create
end
```

2. Provide AshOaskit's explicit operation metadata and use its operation ID for
   Oaskit validation. Ensure your endpoint runs `Plug.Parsers` for JSON before
   dispatching to this controller:

```elixir
defmodule MyAppWeb.ReportController do
  @behaviour AshOaskit.OpenApiController
  use MyAppWeb, :controller
  use Oaskit.Controller

  plug Oaskit.Plugs.ValidateRequest

  use_operation :create, "create_report"

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

  def create(conn, _params) do
    %{"name" => name} = body_params(conn)
    json(conn, %{"name" => name})
  end
end
```

Invalid requests are rejected before your action runs, with structured
errors from oaskit's default error handler.

> #### Merging hand-written operations into the spec {: .info}
>
> Pass `router: MyAppWeb.Router` to `use AshOaskit` in `MyAppWeb.ApiSpec`.
> AshOaskit reads `openapi_operations/0`. The `Oaskit.Controller.operation/2`
> macro alone does not implement that callback. `use_operation/2` above connects
> validation to the explicit `create_report` operation in the generated spec.

## Validating responses in tests

`Oaskit.Test.valid_response/3` asserts a conn's response against the
spec's response schema for the matched operation (it requires the route
to have gone through `ValidateRequest`, so it applies to the same
hand-written controllers):

```elixir
use MyAppWeb.ConnCase, async: true
import Oaskit.Test

test "create report returns a valid response", %{conn: conn} do
  conn = post(conn, ~p"/api/reports", %{"name" => "Q3"})
  assert %{"name" => "Q3"} = valid_response(MyAppWeb.ApiSpec, conn, 200)
end
```

For Ash-served routes, assert against the generated spec directly — the
spec is data:

```elixir
test "generated spec stays valid" do
  assert {:ok, _} = AshOaskit.validate(MyAppWeb.ApiSpec.spec())
end
```

## Validating the spec itself

Two layers are available and cheap to run in CI:

```elixir
# Structural validation against the OpenAPI metaschema
{:ok, %Oaskit.Spec.OpenAPI{}} = AshOaskit.validate(MyAppWeb.ApiSpec.spec())

# Build request and response validators for documented operations
Oaskit.build_spec!(MyAppWeb.ApiSpec, responses: true)
```

The default build checks request validators; `responses: true` also builds response
validators. A successful build does not prove that every unused component was compiled,
that runtime payloads match the spec, or that application authorization is enforced.
Exercise real valid and invalid requests and responses as well.
