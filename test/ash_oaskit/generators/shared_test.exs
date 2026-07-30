defmodule AshOaskit.Generators.SharedTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias AshOaskit.Generators.Shared

  describe "generate/2" do
    test "delegates to Generator.generate/2" do
      spec = Shared.generate([AshOaskit.Test.Blog], version: "3.1", title: "Shared Test")
      assert spec[:openapi] =~ "3.1"
      assert spec[:info][:title] == "Shared Test"
    end
  end
end
