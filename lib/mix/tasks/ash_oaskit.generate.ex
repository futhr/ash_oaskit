defmodule Mix.Tasks.AshOaskit.Generate do
  @shortdoc "Generate OpenAPI specification files"

  @moduledoc """
  Generate OpenAPI specification files from Ash domains.

  > #### Tip {: .tip}
  >
  > If you already define a spec module with `use AshOaskit`, prefer
  > oaskit's exporter — it uses the exact spec your app serves:
  >
  >     mix openapi.dump MyAppWeb.ApiSpec
  >
  > This task remains useful for YAML output and one-off generation
  > without a spec module.

  ## Usage

      mix ash_oaskit.generate --domains MyApp.Blog,MyApp.Accounts

  ## Options

    * `--domains` - Comma-separated list of Ash domains (required)
    * `--version` - OpenAPI version: "3.0" or "3.1" (default: "3.1")
    * `--output` - Output file path (default: `openapi-<version>.<format>`,
      for example `openapi-3.1.json`)
    * `--format` - Output format: "json" or "yaml" (default: "json")
    * `--title` - API title
    * `--api-version` - API version string
    * `--pretty` - Pretty-print the output (default: true)

  ## Examples

      # Generate OpenAPI 3.1 spec
      mix ash_oaskit.generate --domains MyApp.Blog --output openapi-3.1.json

      # Generate OpenAPI 3.0 spec
      mix ash_oaskit.generate --domains MyApp.Blog --version 3.0 --output openapi-3.0.json

      # Generate both versions
      mix ash_oaskit.generate --domains MyApp.Blog --version 3.1 --output openapi-3.1.json
      mix ash_oaskit.generate --domains MyApp.Blog --version 3.0 --output openapi-3.0.json
  """

  use Mix.Task

  @impl Mix.Task
  @spec run([String.t()]) :: :ok
  def run(args) do
    {opts, positional, invalid} =
      OptionParser.parse(args,
        strict: [
          domains: :string,
          version: :string,
          output: :string,
          format: :string,
          title: :string,
          api_version: :string,
          pretty: :boolean
        ],
        aliases: [
          d: :domains,
          v: :version,
          o: :output,
          f: :format,
          t: :title
        ]
      )

    validate_arguments!(invalid, positional)

    version = opts[:version] || "3.1"
    output = opts[:output] || default_output(version, opts[:format])
    format = opts[:format] || "json"
    pretty = Keyword.get(opts, :pretty, true)

    if format not in ["json", "yaml"] do
      Mix.raise("Unknown format: #{format}. Use 'json' or 'yaml'")
    end

    Mix.Task.run("app.start")
    domains = parse_domains(opts[:domains])

    if domains == [] do
      Mix.raise("No domains specified. Use --domains MyApp.Domain1,MyApp.Domain2")
    end

    spec_opts =
      [
        domains: domains,
        version: version
      ]
      |> maybe_add(:title, opts[:title])
      |> maybe_add(:api_version, opts[:api_version])

    Mix.shell().info("Generating OpenAPI #{version} spec...")

    spec = AshOaskit.spec(spec_opts)

    content =
      case format do
        "json" -> encode_json(spec, pretty)
        "yaml" -> encode_yaml(spec)
      end

    File.write!(output, content)

    Mix.shell().info("Generated #{output}")
  end

  defp validate_arguments!([], []), do: :ok

  defp validate_arguments!(invalid, positional),
    do: Mix.raise("Invalid arguments: #{inspect(invalid ++ positional)}")

  defp parse_domains(nil), do: []

  defp parse_domains(domains_string) do
    domains_string
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.map(&domain_module!/1)
    |> Enum.uniq()
  end

  defp domain_module!(name) do
    module = Module.safe_concat([name])

    if Code.ensure_loaded?(module) and Spark.Dsl.is?(module, Ash.Domain) do
      module
    else
      Mix.raise("Not a loaded Ash domain: #{name}")
    end
  rescue
    ArgumentError -> Mix.raise("Unknown Ash domain: #{name}")
  end

  defp default_output(version, format) do
    ext = format || "json"
    "openapi-#{version}.#{ext}"
  end

  defp encode_json(spec, pretty), do: Oaskit.SpecDumper.to_json!(spec, pretty: pretty)

  defp encode_yaml(spec) do
    if Code.ensure_loaded?(Ymlr) and function_exported?(Ymlr, :document!, 1) do
      # Round-trip through JSON to normalize atoms/structs before YAML
      spec
      |> JSV.Codec.encode!()
      |> JSV.Codec.decode!()
      |> Ymlr.document!()
    else
      Mix.raise(
        "YAML format requires the :ymlr dependency. Add {:ymlr, \"~> 5.0\"} to your mix.exs"
      )
    end
  end

  defp maybe_add(opts, _, nil), do: opts
  defp maybe_add(opts, key, value), do: Keyword.put(opts, key, value)
end
