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
    2. Generates an `ApiSpec` module (`use AshOaskit`) to fill in with
       your domains
    3. Prints the router snippet for serving the spec and Redoc UI

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
      spec_module = Igniter.Project.Module.module_name(igniter, "ApiSpec")

      igniter
      |> Igniter.Project.Formatter.import_dep(:ash_oaskit)
      |> Igniter.Project.Module.create_module(spec_module, """
      use AshOaskit,
        domains: [
          # Add your Ash domains here, e.g. #{inspect(Igniter.Project.Module.module_name_prefix(igniter))}.Blog
        ],
        title: "API",
        api_version: "1.0.0"
      """)
      |> Igniter.add_notice("""
      AshOaskit installed!

      1. Add your Ash domains to #{inspect(spec_module)}.

      2. Serve the spec from your router:

           use AshOaskit.Router,
             spec: #{inspect(spec_module)},
             open_api: "/openapi",
             redoc: "/redoc"

      3. (Optional, dev) Regenerate the spec on code reload by adding
         to config/dev.exs:

           config :ash_oaskit, cache_specs: false

      4. Export the spec from the command line:

           mix openapi.dump #{inspect(spec_module)}
      """)
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
