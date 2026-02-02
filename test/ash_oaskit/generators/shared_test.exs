defmodule AshOaskit.Generators.SharedTest do
  @moduledoc """
  Tests for the AshOaskit.Generators.Shared module.

  The Shared module delegates to `Generator.generate/2` as the single
  entry point for spec generation.
  """

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
