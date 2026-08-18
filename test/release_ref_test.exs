defmodule AshOaskit.ReleaseRefTest do
  @moduledoc false

  use ExUnit.Case, async: true

  @script Path.expand("../scripts/verify_release_ref.exs", __DIR__)

  test "accepts only the exact version tag" do
    assert {output, 0} = verify_ref("refs/tags/v0.3.0")
    assert output =~ "matches package version 0.3.0"
  end

  test "rejects mismatched, malformed, and non-tag refs" do
    for ref <- ["refs/tags/v0.3.1", "refs/tags/vgarbage", "refs/heads/main"] do
      assert {output, 1} = verify_ref(ref)
      assert output =~ "cannot publish"
      assert output =~ "refs/tags/v0.3.0"
    end
  end

  defp verify_ref(ref) do
    executable = System.find_executable("elixir") || raise "elixir executable not found"

    System.cmd(executable, [@script, ref],
      stderr_to_stdout: true,
      env: %{"CODECOV_TOKEN" => nil, "GITHUB_TOKEN" => nil, "HEX_API_KEY" => nil}
    )
  end
end
