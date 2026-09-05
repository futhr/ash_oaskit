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
    2. Generates a compileable `ApiSpec` scaffold; pass `--domains` to activate it
    3. Prints the router snippet for serving the spec and Redoc UI

    ## Options

    * `--domains` - Comma-separated Ash domain module names
    """

    use Igniter.Mix.Task

    @impl Igniter.Mix.Task
    @spec info([String.t()], term()) :: Igniter.Mix.Task.Info.t()
    def info(_, _) do
      %Igniter.Mix.Task.Info{
        group: :ash_oaskit,
        adds_deps: [],
        installs: [],
        schema: [domains: :string],
        example: "mix igniter.install ash_oaskit"
      }
    end

    @impl Igniter.Mix.Task
    @spec igniter(Igniter.t()) :: Igniter.t()
    def igniter(igniter) do
      spec_module = Igniter.Project.Module.module_name(igniter, "ApiSpec")
      domains = igniter.args.options[:domains]

      igniter
      |> Igniter.Project.Formatter.import_dep(:ash_oaskit)
      |> Igniter.Project.Module.create_module(spec_module, spec_source(domains))
      |> Igniter.add_notice("""
      AshOaskit installed!

      1. Review #{inspect(spec_module)}. If --domains was omitted, uncomment its
         use AshOaskit declaration and replace the example domain before serving it.

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

    defp spec_source(nil) do
      """
      @moduledoc "Configure your Ash domains before serving this specification."

      # Uncomment after replacing MyApp.Domain with your actual domain:
      # use AshOaskit,
      #   domains: [MyApp.Domain],
      #   title: "API",
      #   api_version: "1.0.0"
      """
    end

    defp spec_source(domains) do
      domains =
        domains
        |> String.split(",", trim: true)
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(&1 == ""))
        |> Enum.map(&module_name!/1)

      if domains == [] do
        spec_source(nil)
      else
        """
        use AshOaskit,
          domains: [#{Enum.join(domains, ", ")}],
          title: "API",
          api_version: "1.0.0"
        """
      end
    end

    defp module_name!(name) do
      if Regex.match?(~r/^(Elixir\.)?[A-Z][A-Za-z0-9_]*(\.[A-Z][A-Za-z0-9_]*)*$/, name),
        do: String.trim_leading(name, "Elixir."),
        else: Mix.raise("Invalid domain module: #{inspect(name)}")
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
