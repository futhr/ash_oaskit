# Run with `mix run scripts/verify_consumer.exs [minimal|minimum|integrations]`.
# The fixture uses the built Hex archive, not the source checkout or its lockfile.
mode = List.first(System.argv()) || "minimal"
unless mode in ["minimal", "minimum", "integrations"], do: Mix.raise("Unknown consumer mode")
{temp, 0} = System.cmd("mktemp", ["-d"])
temp = String.trim(temp)
archive = Path.join(temp, "ash_oaskit.tar")
package = Path.join(temp, "package")
consumer = Path.join(temp, "consumer")

run = fn args, cwd ->
  case System.cmd("mix", args,
         cd: cwd,
         env: [{"MIX_ENV", "prod"}, {"MIX_BUILD_PATH", nil}, {"MIX_DEPS_PATH", nil}],
         into: IO.stream()
       ) do
    {_, 0} -> :ok
    {_, status} -> Mix.raise("Consumer command failed (#{status}): mix #{Enum.join(args, " ")}")
  end
end

try do
  run.(["hex.build", "--output", archive], File.cwd!())
  File.mkdir_p!(package)
  :ok = :erl_tar.extract(String.to_charlist(archive), [{:cwd, String.to_charlist(package)}])

  :ok =
    :erl_tar.extract(String.to_charlist(Path.join(package, "contents.tar.gz")), [
      :compressed,
      {:cwd, String.to_charlist(package)}
    ])

  File.mkdir_p!(Path.join(consumer, "config"))

  pins =
    case mode do
      "minimum" ->
        [
          ash: "3.33.0",
          spark: "2.6.0",
          decimal: "3.1.0",
          oaskit: "0.14.2",
          plug: "1.20.3",
          jason: "1.4.0"
        ]

      "integrations" ->
        [ash_json_api: "1.7.1", phoenix: "1.8.13", igniter: "0.6.29"]

      _ ->
        []
    end

  deps = [
    {:ash_oaskit, [path: package]}
    | Enum.map(pins, fn {name, version} -> {name, "== #{version}", [override: true]} end)
  ]

  File.write!(Path.join(consumer, "mix.exs"), """
  defmodule Consumer.MixProject do
    use Mix.Project
    def project, do: [app: :consumer, version: "0.1.0", consolidate_protocols: false, deps: #{inspect(deps)}]
    def application, do: []
  end
  """)

  File.write!(
    Path.join(consumer, "config/config.exs"),
    "import Config\nconfig :ash, default_string_length_count: :codepoints\n"
  )

  integrations? = mode == "integrations"

  File.write!(Path.join(consumer, "verify.exs"), """
  defmodule Consumer.Resource do
    use Ash.Resource, domain: nil#{if integrations?, do: ", extensions: [AshJsonApi.Resource]"}
    attributes do
      uuid_primary_key :id
      attribute :name, :string, public?: true
    end
    actions do
      defaults [:read]
    end
    #{if integrations?, do: ~s(json_api do\n type "items"\n routes do\n base "/items"\n index :read\n end\n end)}
  end
  defmodule Consumer.Domain do
    use Ash.Domain, validate_config_inclusion?: false#{if integrations?, do: ", extensions: [AshJsonApi.Domain]"}
    resources do
      resource Consumer.Resource
    end
  end
  for version <- ["3.0", "3.1"] do
    spec = AshOaskit.spec(domains: [Consumer.Domain], version: version)
    {:ok, _} = AshOaskit.validate(spec)
    true = is_binary(Jason.encode!(spec))
    #{if integrations?, do: ~s|true = Map.has_key?(spec["paths"], "/items")|, else: ~s|%{} = spec["paths"]|}
  end
  #{unless integrations?, do: "false = Enum.any?([AshJsonApi, Phoenix, Igniter], &Code.ensure_loaded?/1)"}
  IO.puts("Packaged consumer verified: #{mode}")
  """)

  run.(["deps.get"], consumer)
  run.(["run", "verify.exs"], consumer)
after
  File.rm_rf!(temp)
end
