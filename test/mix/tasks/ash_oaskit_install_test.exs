defmodule Mix.Tasks.AshOaskit.InstallTest do
  @moduledoc false

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

        assert %Igniter{} = result
      end

      test "igniter/1 generates an ApiSpec module and prints the router snippet" do
        result = Install.igniter(Igniter.new())

        created_sources = Map.keys(result.rewrite.sources)
        assert Enum.any?(created_sources, &String.ends_with?(&1, "api_spec.ex"))

        assert Enum.any?(result.notices, &(&1 =~ "use AshOaskit.Router"))
        assert Enum.any?(result.notices, &(&1 =~ "mix openapi.dump"))
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
