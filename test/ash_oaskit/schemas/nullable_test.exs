defmodule AshOaskit.Schemas.NullableTest do
  use ExUnit.Case, async: true

  alias AshOaskit.Schemas.Nullable

  describe "make_nullable/2" do
    test "3.0: adds nullable true" do
      assert Nullable.make_nullable(%{type: :string}, "3.0") ==
               %{type: :string, nullable: true}
    end

    test "3.1: converts atom type to array with null" do
      assert Nullable.make_nullable(%{type: :string}, "3.1") ==
               %{type: [:string, :null]}
    end

    test "3.1: preserves other fields" do
      assert Nullable.make_nullable(%{type: :integer, format: :int32}, "3.1") ==
               %{type: [:integer, :null], format: :int32}
    end

    test "3.1: schema without type key is unchanged" do
      schema = %{oneOf: [%{type: :string}, %{type: :integer}]}
      assert Nullable.make_nullable(schema, "3.1") == schema
    end
  end

  describe "make_nullable_oneof/2" do
    test "3.0: adds nullable true" do
      assert Nullable.make_nullable_oneof(%{type: :object}, "3.0") ==
               %{type: :object, nullable: true}
    end

    test "3.1: wraps schema in oneOf with null type first" do
      schema = %{type: :object, properties: %{id: %{type: :string}}}

      assert Nullable.make_nullable_oneof(schema, "3.1") ==
               %{oneOf: [%{type: :null}, schema]}
    end

    test "3.1: prepends null to existing oneOf list" do
      schema = %{oneOf: [%{type: :string}, %{type: :integer}]}

      assert Nullable.make_nullable_oneof(schema, "3.1") ==
               %{oneOf: [%{type: :null}, %{type: :string}, %{type: :integer}]}
    end

    test "3.1: works with ref schemas" do
      schema = %{"$ref" => "#/components/schemas/User"}

      assert Nullable.make_nullable_oneof(schema, "3.1") ==
               %{oneOf: [%{type: :null}, schema]}
    end
  end
end
