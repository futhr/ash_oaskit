# Run with `mix bench`. Fixtures and correctness checks stay outside timed work.
alias AshOaskit.Core.PathRegistry
alias AshOaskit.Core.SchemaRef
alias AshOaskit.SchemaBuilder
alias Benchee.Formatters.Markdown

for app <- [:benchee, :benchee_markdown] do
  {:ok, _} = Application.ensure_all_started(app)
end

recorded_at = DateTime.to_iso8601(DateTime.utc_now())
output_dir = Path.join(__DIR__, "output")

configuration = [
  parallel: 1,
  warmup: 2,
  time: 5,
  memory_time: 1,
  reduction_time: 1,
  pre_check: true
]

run = fn name, title, description, jobs, inputs ->
  description = """
  #{description}

  Recorded at #{recorded_at} with `mix bench`.
  AshOaskit #{Application.spec(:ash_oaskit, :vsn)},
  Benchee #{Application.spec(:benchee, :vsn)},
  benchee_markdown #{Application.spec(:benchee_markdown, :vsn)}.

  Inputs and correctness checks are outside timed work. Scenarios run serially
  with #{configuration[:warmup]} seconds of warmup, #{configuration[:time]} seconds of runtime measurement,
  #{configuration[:memory_time]} second of memory measurement, and
  #{configuration[:reduction_time]} second of reduction measurement. Slow scenarios may collect
  few samples; these measurements are observations, not guarantees.

  Memory results measure allocations in the benchmarked process, not peak resident
  memory or allocations in other processes. See [methodology](../benchmarks.md).
  """

  Benchee.run(
    jobs,
    configuration ++
      [
        inputs: inputs,
        formatters: [
          Benchee.Formatters.Console,
          {Markdown,
           file: Path.join(output_dir, name <> ".md"),
           title: "# " <> title,
           description: description}
        ]
      ]
  )
end

path_inputs =
  Enum.map([100, 500, 1000, 2000], fn size ->
    entries = Enum.map(1..size, &{"/items#{&1}/{id}", "get", %{operationId: "op#{&1}"}})
    {"#{size} paths", entries}
  end)

incremental = fn entries ->
  Enum.reduce(entries, %{}, fn {path, method, operation}, paths ->
    PathRegistry.put(paths, path, method, operation)
  end)
end

for {_, entries} <- path_inputs do
  true = incremental.(entries) === PathRegistry.from_operations(entries)
end

run.(
  "paths",
  "Path registration",
  "Compares the retained incremental API with indexed bulk generation using identical operations.",
  %{
    "incremental registration" => incremental,
    "indexed registration" => &PathRegistry.from_operations/1
  },
  path_inputs
)

reference_inputs =
  Enum.map([100, 500, 1000, 2000], fn size ->
    schemas = Map.new(1..size, &{"Schema#{&1}", %{type: :string}})
    refs = Enum.map(Map.keys(schemas), &SchemaRef.schema_ref/1)
    :ok = SchemaBuilder.validate_refs!(refs, schemas)

    rejected =
      try do
        SchemaBuilder.validate_refs!(SchemaRef.schema_ref("Missing"), schemas)
        false
      rescue
        ArgumentError -> true
      end

    true = rejected
    {"#{size} references", {refs, schemas}}
  end)

run.(
  "references",
  "Schema reference checks",
  "Measures the current validator with distinct local references and matching component targets.",
  %{
    "validate local references" => fn {refs, schemas} ->
      SchemaBuilder.validate_refs!(refs, schemas)
    end
  },
  reference_inputs
)

yaml_inputs =
  Enum.map([100, 500, 1000], fn size ->
    schemas =
      Map.new(1..size, fn index ->
        {"Item#{index}",
         %{
           "type" => "object",
           "properties" => %{
             "name" => %{"type" => "string"},
             "rating" => %{"type" => "number"},
             "active" => %{"type" => "boolean"}
           },
           "example" => %{"name" => "Item #{index}", "rating" => 1.0, "active" => false}
         }}
      end)

    spec =
      Oaskit.normalize_spec!(%{
        "openapi" => "3.1.0",
        "info" => %{"title" => "YAML benchmark", "version" => "1.0.0"},
        "paths" => %{},
        "components" => %{"schemas" => schemas},
        "x-native-values" => [nil, true, false, 1, 1.0, "1", [], %{}]
      })

    {:ok, _} = AshOaskit.validate(spec)
    {"#{size} schemas (#{byte_size(JSV.Codec.encode!(spec))} JSON bytes)", spec}
  end)

round_trip = fn spec ->
  spec |> JSV.Codec.encode!() |> JSV.Codec.decode!() |> Ymlr.document!()
end

for {_, spec} <- yaml_inputs do
  yaml = Ymlr.document!(spec)
  true = round_trip.(spec) === yaml
  true = YamlElixir.read_from_string!(yaml) === spec
end

run.(
  "yaml",
  "YAML export",
  "Compares the former JSON round trip with direct YAML encoding of normalized native values.",
  %{"JSON round trip then YAML" => round_trip, "direct YAML" => &Ymlr.document!/1},
  yaml_inputs
)
