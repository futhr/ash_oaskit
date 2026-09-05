Code.require_file("release_controls.exs", __DIR__)

api = fn path ->
  case System.cmd("gh", ["api", "repos/futhr/ash_oaskit/#{path}"], stderr_to_stdout: true) do
    {output, 0} -> Jason.decode!(output)
    {output, _} -> Mix.raise("Cannot inspect release controls: #{output}")
  end
end

jobs = YamlElixir.read_from_file!(".github/workflows/ci.yml")["jobs"]

checks =
  Enum.flat_map(jobs, fn {id, job} ->
    name = job["name"] || id

    case get_in(job, ["strategy", "matrix", "include"]) do
      nil ->
        [name]

      matrix ->
        Enum.map(matrix, fn row ->
          Enum.reduce(row, name, fn {key, value}, name ->
            String.replace(name, ~r/\$\{\{\s*matrix\.#{key}\s*\}\}/, value)
          end)
        end)
    end
  end)

state = %{
  main: api.("rules/branches/main"),
  tags: Enum.map(api.("rulesets"), &api.("rulesets/#{&1["id"]}")),
  environment: api.("environments/hex-publish"),
  policies: api.("environments/hex-publish/deployment-branch-policies"),
  secrets: api.("environments/hex-publish/secrets")
}

case AshOaskit.ReleaseControls.violations(state, checks) do
  [] -> Mix.shell().info("Release controls verified. Confirm the Hex key's package scope in Hex.")
  problems -> Mix.raise("Release controls incomplete:\n- " <> Enum.join(problems, "\n- "))
end
