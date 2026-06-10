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

2. Declare the operation in the controller and validate:

```elixir
defmodule MyAppWeb.ReportController do
  use MyAppWeb, :controller
  use Oaskit.Controller

  plug Oaskit.Plugs.ValidateRequest

  operation :create,
    operation_id: "create_report",
    request_body: {%{
      "type" => "object",
      "required" => ["name"],
      "properties" => %{"name" => %{"type" => "string"}}
    }, []},
    responses: [ok: true]

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
> Operations declared with the `operation` macro live on the controller.
> To document them in your AshOaskit spec output, pass your Phoenix
> router via the `:router` option of `use AshOaskit` — controllers
> implementing `AshOaskit.OpenApiController` are introspected and merged
> into `paths`.

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

# Full build: normalization + JSV validator construction for every operation
Oaskit.build_spec!(MyAppWeb.ApiSpec)
```

`Oaskit.build_spec!` is the stronger check — it proves every schema in
the spec compiles to a working JSV validator.
