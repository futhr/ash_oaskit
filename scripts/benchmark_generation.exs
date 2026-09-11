# Run with mix run scripts/benchmark_generation.exs. Inputs and warmup are outside
# timed work. Compare the retained incremental API against indexed bulk generation.
# Timings are local medians; they measure neither allocated memory nor peak RSS.
alias AshOaskit.Core.PathRegistry
alias AshOaskit.SchemaBuilder

for size <- [100, 500, 1000, 2000] do
  entries = Enum.map(1..size, &{"/items#{&1}/{id}", "get", %{operationId: "op#{&1}"}})
  schemas = Map.new(1..size, &{"Schema#{&1}", %{type: :string}})
  refs = Enum.map(Map.keys(schemas), &%{"$ref" => "#/components/schemas/#{&1}"})

  incremental = fn ->
    Enum.reduce(entries, %{}, fn {path, method, op}, acc ->
      PathRegistry.put(acc, path, method, op)
    end)
  end

  indexed = fn -> PathRegistry.from_operations(entries) end
  true = incremental.() === indexed.()

  for {label, run} <- [
        incremental: incremental,
        indexed: indexed,
        references: fn -> SchemaBuilder.validate_refs!(refs, schemas) end
      ] do
    run.()
    times = Enum.sort(for _ <- 1..3, do: elem(:timer.tc(run), 0))

    IO.puts(
      "#{label} entries=#{size} median_us=#{Enum.at(times, 1)} samples_us=#{inspect(times)}"
    )
  end
end
