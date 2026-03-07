defmodule AshOaskit.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/futhr/ash_oaskit"

  def project do
    [
      app: :ash_oaskit,
      version: @version,
      elixir: "~> 1.16",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),

      # Suppress consolidate_protocols warnings in dev environment
      consolidate_protocols: Mix.env() != :dev,

      # Hex package
      description: description(),
      package: package(),

      # Documentation
      name: "AshOasKit",
      source_url: @source_url,
      homepage_url: @source_url,
      docs: docs(),
      test_coverage: [tool: ExCoveralls],
      dialyzer: [
        plt_core_path: "priv/plts",
        plt_file: {:no_warn, "priv/plts/ash_oaskit.plt"},
        flags: [:error_handling, :unknown],
        plt_add_apps: [:mix, :ex_unit],
        ignore_warnings: ".dialyzer_ignore.exs"
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  def cli do
    [
      preferred_envs: [
        check: :dev,
        coveralls: :test,
        "coveralls.html": :test,
        "coveralls.json": :test,
        "test.watch": :test
      ]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      # Core Ash dependencies
      {:ash, "~> 3.0"},
      {:spark, "~> 2.0"},

      # OpenAPI spec normalization, validation, and rendering
      {:oaskit, "~> 0.11"},

      # AshJsonApi integration (optional)
      {:ash_json_api, "~> 1.0", optional: true},

      # Igniter for installation task (optional)
      {:igniter, "~> 0.5", optional: true},

      # Phoenix integration (optional for consumers, available in test)
      {:plug, "~> 1.14"},
      {:phoenix, "~> 1.7", optional: true},

      # JSON encoding
      {:jason, "~> 1.4"},

      # Dev/Test dependencies
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      {:doctest_formatter, "~> 0.4", only: [:dev, :test], runtime: false},
      {:ex_check, "~> 0.16", only: :dev, runtime: false},
      {:doctor, "~> 0.21", only: :dev, runtime: false},
      {:mix_audit, "~> 2.1", only: [:dev, :test], runtime: false},
      {:sobelow, "~> 0.13", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.18", only: :test},
      {:mix_test_watch, "~> 1.2", only: [:dev, :test], runtime: false},
      {:git_ops, "~> 2.6", only: :dev}
    ]
  end

  defp aliases do
    [
      # Setup
      setup: ["deps.get", "deps.compile", "compile"],

      # Testing
      "test.watch": ["test.watch --stale"],

      # Publishing
      "hex.publish": ["hex.build", "hex.publish", "tag"],
      tag: &tag_release/1
    ]
  end

  defp description do
    """
    OpenAPI 3.0 and 3.1 spec generator for Ash Framework resources.
    Supports dual-version output for migration scenarios.
    """
  end

  defp package do
    [
      files: ~w(
        lib
        .formatter.exs
        mix.exs
        README.md
        LICENSE.md
        CHANGELOG.md
        CONTRIBUTING.md
        usage-rules.md
      ),
      maintainers: ["Tobias Bohwalli <hi@futhr.io>"],
      licenses: ["MIT"],
      source_url: @source_url,
      links: %{
        "GitHub" => @source_url,
        "Changelog" => "#{@source_url}/blob/main/CHANGELOG.md",
        "Issues" => "#{@source_url}/issues"
      }
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: [
        "README.md": [title: "Overview"],
        "CHANGELOG.md": [title: "Changelog"],
        "CONTRIBUTING.md": [title: "Contributing"],
        "LICENSE.md": [title: "License"],
        "usage-rules.md": [title: "Usage Rules (LLM)"]
      ],
      groups_for_modules: [
        "Core API": [
          AshOaskit
        ],
        Generators: [
          AshOaskit.Generators.V30,
          AshOaskit.Generators.V31
        ],
        Utilities: [
          AshOaskit.TypeMapper
        ],
        Phoenix: [
          AshOaskit.Controller
        ]
      ],
      source_ref: "v#{@version}",
      source_url: @source_url,
      formatters: ["html"]
    ]
  end

  defp tag_release(_) do
    Mix.shell().info("Tagging release as v#{@version}")
    System.cmd("git", ["tag", "-a", "v#{@version}", "-m", "Release v#{@version}"])
    System.cmd("git", ["push", "--tags"])
  end
end
