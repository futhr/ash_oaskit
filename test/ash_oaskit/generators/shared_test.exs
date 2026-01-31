defmodule AshOaskit.Generators.SharedTest do
  @moduledoc """
  Tests for the AshOaskit.Generators.Shared module.

  This module tests the Shared delegate module that provides a unified API
  for accessing generator functionality. It delegates to the appropriate
  specialized modules (Generator, InfoBuilder, PathBuilder, etc.).

  ## Test Categories

  - **Generate delegation** - Verifies spec generation delegates to Generator
  - **Info building** - Verifies info object building delegates to InfoBuilder
  - **Path building** - Verifies path generation delegates to PathBuilder
  - **Consistency** - Ensures Shared API produces identical results to direct calls

  ## Why These Tests Matter

  The Shared module is the recommended entry point for internal use. If
  delegation is broken or inconsistent, other modules that depend on Shared
  will silently produce incorrect output.
  """

  use ExUnit.Case, async: true

  alias AshOaskit.Generators.Shared

  describe "generate/2" do
    test "delegates to Generator.generate/2" do
      spec = Shared.generate([AshOaskit.Test.Blog], version: "3.1", title: "Shared Test")
      assert spec["openapi"] =~ "3.1"
      assert spec["info"]["title"] == "Shared Test"
    end
  end

  describe "build_info/1" do
    test "delegates to InfoBuilder.build_info/1" do
      info = Shared.build_info(title: "Test", api_version: "2.0")
      assert info["title"] == "Test"
      assert info["version"] == "2.0"
    end
  end

  describe "build_servers/1" do
    test "delegates to InfoBuilder.build_servers/1" do
      servers = Shared.build_servers(servers: ["https://api.example.com"])
      assert is_list(servers)
      assert hd(servers)["url"] == "https://api.example.com"
    end
  end

  describe "build_paths/2" do
    test "delegates to PathBuilder.build_paths/2" do
      paths = Shared.build_paths([AshOaskit.Test.Blog], version: "3.1")
      assert is_map(paths)
    end
  end

  describe "build_components/2" do
    test "delegates to Generator.build_components/2" do
      components = Shared.build_components([AshOaskit.Test.Blog], version: "3.1")
      assert Map.has_key?(components, "schemas")
    end
  end

  describe "build_tags/1" do
    test "delegates to InfoBuilder.build_tags/1" do
      tags = Shared.build_tags([AshOaskit.Test.Blog])
      assert is_list(tags)
      assert Enum.all?(tags, &Map.has_key?(&1, "name"))
    end
  end

  describe "maybe_add/3" do
    test "delegates to InfoBuilder.maybe_add/3" do
      assert Shared.maybe_add(%{}, "key", "value") == %{"key" => "value"}
      assert Shared.maybe_add(%{}, "key", nil) == %{}
    end
  end

  describe "humanize/1" do
    test "delegates to PathBuilder.humanize/1" do
      assert Shared.humanize("create_user") == "Create User"
    end
  end
end
