Mix.start()

project_root = Path.expand("..", __DIR__)
Code.require_file(Path.join(project_root, "mix.exs"))

version = AshOaskit.MixProject.project() |> Keyword.fetch!(:version)
expected_ref = "refs/tags/v#{version}"

case System.argv() do
  [^expected_ref] ->
    IO.puts("Release ref matches package version #{version}")

  [actual_ref] ->
    IO.puts(:stderr, "Ref #{inspect(actual_ref)} cannot publish; expected #{expected_ref}")
    System.halt(1)

  _ ->
    IO.puts(:stderr, "Usage: elixir scripts/verify_release_ref.exs <git-ref>")
    System.halt(1)
end
