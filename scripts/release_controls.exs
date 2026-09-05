defmodule AshOaskit.ReleaseControls do
  @moduledoc false

  def violations(state, checks) do
    rules = state.main
    environment = state.environment

    required_checks =
      Enum.find(rules, &(&1["type"] == "required_status_checks")) || %{}

    parameters = required_checks["parameters"] || %{}

    contexts =
      parameters
      |> Map.get("required_status_checks", [])
      |> Enum.filter(&(&1["integration_id"] == 15368))
      |> Enum.map(& &1["context"])

    [
      {Enum.all?(["deletion", "non_fast_forward", "pull_request"], fn type ->
         Enum.any?(rules, &(&1["type"] == type))
       end), "main must require reviewed PRs and forbid deletion/force pushes"},
      {parameters["strict_required_status_checks_policy"] == true and checks -- contexts == [],
       "main must require every current CI job from GitHub Actions and an up-to-date branch"},
      {Enum.any?(state.tags, &tag_rule?(&1, "creation", false)),
       "release tag creation must be restricted"},
      {Enum.any?(state.tags, &tag_rule?(&1, "update", true)) and
         Enum.any?(state.tags, &tag_rule?(&1, "deletion", true)),
       "release tags must forbid updates and deletion without bypasses"},
      {environment["can_admins_bypass"] == false, "hex-publish must disable admin bypass"},
      {Enum.any?(environment["protection_rules"], fn rule ->
         rule["type"] == "required_reviewers" and rule["reviewers"] != []
       end), "hex-publish must require a reviewer"},
      {Enum.map(state.policies["branch_policies"], &Map.take(&1, ["name", "type"])) ==
         [%{"name" => "v*", "type" => "tag"}], "hex-publish must allow only v* tags"},
      {Enum.any?(state.secrets["secrets"], &(&1["name"] == "HEX_API_KEY")),
       "add a package-scoped HEX_API_KEY to the hex-publish environment"}
    ]
    |> Enum.reject(&elem(&1, 0))
    |> Enum.map(&elem(&1, 1))
  end

  defp tag_rule?(rule, type, immutable?) do
    rule["target"] == "tag" and rule["enforcement"] == "active" and
      get_in(rule, ["conditions", "ref_name"]) ==
        %{"include" => ["refs/tags/v*"], "exclude" => []} and
      Enum.any?(rule["rules"], &(&1["type"] == type)) and
      allowed_bypasses?(rule["bypass_actors"], immutable?)
  end

  defp allowed_bypasses?(actors, true), do: actors == []

  defp allowed_bypasses?(actors, false) do
    Enum.all?(actors, fn actor ->
      actor["actor_type"] == "RepositoryRole" and actor["actor_id"] in [2, 5]
    end)
  end
end
