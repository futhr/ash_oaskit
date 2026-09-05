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

  test "rejects a repository secret as a substitute for an environment secret" do
    state = %{protected_state() | secrets: %{"secrets" => []}}
    assert [message] = ReleaseControls.violations(state, ["Test"])
    assert message =~ "HEX_API_KEY"
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
