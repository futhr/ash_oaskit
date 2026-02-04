defmodule AshOaskit.OpenAPI30ComplianceTest do
  @moduledoc """
  OpenAPI 3.0.3 Specification Compliance Tests.

  These tests verify that ash_oaskit generates specs compliant with the
  OpenAPI 3.0.3 specification, focusing on the differences from 3.1.

  Reference: https://spec.openapis.org/oas/v3.0.3

  ## Key 3.0 Features Tested

  - **Nullable flag** - `nullable: true` instead of type arrays
  - **Type is always a string** - Never an array
  - **No JSON Schema 2020-12** - Draft 5 subset only
  - **Version string** - Must be "3.0.3"

  ## 3.0 vs 3.1 Differences

  | Feature | 3.0 | 3.1 |
  |---------|-----|-----|
  | Nullable | `nullable: true` | `type: [T, "null"]` |
  | Schema | OpenAPI subset | JSON Schema 2020-12 |
  | exclusiveMin | boolean | numeric |
  """

  use ExUnit.Case, async: true

  alias AshOaskit.TypeMapper

  # Helper to build a mock attribute map
  defp mock_attr(overrides) do
    Map.merge(
      %{
        name: :test_field,
        type: :string,
        allow_nil?: false,
        constraints: [],
        description: nil,
        default: nil
      },
      overrides
    )
  end

  describe "nullable handling (3.0 style)" do
    test "nullable string uses nullable: true flag" do
      schema = TypeMapper.to_json_schema_30(mock_attr(%{type: :string, allow_nil?: true}))

      assert schema["nullable"] == true
      assert schema["type"] == "string"
      refute is_list(schema["type"])
    end

    test "non-nullable string has no nullable key" do
      schema = TypeMapper.to_json_schema_30(mock_attr(%{type: :string, allow_nil?: false}))

      refute Map.has_key?(schema, "nullable")
      assert schema["type"] == "string"
    end

    test "nullable integer uses nullable: true flag" do
      schema = TypeMapper.to_json_schema_30(mock_attr(%{type: :integer, allow_nil?: true}))

      assert schema["nullable"] == true
      assert schema["type"] == "integer"
      refute is_list(schema["type"])
    end

    test "nullable boolean uses nullable: true flag" do
      schema = TypeMapper.to_json_schema_30(mock_attr(%{type: :boolean, allow_nil?: true}))

      assert schema["nullable"] == true
      assert schema["type"] == "boolean"
      refute is_list(schema["type"])
    end

    test "nullable array uses nullable: true flag" do
      schema =
        TypeMapper.to_json_schema_30(mock_attr(%{type: {:array, :string}, allow_nil?: true}))

      assert schema["nullable"] == true
      assert schema["type"] == "array"
      refute is_list(schema["type"])
      assert schema["items"] == %{"type" => "string"}
    end

    test "nullable uuid uses nullable: true flag" do
      schema = TypeMapper.to_json_schema_30(mock_attr(%{type: :uuid, allow_nil?: true}))

      assert schema["nullable"] == true
      assert schema["type"] == "string"
      assert schema["format"] == "uuid"
      refute is_list(schema["type"])
    end

    test "nullable map uses nullable: true flag" do
      schema = TypeMapper.to_json_schema_30(mock_attr(%{type: :map, allow_nil?: true}))

      assert schema["nullable"] == true
      assert schema["type"] == "object"
      refute is_list(schema["type"])
    end

    test "nullable datetime uses nullable: true flag" do
      schema =
        TypeMapper.to_json_schema_30(mock_attr(%{type: :utc_datetime, allow_nil?: true}))

      assert schema["nullable"] == true
      assert schema["type"] == "string"
      assert schema["format"] == "date-time"
      refute is_list(schema["type"])
    end
  end

  describe "type is always a string in 3.0" do
    test "non-nullable types produce string type values" do
      types = [
        :string,
        :integer,
        :float,
        :decimal,
        :boolean,
        :date,
        :time,
        :datetime,
        :utc_datetime,
        :uuid,
        :binary,
        :map,
        :atom
      ]

      for type <- types do
        schema = TypeMapper.to_json_schema_30(mock_attr(%{type: type}))

        assert is_binary(schema["type"]),
               "Expected string type for #{type}, got: #{inspect(schema["type"])}"
      end
    end

    test "nullable types still produce string type values" do
      types = [:string, :integer, :boolean, :uuid, :map]

      for type <- types do
        schema = TypeMapper.to_json_schema_30(mock_attr(%{type: type, allow_nil?: true}))

        assert is_binary(schema["type"]),
               "Expected string type for nullable #{type}, got: #{inspect(schema["type"])}"
      end
    end

    test "array type produces string type value" do
      schema = TypeMapper.to_json_schema_30(mock_attr(%{type: {:array, :string}}))
      assert schema["type"] == "array"
      assert is_binary(schema["type"])
    end
  end

  describe "OpenAPI version declaration" do
    test "V30 generator outputs openapi 3.0.3" do
      spec = AshOaskit.spec_30(domains: [AshOaskit.Test.SimpleDomain])
      assert spec["openapi"] == "3.0.3"
    end

    test "spec includes required info object" do
      spec = AshOaskit.spec_30(domains: [AshOaskit.Test.SimpleDomain], title: "Test API")

      assert is_map(spec["info"])
      assert spec["info"]["title"] == "Test API"
      assert is_binary(spec["info"]["version"])
    end
  end

  describe "constraint mapping (same as 3.1)" do
    test "min_length constraint maps to minLength" do
      schema =
        TypeMapper.to_json_schema_30(mock_attr(%{type: :string, constraints: [min_length: 5]}))

      assert schema["minLength"] == 5
    end

    test "max_length constraint maps to maxLength" do
      schema =
        TypeMapper.to_json_schema_30(mock_attr(%{type: :string, constraints: [max_length: 100]}))

      assert schema["maxLength"] == 100
    end

    test "min constraint maps to minimum" do
      schema =
        TypeMapper.to_json_schema_30(mock_attr(%{type: :integer, constraints: [min: 0]}))

      assert schema["minimum"] == 0
    end

    test "max constraint maps to maximum" do
      schema =
        TypeMapper.to_json_schema_30(mock_attr(%{type: :integer, constraints: [max: 100]}))

      assert schema["maximum"] == 100
    end

    test "one_of constraint maps to enum" do
      schema =
        TypeMapper.to_json_schema_30(
          mock_attr(%{type: :atom, constraints: [one_of: [:draft, :published]]})
        )

      assert schema["enum"] == ["draft", "published"]
    end

    test "match constraint maps to pattern" do
      schema =
        TypeMapper.to_json_schema_30(
          mock_attr(%{type: :string, constraints: [match: ~r/^[a-z]+$/]})
        )

      assert schema["pattern"] == "^[a-z]+$"
    end

    test "constraints preserved on nullable fields" do
      schema =
        TypeMapper.to_json_schema_30(
          mock_attr(%{
            type: :string,
            allow_nil?: true,
            constraints: [min_length: 1, max_length: 50]
          })
        )

      assert schema["nullable"] == true
      assert schema["minLength"] == 1
      assert schema["maxLength"] == 50
    end
  end

  describe "description and default preservation" do
    test "description preserved on non-nullable field" do
      schema =
        TypeMapper.to_json_schema_30(mock_attr(%{description: "A test field"}))

      assert schema["description"] == "A test field"
    end

    test "description preserved on nullable field" do
      schema =
        TypeMapper.to_json_schema_30(
          mock_attr(%{description: "Nullable description", allow_nil?: true})
        )

      assert schema["description"] == "Nullable description"
      assert schema["nullable"] == true
    end

    test "static default value included" do
      schema = TypeMapper.to_json_schema_30(mock_attr(%{default: "draft"}))
      assert schema["default"] == "draft"
    end

    test "boolean false default included" do
      schema = TypeMapper.to_json_schema_30(mock_attr(%{type: :boolean, default: false}))
      assert schema["default"] == false
    end

    test "integer zero default included" do
      schema = TypeMapper.to_json_schema_30(mock_attr(%{type: :integer, default: 0}))
      assert schema["default"] == 0
    end

    test "function default excluded" do
      schema = TypeMapper.to_json_schema_30(mock_attr(%{default: &Ash.UUID.generate/0}))
      refute Map.has_key?(schema, "default")
    end
  end

  describe "format strings" do
    test "uuid type has uuid format" do
      schema = TypeMapper.to_json_schema_30(mock_attr(%{type: :uuid}))
      assert schema["format"] == "uuid"
    end

    test "date type has date format" do
      schema = TypeMapper.to_json_schema_30(mock_attr(%{type: :date}))
      assert schema["format"] == "date"
    end

    test "time type has time format" do
      schema = TypeMapper.to_json_schema_30(mock_attr(%{type: :time}))
      assert schema["format"] == "time"
    end

    test "datetime types have date-time format" do
      for type <- [:datetime, :utc_datetime, :utc_datetime_usec, :naive_datetime] do
        schema = TypeMapper.to_json_schema_30(mock_attr(%{type: type}))

        assert schema["format"] == "date-time",
               "Expected date-time format for #{type}"
      end
    end

    test "float type has float format" do
      schema = TypeMapper.to_json_schema_30(mock_attr(%{type: :float}))
      assert schema["format"] == "float"
    end

    test "decimal type has double format" do
      schema = TypeMapper.to_json_schema_30(mock_attr(%{type: :decimal}))
      assert schema["format"] == "double"
    end

    test "binary type has binary format" do
      schema = TypeMapper.to_json_schema_30(mock_attr(%{type: :binary}))
      assert schema["format"] == "binary"
    end
  end

  describe "special types" do
    test "map type becomes object" do
      schema = TypeMapper.to_json_schema_30(mock_attr(%{type: :map}))
      assert schema["type"] == "object"
    end

    test "atom type becomes string" do
      schema = TypeMapper.to_json_schema_30(mock_attr(%{type: :atom}))
      assert schema["type"] == "string"
    end

    test "term type becomes empty schema" do
      schema = TypeMapper.to_json_schema_30(mock_attr(%{type: :term}))
      assert schema == %{} or schema == %{"description" => nil}
    end

    test "ci_string type becomes string" do
      schema = TypeMapper.to_json_schema_30(mock_attr(%{type: :ci_string}))
      assert schema["type"] == "string"
    end
  end

  describe "array type handling" do
    test "array of strings" do
      schema = TypeMapper.to_json_schema_30(mock_attr(%{type: {:array, :string}}))

      assert schema["type"] == "array"
      assert schema["items"] == %{"type" => "string"}
    end

    test "array of integers" do
      schema = TypeMapper.to_json_schema_30(mock_attr(%{type: {:array, :integer}}))

      assert schema["type"] == "array"
      assert schema["items"] == %{"type" => "integer"}
    end

    test "nested array" do
      schema = TypeMapper.to_json_schema_30(mock_attr(%{type: {:array, {:array, :integer}}}))

      assert schema["type"] == "array"
      assert schema["items"]["type"] == "array"
      assert schema["items"]["items"] == %{"type" => "integer"}
    end
  end

  describe "schema structure compliance" do
    test "schemas are placed in components/schemas" do
      spec = AshOaskit.spec_30(domains: [AshOaskit.Test.SimpleDomain])

      assert is_map(spec["components"])
      assert is_map(spec["components"]["schemas"])
    end

    test "schema references use correct format" do
      spec = AshOaskit.spec_30(domains: [AshOaskit.Test.Blog])

      paths = spec["paths"] || %{}

      refs =
        paths
        |> Jason.encode!()
        |> then(&Regex.scan(~r/"\$ref"\s*:\s*"([^"]+)"/, &1))
        |> Enum.map(fn [_, ref] -> ref end)

      Enum.each(refs, fn ref ->
        assert String.starts_with?(ref, "#/components/schemas/") or
                 String.starts_with?(ref, "#/components/"),
               "Invalid $ref format: #{ref}"
      end)
    end

    test "component keys match valid pattern" do
      spec = AshOaskit.spec_30(domains: [AshOaskit.Test.SimpleDomain])

      schemas = spec["components"]["schemas"] || %{}

      Enum.each(Map.keys(schemas), fn key ->
        assert Regex.match?(~r/^[a-zA-Z0-9.\-_]+$/, key),
               "Invalid component key: #{key}"
      end)
    end
  end

  describe "Oaskit validation for 3.0" do
    test "full spec passes Oaskit validation" do
      spec = AshOaskit.spec_30(domains: [AshOaskit.Test.Blog])
      assert {:ok, %Oaskit.Spec.OpenAPI{}} = AshOaskit.validate(spec)
    end

    test "multi-domain spec passes Oaskit validation" do
      spec =
        AshOaskit.spec_30(
          domains: [AshOaskit.Test.SimpleDomain, AshOaskit.Test.Blog],
          title: "Multi-Domain API",
          api_version: "1.0.0"
        )

      assert {:ok, %Oaskit.Spec.OpenAPI{}} = AshOaskit.validate(spec)
    end

    test "spec roundtrips through JSON encoding" do
      spec = AshOaskit.spec_30(domains: [AshOaskit.Test.Blog])

      json = Jason.encode!(spec)
      decoded = Jason.decode!(json)

      assert decoded["openapi"] == "3.0.3"
      assert is_map(decoded["info"])
      assert is_map(decoded["paths"])
    end
  end
end
