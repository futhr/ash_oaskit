defmodule Mix.Tasks.AshOaskit.Generate do
  @shortdoc "Generate OpenAPI specification files"

  @moduledoc """
  Generate OpenAPI specification files from Ash domains.

  ## Usage

      mix ash_oaskit.generate --domains MyApp.Blog,MyApp.Accounts

  ## Options

    * `--domains` - Comma-separated list of Ash domains (required)
    * `--version` - OpenAPI version: "3.0" or "3.1" (default: "3.1")
    * `--output` - Output file path (default: "openapi.json")
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
    Mix.Task.run("app.start")

    {opts, _, _} =
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

    domains = parse_domains(opts[:domains])
    version = opts[:version] || "3.1"
    output = opts[:output] || default_output(version, opts[:format])
    format = opts[:format] || "json"
    pretty = Keyword.get(opts, :pretty, true)

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
        _ -> Mix.raise("Unknown format: #{format}. Use 'json' or 'yaml'")
      end

    File.write!(output, content)

    Mix.shell().info("Generated #{output}")
  end

  defp parse_domains(nil), do: []

  defp parse_domains(domains_string) do
    domains_string
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.map(&Module.safe_concat([&1]))
  end

  defp default_output(version, format) do
    ext = format || "json"
    "openapi-#{version}.#{ext}"
  end

  defp encode_json(spec, pretty), do: Oaskit.SpecDumper.to_json!(spec, pretty: pretty)

  defp encode_yaml(spec) do
    if Code.ensure_loaded?(YamlElixir.Sigil) do
      # Use yaml_elixir if available
      spec
      |> Jason.encode!()
      |> Jason.decode!()
      |> Ymlr.document!()
    else
      Mix.raise(
        "YAML format requires the :ymlr dependency. Add {:ymlr, \"~> 5.0\"} to your mix.exs"
      )
    end
  end

  defp maybe_add(opts, _key, nil), do: opts
  defp maybe_add(opts, key, value), do: Keyword.put(opts, key, value)
end
