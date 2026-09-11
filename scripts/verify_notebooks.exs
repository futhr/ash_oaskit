# Run with `mix run scripts/verify_notebooks.exs` using the checkout dependencies.
# Consumer checks separately exercise package installation. Livebook setup cells
# and explicitly non-executable examples are excluded from this local check.
Application.put_env(:ash_oaskit, :cache_specs, false)

for path <- Path.wildcard("notebooks/*.livemd") do
  cells =
    ~r/(<!-- livebook:\{"force_markdown":true\} -->\s*)?```elixir\n(.*?)\n```/s
    |> Regex.scan(File.read!(path))
    |> Enum.flat_map(fn [_, markdown, code] ->
      if markdown == "" and not String.contains?(code, "Mix.install("), do: [code], else: []
    end)

  {bindings, _} =
    Enum.reduce(cells, {[], Code.env_for_eval(file: path)}, fn code, {bindings, env} ->
      {_, bindings, env} = Code.eval_quoted_with_env(Code.string_to_quoted!(code), bindings, env)
      {bindings, env}
    end)

  for {_, spec} <- bindings, is_map(spec), Map.has_key?(spec, "openapi") do
    AshOaskit.validate!(spec)
  end

  IO.puts("Verified #{path}: #{length(cells)} executable cells")
end
