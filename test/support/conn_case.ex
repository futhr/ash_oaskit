# Test case template for controller tests.
#
# This module provides a test case template for testing the AshOaskit.Controller
# module, which serves OpenAPI specs from Phoenix applications.
#
# ## Usage
#
#     defmodule AshOaskit.ControllerTest do
#       use AshOaskit.ConnCase
#
#       test "returns OpenAPI spec" do
#         conn = conn(:get, "/openapi.json")
#         # ... test controller actions
#       end
#     end
#
# ## Imported Functions
#
# - `Plug.Conn` - Connection manipulation functions
# - `Plug.Test` - Test helpers including `conn/2` and `conn/3`

defmodule AshOaskit.ConnCase do
  @moduledoc false
  use ExUnit.CaseTemplate

  using do
    quote do
      import Plug.Conn
      import Plug.Test
    end
  end
end
