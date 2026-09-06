defmodule AshOaskit.Quality.CredoNestingTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias Credo.Check.Refactor.Nesting
  alias Credo.SourceFile

  setup_all do
    {:ok, _} = Application.ensure_all_started(:credo)
    {config, _} = Code.eval_file(Path.expand("../../.credo.exs", __DIR__))
    default = Enum.find(config.configs, &(&1.name == "default"))
    {Nesting, params} = List.keyfind(default.checks.enabled, Nesting, 0)

    assert params[:max_nesting] == 2
    assert params[:priority] == :high

    %{params: params}
  end

  test "allows two conditional levels", %{params: params} do
    source = """
    defmodule NestingFixture do
      def allowed(a, b) do
        if a do
          if b, do: :ok
        end
      end
    end
    """

    assert issues(source, params) == []
  end

  test "rejects three conditional levels", %{params: params} do
    source = """
    defmodule NestingFixture do
      def rejected(a, b, c) do
        if a do
          if b do
            if c, do: :ok
          end
        end
      end
    end
    """

    assert [%{message: message}] = issues(source, params)
    assert message =~ "max depth is 2, was 3"
  end

  test "counts anonymous functions toward conditional nesting", %{params: params} do
    source = """
    defmodule NestingFixture do
      def rejected(items, enabled) do
        Enum.map(items, fn item ->
          if enabled do
            case item do
              :ok -> true
              _ -> false
            end
          end
        end)
      end
    end
    """

    assert [%{message: message}] = issues(source, params)
    assert message =~ "max depth is 2, was 3"
  end

  for {construct, expression} <- [
        {"unless", "unless false, do: :ok"},
        {"cond", "cond do\ntrue -> :ok\nend"},
        {"for", "for item <- [1], do: item"},
        {"with", "with {:ok, value} <- {:ok, 1}, do: value"}
      ] do
    test "counts #{construct} at both sides of the nesting boundary", %{params: params} do
      assert issues(nested_fixture(unquote(expression), 1), params) == []

      assert [%{message: message}] = issues(nested_fixture(unquote(expression), 2), params)
      assert message =~ "max depth is 2, was 3"
    end
  end

  defp nested_fixture(expression, depth) do
    body = Enum.reduce(1..depth, expression, fn _, body -> "if true do\n#{body}\nend" end)

    """
    defmodule NestingFixture do
      def sample do
        #{body}
      end
    end
    """
  end

  defp issues(source, params) do
    source
    |> SourceFile.parse("nesting_fixture.ex")
    |> Nesting.run(params)
  end
end
