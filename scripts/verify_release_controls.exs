Code.require_file("release_controls.exs", __DIR__)

{opts, arguments} =
  OptionParser.parse!(System.argv(), strict: [owner_authorized_repository_key: :boolean])

if arguments != [], do: Mix.raise("Unexpected release-control arguments: #{inspect(arguments)}")

api = fn path ->
  case System.cmd("gh", ["api", path], stderr_to_stdout: true) do
    {output, 0} -> Jason.decode!(output)
    {output, _} -> Mix.raise("Cannot inspect release controls: #{output}")
  end
end

repo_api = fn path -> api.("repos/futhr/ash_oaskit/#{path}") end
owner_authorized_repository_key = Keyword.get(opts, :owner_authorized_repository_key, false)

{authenticated_actor, repository_secrets} =
  if owner_authorized_repository_key do
    {api.("user")["login"], repo_api.("actions/secrets")}
  else
    {nil, %{"secrets" => []}}
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
  main: repo_api.("rules/branches/main"),
  tags: Enum.map(repo_api.("rulesets"), &repo_api.("rulesets/#{&1["id"]}")),
  environment: repo_api.("environments/hex-publish"),
  policies: repo_api.("environments/hex-publish/deployment-branch-policies"),
  secrets: repo_api.("environments/hex-publish/secrets"),
  repository_secrets: repository_secrets,
  authenticated_actor: authenticated_actor,
  owner_authorized_repository_key: owner_authorized_repository_key
}

case AshOaskit.ReleaseControls.violations(state, checks) do
  [] -> Mix.shell().info("Release controls verified. Confirm the Hex key's package scope in Hex.")
  problems -> Mix.raise("Release controls incomplete:\n- " <> Enum.join(problems, "\n- "))
end
