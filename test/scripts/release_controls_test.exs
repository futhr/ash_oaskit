Code.require_file("../../scripts/release_controls.exs", __DIR__)

defmodule AshOaskit.ReleaseControlsTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias AshOaskit.ReleaseControls

  defp protected_state do
    %{
      main: [
        %{"type" => "deletion"},
        %{"type" => "non_fast_forward"},
        %{"type" => "pull_request"},
        %{
          "type" => "required_status_checks",
          "parameters" => %{
            "strict_required_status_checks_policy" => true,
            "required_status_checks" => [%{"context" => "Test", "integration_id" => 15368}]
          }
        }
      ],
      tags: [
        %{
          "target" => "tag",
          "enforcement" => "active",
          "bypass_actors" => [],
          "conditions" => %{"ref_name" => %{"include" => ["refs/tags/v*"], "exclude" => []}},
          "rules" => Enum.map(["creation", "update", "deletion"], &%{"type" => &1})
        }
      ],
      environment: %{
        "can_admins_bypass" => false,
        "protection_rules" => [
          %{"type" => "required_reviewers", "reviewers" => [%{"type" => "User"}]}
        ]
      },
      policies: %{"branch_policies" => [%{"name" => "v*", "type" => "tag"}]},
      secrets: %{"secrets" => [%{"name" => "HEX_API_KEY"}]}
    }
  end

  test "accepts the required controls" do
    assert ReleaseControls.violations(protected_state(), ["Test"]) == []
  end

  test "detects new CI jobs that are not required" do
    assert [message] = ReleaseControls.violations(protected_state(), ["Test", "New job"])
    assert message =~ "every current CI job"
  end

  test "rejects a repository key without explicit owner authorization" do
    state =
      protected_state()
      |> Map.put(:secrets, %{"secrets" => []})
      |> Map.put(:repository_secrets, %{"secrets" => [%{"name" => "HEX_API_KEY"}]})
      |> Map.put(:authenticated_actor, "futhr")

    assert [message] = ReleaseControls.violations(state, ["Test"])
    assert message =~ "HEX_API_KEY"
  end

  test "accepts an existing repository key explicitly authorized by the authenticated owner" do
    state = owner_authorized_repository_state()
    assert ReleaseControls.violations(state, ["Test"]) == []
  end

  test "rejects repository-key authorization by another authenticated user" do
    state =
      Map.put(owner_authorized_repository_state(), :authenticated_actor, "another-maintainer")

    assert [message] = ReleaseControls.violations(state, ["Test"])
    assert message =~ "HEX_API_KEY"
  end

  test "owner authorization still requires an existing repository key" do
    state = Map.put(owner_authorized_repository_state(), :repository_secrets, %{"secrets" => []})
    assert [message] = ReleaseControls.violations(state, ["Test"])
    assert message =~ "HEX_API_KEY"
  end

  defp owner_authorized_repository_state do
    protected_state()
    |> Map.put(:secrets, %{"secrets" => []})
    |> Map.put(:repository_secrets, %{"secrets" => [%{"name" => "HEX_API_KEY"}]})
    |> Map.put(:authenticated_actor, "futhr")
    |> Map.put(:owner_authorized_repository_key, true)
  end

  test "rejects bypassable immutable tags and branch deployments" do
    state = protected_state()
    tags = Enum.map(state.tags, &Map.put(&1, "bypass_actors", [%{"actor_type" => "Integration"}]))

    state = %{
      state
      | tags: tags,
        policies: %{"branch_policies" => [%{"name" => "v*", "type" => "branch"}]}
    }

    assert length(ReleaseControls.violations(state, ["Test"])) == 3
  end
end
