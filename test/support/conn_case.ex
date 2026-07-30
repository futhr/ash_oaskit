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
