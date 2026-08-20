Code.require_file("../scripts/release_ref.exs", __DIR__)

defmodule AshOaskit.ReleaseRefTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias AshOaskit.ReleaseRef

  setup do
    repository =
      Path.join(
        System.tmp_dir!(),
        "ash_oaskit_release_ref_#{System.unique_integer([:positive])}"
      )

    File.mkdir_p!(repository)
    git!(repository, ["init", "--quiet", "--initial-branch=main"])
    git!(repository, ["config", "user.email", "release-test@example.invalid"])
    git!(repository, ["config", "user.name", "Release Test"])
    File.write!(Path.join(repository, "release.txt"), "first\n")
    git!(repository, ["add", "release.txt"])
    git!(repository, ["commit", "--quiet", "-m", "first"])
    sha = git!(repository, ["rev-parse", "HEAD"])
    git!(repository, ["tag", "--annotate", "v0.3.0", "--message", "v0.3.0"])

    on_exit(fn -> File.rm_rf!(repository) end)

    %{environment: release_environment(sha), repository: repository, sha: sha}
  end

  test "accepts the exact annotated tag at the protected commit", context do
    assert :ok =
             ReleaseRef.verify!("0.3.0", context.environment, context.repository, "main")
  end

  test "rejects mismatched and non-tag refs", context do
    for ref <- ["refs/tags/v0.3.1", "refs/tags/vgarbage", "refs/heads/main"] do
      environment = Map.put(context.environment, "GITHUB_REF", ref)

      assert_raise ArgumentError, ~r/release must run from refs\/tags\/v0\.3\.0/, fn ->
        ReleaseRef.verify!("0.3.0", environment, context.repository, "main")
      end
    end
  end

  test "rejects a lightweight tag", context do
    git!(context.repository, ["tag", "--delete", "v0.3.0"])
    git!(context.repository, ["tag", "v0.3.0"])

    assert_raise ArgumentError, ~r/must be an annotated tag/, fn ->
      ReleaseRef.verify!("0.3.0", context.environment, context.repository, "main")
    end
  end

  test "rejects a tag or checkout that differs from the triggering SHA", context do
    File.write!(Path.join(context.repository, "release.txt"), "second\n")
    git!(context.repository, ["add", "release.txt"])
    git!(context.repository, ["commit", "--quiet", "-m", "second"])
    second_sha = git!(context.repository, ["rev-parse", "HEAD"])

    assert_raise ArgumentError, ~r/resolves to .* not triggering SHA/, fn ->
      ReleaseRef.verify!(
        "0.3.0",
        release_environment(second_sha),
        context.repository,
        "main"
      )
    end

    assert_raise ArgumentError, ~r/checked out HEAD .* does not match triggering SHA/, fn ->
      ReleaseRef.verify!("0.3.0", context.environment, context.repository, "main")
    end
  end

  test "rejects a commit outside protected main", context do
    git!(context.repository, ["checkout", "--quiet", "--orphan", "release-only"])
    File.write!(Path.join(context.repository, "release.txt"), "orphan\n")
    git!(context.repository, ["add", "release.txt"])
    git!(context.repository, ["commit", "--quiet", "-m", "orphan"])
    orphan_sha = git!(context.repository, ["rev-parse", "HEAD"])
    git!(context.repository, ["tag", "--delete", "v0.3.0"])
    git!(context.repository, ["tag", "--annotate", "v0.3.0", "--message", "v0.3.0"])

    assert_raise ArgumentError, ~r/is not an ancestor of protected main/, fn ->
      ReleaseRef.verify!(
        "0.3.0",
        release_environment(orphan_sha),
        context.repository,
        "main"
      )
    end
  end

  test "rejects a malformed triggering SHA", context do
    environment = Map.put(context.environment, "GITHUB_SHA", "not-a-sha")

    assert_raise ArgumentError, ~r/lowercase 40-character commit SHA/, fn ->
      ReleaseRef.verify!("0.3.0", environment, context.repository, "main")
    end
  end

  defp release_environment(sha) do
    %{"GITHUB_REF" => "refs/tags/v0.3.0", "GITHUB_SHA" => sha}
  end

  defp git!(repository, arguments) do
    options = [
      stderr_to_stdout: true,
      env: [{"CODECOV_TOKEN", nil}, {"GITHUB_TOKEN", nil}, {"HEX_API_KEY", nil}]
    ]

    case System.cmd("git", ["-C", repository | arguments], options) do
      {output, 0} -> String.trim(output)
      {output, status} -> flunk("git failed with status #{status}: #{output}")
    end
  end
end
