if Code.ensure_loaded?(Igniter) do
  defmodule Mix.Tasks.AshOaskit.Install do
    @shortdoc "Installs AshOaskit into your project"

    @moduledoc """
    Installs AshOaskit into your project.

    This task should be run with `mix igniter.install ash_oaskit`.

    ## Usage

        mix igniter.install ash_oaskit

    ## What it does

    1. Adds `:ash_oaskit` to your formatter's import dependencies
    2. Configures the default OpenAPI version in your config

    ## Options

    This task accepts no options.
    """

    use Igniter.Mix.Task

    @impl Igniter.Mix.Task
    @spec info([String.t()], term()) :: Igniter.Mix.Task.Info.t()
    def info(_, _) do
      %Igniter.Mix.Task.Info{
        group: :ash_oaskit,
        adds_deps: [],
        installs: [],
        example: "mix igniter.install ash_oaskit"
      }
    end

    @impl Igniter.Mix.Task
    @spec igniter(Igniter.t()) :: Igniter.t()
    def igniter(igniter) do
      igniter
      |> Igniter.Project.Formatter.import_dep(:ash_oaskit)
      |> Igniter.Project.Config.configure(
        "config.exs",
        :ash_oaskit,
        [:version],
        "3.1"
      )
    end
  end
else
  defmodule Mix.Tasks.AshOaskit.Install do
    @shortdoc "Installs AshOaskit into your project"
    @moduledoc """
    Installs AshOaskit into your project.

    This task requires the `igniter` dependency. Please install igniter and try again.

    ## Installation

    Add igniter to your dependencies:

        {:igniter, "~> 0.5"}

    Then run:

        mix igniter.install ash_oaskit

    For more information, see: https://hexdocs.pm/igniter
    """

    use Mix.Task

    @impl Mix.Task
    @spec run([String.t()]) :: no_return()
    def run(_) do
      Mix.shell().error("""
      The task 'ash_oaskit.install' requires igniter.

      Please install igniter and try again.

      Add to your mix.exs deps:

          {:igniter, "~> 0.5"}

      Then run:

          mix igniter.install ash_oaskit

      For more information, see: https://hexdocs.pm/igniter
      """)

      exit({:shutdown, 1})
    end
  end
end
