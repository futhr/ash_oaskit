defmodule AshOaskit.Core.PathUtilsTest do
  @moduledoc """
  Tests for the `AshOaskit.Core.PathUtils` module.

  Verifies path and route string utilities used across the generator
  pipeline. Includes doctests to validate the inline examples in the
  module documentation.

  ## Test categories

    - `humanize/1` — Converts underscore identifiers to title case
    - `extract_path_params/1` — Extracts `:param` names from routes
    - `convert_path_params/1` — Converts `:param` to `{param}` format
  """
  use ExUnit.Case, async: true

  alias AshOaskit.Core.PathUtils

  doctest AshOaskit.Core.PathUtils

  describe "humanize/1" do
    test "converts underscored string to title case" do
      assert PathUtils.humanize("create_user") == "Create User"
    end

    test "handles single word" do
      assert PathUtils.humanize("index") == "Index"
    end

    test "handles multiple underscores" do
      assert PathUtils.humanize("list_all_posts") == "List All Posts"
    end
  end

  describe "extract_path_params/1" do
    test "extracts single param" do
      assert PathUtils.extract_path_params("/posts/:id") == ["id"]
    end

    test "extracts multiple params" do
      assert PathUtils.extract_path_params("/posts/:post_id/comments/:id") ==
               ["post_id", "id"]
    end

    test "returns empty list when no params" do
      assert PathUtils.extract_path_params("/posts") == []
    end
  end

  describe "convert_path_params/1" do
    test "converts Phoenix style to OpenAPI style" do
      assert PathUtils.convert_path_params("/posts/:id") == "/posts/{id}"
    end

    test "converts multiple params" do
      assert PathUtils.convert_path_params("/posts/:post_id/comments/:id") ==
               "/posts/{post_id}/comments/{id}"
    end

    test "leaves paths without params unchanged" do
      assert PathUtils.convert_path_params("/posts") == "/posts"
    end
  end
end
