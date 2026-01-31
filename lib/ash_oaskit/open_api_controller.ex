defmodule AshOaskit.OpenApiController do
  @moduledoc """
  Behaviour for Phoenix controllers to provide OpenAPI metadata.

  Only controllers implementing this behaviour will be included
  in the generated OpenAPI specification when using Phoenix router
  introspection.

  ## Usage

  Implement this behaviour in your Phoenix controllers to include
  them in the OpenAPI spec:

      defmodule MyAppWeb.HealthController do
        use MyAppWeb, :controller
        @behaviour AshOaskit.OpenApiController

        @impl true
        def openapi_operations do
          %{
            index: %{
              "summary" => "Health check",
              "description" => "Returns system health status",
              "tags" => ["Infrastructure"],
              "responses" => %{
                "200" => %{"description" => "System healthy"},
                "503" => %{"description" => "System unhealthy"}
              }
            },
            liveness: %{
              "summary" => "Kubernetes liveness probe",
              "tags" => ["Infrastructure"],
              "responses" => %{
                "200" => %{"description" => "Alive"}
              }
            }
          }
        end

        @impl true
        def openapi_tag do
          %{"name" => "Infrastructure", "description" => "System operations"}
        end

        # ... controller actions
      end

  ## Callbacks

  ### Required: `openapi_operations/0`

  Returns a map of action atoms to OpenAPI operation objects.
  Each operation object should contain standard OpenAPI fields:

  - `"summary"` - Short description (recommended)
  - `"description"` - Detailed description (optional)
  - `"tags"` - List of tag names (optional)
  - `"parameters"` - List of parameter objects (optional)
  - `"requestBody"` - Request body object (optional, for POST/PATCH)
  - `"responses"` - Map of response code to response object (recommended)

  ### Optional: `openapi_tag/0`

  Returns a tag object or string for this controller.
  If not implemented, the controller name is used as the tag.

  Can return either:
  - A string: `"Infrastructure"`
  - A map: `%{"name" => "Infrastructure", "description" => "System ops"}`

  ## Router Configuration

  To enable Phoenix controller introspection, pass the `:router` option:

      use AshOaskit.Router,
        domains: [MyApp.Blog],
        router: MyAppWeb.Router,  # Enable controller introspection
        open_api: "/openapi",
        title: "My API"

  Only controllers implementing this behaviour will be included.
  Controllers without the behaviour are ignored.
  """

  @doc """
  Returns OpenAPI operation metadata for controller actions.

  The returned map should have action atoms as keys and OpenAPI
  operation objects as values.

  ## Example

      def openapi_operations do
        %{
          index: %{
            "summary" => "List items",
            "tags" => ["Items"],
            "responses" => %{
              "200" => %{"description" => "Success"}
            }
          },
          show: %{
            "summary" => "Get item",
            "tags" => ["Items"],
            "parameters" => [
              %{
                "name" => "id",
                "in" => "path",
                "required" => true,
                "schema" => %{"type" => "string"}
              }
            ],
            "responses" => %{
              "200" => %{"description" => "Success"},
              "404" => %{"description" => "Not found"}
            }
          }
        }
      end
  """
  @callback openapi_operations() :: %{atom() => map()}

  @doc """
  Returns the OpenAPI tag for this controller.

  Optional callback. If not implemented, the controller name
  (with "Controller" suffix removed) is used as the tag name.

  ## Examples

  Return a simple string:

      def openapi_tag, do: "Infrastructure"

  Return a full tag object with description:

      def openapi_tag do
        %{
          "name" => "Infrastructure",
          "description" => "System health and monitoring endpoints"
        }
      end
  """
  @callback openapi_tag() :: String.t() | map()

  @optional_callbacks [openapi_tag: 0]
end
