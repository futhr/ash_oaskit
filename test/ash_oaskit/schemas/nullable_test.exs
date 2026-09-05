defmodule AshOaskit.Schemas.NullableTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias AshOaskit.Schemas.Nullable

  test "simple schemas retain constraints and allow null exactly once" do
    for version <- ["3.0", "3.1"] do
      schema = %{type: :string, enum: ["draft"], description: "Status", maxLength: 10}
      nullable = Nullable.make_nullable(schema, version)

      assert nullable.enum == ["draft", nil]
      assert nullable.description == "Status"
      assert nullable.maxLength == 10
      assert Nullable.make_nullable(nullable, version) == nullable

      if version == "3.1" do
        assert nullable.type == [:string, :null]
      else
        assert nullable.type == :string
        assert nullable.nullable
      end
    end
  end

  test "compositions preserve sibling constraints and already-nullable branches" do
    for schema <- [
          %{oneOf: [%{type: :string}, %{type: :null}], description: "Value"},
          %{anyOf: [%{type: :string}, %{type: :integer}], maxLength: 3},
          %{type: [:string, :null], enum: ["ok"]},
          %{type: :string, const: "ok"}
        ] do
      nullable = Nullable.make_nullable(schema, "3.1")
      validator = nullable |> Jason.encode!() |> Jason.decode!() |> JSV.build!()

      assert {:ok, _} = JSV.validate(nil, validator)
      assert {:ok, _} = JSV.validate("ok", validator)
      assert {:error, _} = JSV.validate(%{}, validator)
      assert Nullable.make_nullable(nullable, "3.1") == nullable
    end
  end

  test "nullable refs allow null even when the referenced schema already allows it" do
    nullable = Nullable.make_nullable_oneof(%{"$ref" => "#/$defs/value"}, "3.1")

    validator =
      nullable
      |> Jason.encode!()
      |> Jason.decode!()
      |> Map.put("$defs", %{"value" => %{"type" => ["string", "null"]}})
      |> JSV.build!()

    assert {:ok, _} = JSV.validate(nil, validator)
    assert {:ok, _} = JSV.validate("value", validator)
    assert {:error, _} = JSV.validate(123, validator)
  end

  test "3.0 reference nullability has an explicit null-only typed branch" do
    ref = %{"$ref" => "#/components/schemas/User"}

    assert Nullable.make_nullable(ref, "3.0") ==
             %{anyOf: [%{type: :object, nullable: true, enum: [nil]}, ref]}
  end

  test "string-key schemas share the same nullable implementation" do
    assert Nullable.make_nullable(
             %{"type" => ["string", "null"], "enum" => ["ok"]},
             "3.1",
             :string
           ) ==
             %{"type" => ["string", "null"], "enum" => ["ok", nil]}
  end

  test "unconstrained schemas already accept null" do
    assert Nullable.make_nullable(%{}, "3.0") == %{}
    assert Nullable.make_nullable(%{}, "3.1") == %{}
  end
end
