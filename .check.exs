[
  ## Don't run tools concurrently
  parallel: false,

  ## Don't print summary
  skipped: false,

  tools: [
    {:compiler, "mix compile --warnings-as-errors"},
    {:formatter, "mix format --check-formatted"},
    {:credo, "mix credo --strict"},
    {:ex_unit, false},
    {:test, command: "mix test", env: %{"MIX_ENV" => "test"}},
    {:hex_audit, "mix hex.audit"},
    {:mix_audit, "mix deps.audit"},
    {:dialyzer, "mix dialyzer"},
    {:doctor, "mix doctor --summary"},
    {:sobelow, "mix sobelow --config"},
    {:ex_doc, false}
  ]
]
