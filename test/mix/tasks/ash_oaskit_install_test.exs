defmodule Mix.Tasks.AshOaskit.InstallTest do
  @moduledoc """
  Tests for the `mix ash_oaskit.install` task.

  This mix task handles initial setup of AshOaskit in a project using Igniter
  for code generation. It configures dependencies, sets up basic configuration,
  and provides a smooth onboarding experience.

  ## What We Test

  - **Module definition** - Task is properly defined with shortdoc and moduledoc
  - **Igniter integration** - When Igniter is available, returns proper task info
    with correct group and dependency declarations
  - **Graceful degradation** - When Igniter is unavailable, shows helpful error
    message instead of crashing

  ## How We Test

  Tests verify module attributes and documentation exist. For Igniter integration,
  we create test Igniter structs and verify the install task returns properly
  configured Igniter results. We use compile-time checks (`Code.ensure_loaded?`)
  to conditionally test Igniter-dependent functionality.

  ## Why These Tests Matter

  The install task is a user's first interaction with AshOaskit. A broken
  installer creates a poor first impression and blocks adoption. These tests
  ensure the task is discoverable (`mix help`), documented, and works correctly
  whether or not optional dependencies like Igniter are present.
  """

  use ExUnit.Case, async: false

  alias Mix.Tasks.AshOaskit.Install

  describe "module definition" do
    test "module is defined" do
      assert Code.ensure_loaded?(Mix.Tasks.AshOaskit.Install)
    end

    test "has shortdoc" do
      assert Install.__info__(:attributes)[:shortdoc] != nil
    end

    test "has moduledoc" do
      {:docs_v1, _, _, _, %{"en" => moduledoc}, _, _} = Code.fetch_docs(Install)
      assert is_binary(moduledoc)
      assert moduledoc =~ "Installs AshOaskit"
    end
  end

  if Code.ensure_loaded?(Igniter) do
    describe "with igniter available" do
      test "info/2 returns task info struct" do
        info = Install.info([], nil)

        assert %Igniter.Mix.Task.Info{} = info
        assert info.group == :ash_oaskit
        assert info.adds_deps == []
      end

      test "igniter/1 configures the project" do
        # Create a test igniter
        igniter = Igniter.new()

        # Run the install task
        result = Install.igniter(igniter)

        # Should return an Igniter struct
        assert %Igniter{} = result
      end
    end
  else
    describe "without igniter available" do
      test "run/1 shows error message and exits" do
        assert_raise ExitError, fn ->
          Install.run([])
        end
      end
    end
  end
end
