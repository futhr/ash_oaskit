defmodule AshOaskit.Core.SchemaRefTest do
  @moduledoc """
  Tests for the `AshOaskit.Core.SchemaRef` module.

  Verifies that `$ref` objects and path strings are constructed correctly
  for component schema references. Includes doctests to validate the
  inline examples in the module documentation.

  ## Test categories

    - `schema_ref/1` — Builds `%{"$ref" => ...}` maps with string keys
    - `schema_ref_path/1` — Builds `#/components/schemas/...` path strings
  """
  use ExUnit.Case, async: true

  alias AshOaskit.Core.SchemaRef

  doctest AshOaskit.Core.SchemaRef

  describe "schema_ref/1" do
    test "builds ref object with correct path" do
      assert SchemaRef.schema_ref("User") == %{"$ref" => "#/components/schemas/User"}
    end

    test "works with suffixed names" do
      assert SchemaRef.schema_ref("UserAttributes") ==
               %{"$ref" => "#/components/schemas/UserAttributes"}
    end

    test "works with interpolated names" do
      name = "Post"

      assert SchemaRef.schema_ref("#{name}Response") ==
               %{"$ref" => "#/components/schemas/PostResponse"}
    end
  end

  describe "schema_ref_path/1" do
    test "builds correct path string" do
      assert SchemaRef.schema_ref_path("User") == "#/components/schemas/User"
    end

    test "works with suffixed names" do
      assert SchemaRef.schema_ref_path("UserRelationships") ==
               "#/components/schemas/UserRelationships"
    end
  end
end
