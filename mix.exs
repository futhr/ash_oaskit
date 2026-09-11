defmodule AshOaskit.MixProject do
  use Mix.Project

  @version "0.4.1"
  @source_url "https://github.com/futhr/ash_oaskit"

  def project do
    [
      app: :ash_oaskit,
      version: @version,
      elixir: "~> 1.17",
      elixirc_paths: elixirc_paths(Mix.env()),
      elixirc_options: [
        no_warn_undefined: [AshJsonApi.Domain.Info, AshJsonApi.Resource.Info]
      ],
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
        bench: :dev,
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
      {:ash, "~> 3.33"},
      {:spark, "~> 2.6"},

      # Security floor: decimal < 3.1.0 has a DoS via unbounded exponent
      # parsing (GHSA-rhv4-8758-jx7v / elixirforum 75261). Pulled
      # transitively via Ash (~> 2.0 or ~> 3.0); ~> 3.1 narrows the
      # resolution without needing override (hex.publish forbids overrides).
      {:decimal, "~> 3.1"},

      # OpenAPI spec normalization, validation, and rendering
      {:oaskit, "~> 0.14.2"},

      # AshJsonApi integration (optional)
      {:ash_json_api, ">= 1.7.1 and < 2.0.0", optional: true},

      # Igniter for installation task (optional)
      {:igniter, ">= 0.6.29 and < 1.0.0", optional: true},

      # Phoenix integration (optional for consumers, available in test)
      {:plug, ">= 1.20.3 and < 2.0.0"},
      {:phoenix, ">= 1.8.13 and < 2.0.0", optional: true},

      # JSON encoding
      {:jason, "~> 1.4"},

      # Dev/Test dependencies
      {:benchee, "~> 1.5", only: :dev, runtime: false},
      {:benchee_markdown, "~> 0.3.4", only: :dev, runtime: false},
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
      bench: ["run bench/generation.exs"],

      # Release
      release: ["git_ops.release"]
    ]
  end

  defp description,
    do: "OpenAPI 3.0 and 3.1 specification generator for Ash Framework domains"

  defp package do
    [
      files: ~w(
        lib
        guides
        notebooks
        bench
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
        "notebooks/quickstart.livemd": [title: "Livebook: Quick Start"],
        "notebooks/schema_generation.livemd": [title: "Livebook: Schema Generation"],
        "notebooks/routes_and_json_api.livemd": [title: "Livebook: Routes and JSON:API"],
        "notebooks/serving_customization_validation.livemd": [
          title: "Livebook: Serving, Customization, and Validation"
        ],
        "notebooks/architecture_deep_dive.livemd": [title: "Livebook: Architecture Deep Dive"],
        "guides/spec-modules.md": [title: "Spec Modules (use AshOaskit)"],
        "guides/request-validation.md": [title: "Request Validation with Oaskit"],
        "guides/cheatsheet.cheatmd": [title: "Cheatsheet"],
        "bench/benchmarks.md": [title: "Benchmark Methodology"],
        "bench/output/paths.md": [title: "Path Registration"],
        "bench/output/references.md": [title: "Schema Reference Checks"],
        "bench/output/yaml.md": [title: "YAML Export"],
        "CHANGELOG.md": [title: "Changelog"],
        "CONTRIBUTING.md": [title: "Contributing"],
        "LICENSE.md": [title: "License"],
        "usage-rules.md": [title: "Usage Rules (LLM)"]
      ],
      groups_for_extras: [
        Livebooks: ~r{notebooks/.*},
        Guides: ~r{guides/.*},
        Benchmarks: ~r{bench/.*}
      ],
      groups_for_modules: [
        "Core API": [
          AshOaskit,
          AshOaskit.Spec,
          AshOaskit.OpenApi
        ],
        Customization: [
          AshOaskit.SpecBuilder,
          AshOaskit.SpecBuilder.Default,
          AshOaskit.SpecModifier,
          AshOaskit.OpenApiController
        ],
        "Phoenix Integration": [
          AshOaskit.Router,
          AshOaskit.Router.Plug,
          AshOaskit.Controller,
          AshOaskit.PhoenixIntrospection
        ],
        Generators: [
          AshOaskit.Generators.Generator,
          AshOaskit.Generators.InfoBuilder,
          AshOaskit.Generators.PathBuilder,
          AshOaskit.Generators.Shared,
          AshOaskit.Generators.V30,
          AshOaskit.Generators.V31
        ],
        Schemas: [
          AshOaskit.SchemaBuilder,
          AshOaskit.SchemaBuilder.EmbeddedSchemas,
          AshOaskit.SchemaBuilder.PropertyBuilders,
          AshOaskit.SchemaBuilder.RelationshipSchemas,
          AshOaskit.SchemaBuilder.ResourceSchemas,
          AshOaskit.Schemas.Nullable,
          AshOaskit.TypeMapper,
          AshOaskit.Core.SchemaRef
        ],
        Parameters: [
          AshOaskit.FilterBuilder,
          AshOaskit.SortBuilder,
          AshOaskit.QueryParameters
        ],
        "Routes & Operations": [
          AshOaskit.RouteGathering,
          AshOaskit.RelationshipRoutes,
          AshOaskit.RelationshipRoutes.RouteOperations,
          AshOaskit.RelationshipRoutes.RouteResponses,
          AshOaskit.Core.PathUtils
        ],
        Responses: [
          AshOaskit.ErrorSchemas,
          AshOaskit.ResponseLinks,
          AshOaskit.ResponseMeta
        ],
        "JSON:API Documents": [
          AshOaskit.IncludedResources,
          AshOaskit.ResourceIdentifier,
          AshOaskit.TagBuilder
        ],
        Support: [
          AshOaskit.Config,
          AshOaskit.MultipartSupport,
          AshOaskit.Security
        ]
      ],
      source_ref: "v#{@version}",
      source_url: @source_url,
      formatters: ["html"]
    ]
  end
end
