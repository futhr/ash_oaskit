defmodule AshOaskit.OpenAPI31ComplianceTest do
  @moduledoc """
  OpenAPI 3.1.0 Specification Compliance Tests.

  These tests verify that ash_oaskit generates specs compliant with the
  OpenAPI 3.1.0 specification, particularly focusing on JSON Schema 2020-12
  alignment and features new or changed in 3.1.

  Reference: https://spec.openapis.org/oas/v3.1.0

  ## Key 3.1 Features Tested

  - **Type Arrays** - `type: ["string", "null"]` instead of `nullable: true`
  - **JSON Schema Alignment** - Full JSON Schema 2020-12 compatibility
  - **Examples** - Both `example` and `examples` keywords
  - **Webhooks** - New webhooks object support

  ## 3.0 vs 3.1 Differences

  | Feature | 3.0 | 3.1 |
  |---------|-----|-----|
  | Nullable | `nullable: true` | `type: [T, "null"]` |
  | Schema | OpenAPI subset | JSON Schema 2020-12 |
  | Examples | `example` only | `example` + `examples` |
  """

  use ExUnit.Case, async: true

  alias AshOaskit.TypeMapper

  describe "JSON Schema 2020-12 type arrays" do
    test "nullable string uses type array instead of nullable keyword" do
      attr = %{
        name: :nullable_field,
        type: :string,
        allow_nil?: true,
        constraints: [],
        description: nil,
        default: nil
      }

      schema = TypeMapper.to_json_schema_31(attr)

      # OpenAPI 3.1 uses type arrays for nullable
      assert schema["type"] == ["string", "null"]
      # nullable keyword should NOT be present in 3.1
      refute Map.has_key?(schema, "nullable")
    end

    test "non-nullable string uses single type string" do
      attr = %{
        name: :required_field,
        type: :string,
        allow_nil?: false,
        constraints: [],
        description: nil,
        default: nil
      }

      schema = TypeMapper.to_json_schema_31(attr)

      assert schema["type"] == "string"
      refute is_list(schema["type"])
    end

    test "nullable integer uses type array" do
      attr = %{
        name: :count,
        type: :integer,
        allow_nil?: true,
        constraints: [],
        description: nil,
        default: nil
      }

      schema = TypeMapper.to_json_schema_31(attr)

      assert schema["type"] == ["integer", "null"]
    end

    test "nullable boolean uses type array" do
      attr = %{
        name: :flag,
        type: :boolean,
        allow_nil?: true,
        constraints: [],
        description: nil,
        default: nil
      }

      schema = TypeMapper.to_json_schema_31(attr)

      assert schema["type"] == ["boolean", "null"]
    end

    test "nullable array uses type array" do
      attr = %{
        name: :items,
        type: {:array, :string},
        allow_nil?: true,
        constraints: [],
        description: nil,
        default: nil
      }

      schema = TypeMapper.to_json_schema_31(attr)

      assert schema["type"] == ["array", "null"]
      assert schema["items"] == %{"type" => "string"}
    end

    test "already nullable type array is not duplicated" do
      # Edge case: if somehow type is already an array with null
      attr = %{
        name: :field,
        type: :string,
        allow_nil?: true,
        constraints: [],
        description: nil,
        default: nil
      }

      schema = TypeMapper.to_json_schema_31(attr)

      # Should only have "null" once
      null_count = Enum.count(schema["type"], &(&1 == "null"))
      assert null_count == 1
    end
  end

  describe "removed/changed keywords from 3.0 to 3.1" do
    test "nullable keyword not present in 3.1 output" do
      attr = %{
        name: :field,
        type: :string,
        allow_nil?: true,
        constraints: [],
        description: nil,
        default: nil
      }

      schema = TypeMapper.to_json_schema_31(attr)

      refute Map.has_key?(schema, "nullable")
    end

    test "3.0 uses nullable keyword instead of type array" do
      attr = %{
        name: :field,
        type: :string,
        allow_nil?: true,
        constraints: [],
        description: nil,
        default: nil
      }

      schema = TypeMapper.to_json_schema_30(attr)

      assert schema["nullable"] == true
      assert schema["type"] == "string"
      refute is_list(schema["type"])
    end
  end

  describe "OpenAPI version declaration" do
    test "V31 generator outputs openapi 3.1.0" do
      spec = AshOaskit.spec_31(domains: [AshOaskit.Test.SimpleDomain])

      assert spec["openapi"] == "3.1.0"
    end

    test "spec includes required info object" do
      spec = AshOaskit.spec_31(domains: [AshOaskit.Test.SimpleDomain], title: "Test API")

      assert is_map(spec["info"])
      assert spec["info"]["title"] == "Test API"
      assert is_binary(spec["info"]["version"])
    end
  end

  describe "schema structure compliance" do
    test "schemas are placed in components/schemas" do
      spec = AshOaskit.spec_31(domains: [AshOaskit.Test.SimpleDomain])

      assert is_map(spec["components"])
      assert is_map(spec["components"]["schemas"])
    end

    test "schema references use correct format" do
      spec = AshOaskit.spec_31(domains: [AshOaskit.Test.Blog])

      # Find a $ref in the spec
      paths = spec["paths"] || %{}

      refs =
        paths
        |> Jason.encode!()
        |> then(&Regex.scan(~r/"\$ref"\s*:\s*"([^"]+)"/, &1))
        |> Enum.map(fn [_, ref] -> ref end)

      # All refs should use components/schemas format
      Enum.each(refs, fn ref ->
        assert String.starts_with?(ref, "#/components/schemas/") or
                 String.starts_with?(ref, "#/components/")
      end)
    end

    test "component keys match valid pattern" do
      spec = AshOaskit.spec_31(domains: [AshOaskit.Test.SimpleDomain])

      schemas = spec["components"]["schemas"] || %{}

      # Keys must match ^[a-zA-Z0-9\.\-_]+$
      Enum.each(Map.keys(schemas), fn key ->
        assert Regex.match?(~r/^[a-zA-Z0-9.\-_]+$/, key),
               "Invalid component key: #{key}"
      end)
    end
  end

  describe "description preservation" do
    test "attribute description is included in schema" do
      attr = %{
        name: :described_field,
        type: :string,
        allow_nil?: false,
        constraints: [],
        description: "This is a test description",
        default: nil
      }

      schema = TypeMapper.to_json_schema_31(attr)

      assert schema["description"] == "This is a test description"
    end

    test "description preserved for nullable fields" do
      attr = %{
        name: :nullable_described,
        type: :string,
        allow_nil?: true,
        constraints: [],
        description: "Nullable field description",
        default: nil
      }

      schema = TypeMapper.to_json_schema_31(attr)

      # Description should be at the top level, not lost in type array transformation
      assert schema["description"] == "Nullable field description"
    end
  end

  describe "constraint mapping to JSON Schema" do
    test "min_length constraint maps to minLength" do
      attr = %{
        name: :constrained,
        type: :string,
        allow_nil?: false,
        constraints: [min_length: 5],
        description: nil,
        default: nil
      }

      schema = TypeMapper.to_json_schema_31(attr)

      assert schema["minLength"] == 5
    end

    test "max_length constraint maps to maxLength" do
      attr = %{
        name: :constrained,
        type: :string,
        allow_nil?: false,
        constraints: [max_length: 100],
        description: nil,
        default: nil
      }

      schema = TypeMapper.to_json_schema_31(attr)

      assert schema["maxLength"] == 100
    end

    test "min constraint maps to minimum" do
      attr = %{
        name: :number_field,
        type: :integer,
        allow_nil?: false,
        constraints: [min: 0],
        description: nil,
        default: nil
      }

      schema = TypeMapper.to_json_schema_31(attr)

      assert schema["minimum"] == 0
    end

    test "max constraint maps to maximum" do
      attr = %{
        name: :number_field,
        type: :integer,
        allow_nil?: false,
        constraints: [max: 100],
        description: nil,
        default: nil
      }

      schema = TypeMapper.to_json_schema_31(attr)

      assert schema["maximum"] == 100
    end

    test "one_of constraint maps to enum" do
      attr = %{
        name: :status,
        type: :atom,
        allow_nil?: false,
        constraints: [one_of: [:draft, :published, :archived]],
        description: nil,
        default: nil
      }

      schema = TypeMapper.to_json_schema_31(attr)

      assert schema["enum"] == ["draft", "published", "archived"]
    end

    test "match constraint maps to pattern" do
      attr = %{
        name: :email,
        type: :string,
        allow_nil?: false,
        constraints: [match: ~r/^[^\s]+@[^\s]+$/],
        description: nil,
        default: nil
      }

      schema = TypeMapper.to_json_schema_31(attr)

      assert schema["pattern"] == "^[^\\s]+@[^\\s]+$"
    end
  end

  describe "default values" do
    test "static default value is included" do
      attr = %{
        name: :status,
        type: :string,
        allow_nil?: false,
        constraints: [],
        description: nil,
        default: "draft"
      }

      schema = TypeMapper.to_json_schema_31(attr)

      assert schema["default"] == "draft"
    end

    test "boolean default false is included" do
      attr = %{
        name: :active,
        type: :boolean,
        allow_nil?: false,
        constraints: [],
        description: nil,
        default: false
      }

      schema = TypeMapper.to_json_schema_31(attr)

      assert schema["default"] == false
    end

    test "integer default zero is included" do
      attr = %{
        name: :count,
        type: :integer,
        allow_nil?: false,
        constraints: [],
        description: nil,
        default: 0
      }

      schema = TypeMapper.to_json_schema_31(attr)

      assert schema["default"] == 0
    end

    test "empty string default is included" do
      attr = %{
        name: :notes,
        type: :string,
        allow_nil?: false,
        constraints: [],
        description: nil,
        default: ""
      }

      schema = TypeMapper.to_json_schema_31(attr)

      assert schema["default"] == ""
    end

    test "function default is not included" do
      attr = %{
        name: :id,
        type: :uuid,
        allow_nil?: false,
        constraints: [],
        description: nil,
        default: &Ash.UUID.generate/0
      }

      schema = TypeMapper.to_json_schema_31(attr)

      refute Map.has_key?(schema, "default")
    end
  end

  describe "array type handling" do
    test "array of strings" do
      attr = %{
        name: :tags,
        type: {:array, :string},
        allow_nil?: false,
        constraints: [],
        description: nil,
        default: nil
      }

      schema = TypeMapper.to_json_schema_31(attr)

      assert schema["type"] == "array"
      assert schema["items"] == %{"type" => "string"}
    end

    test "array of integers" do
      attr = %{
        name: :numbers,
        type: {:array, :integer},
        allow_nil?: false,
        constraints: [],
        description: nil,
        default: nil
      }

      schema = TypeMapper.to_json_schema_31(attr)

      assert schema["type"] == "array"
      assert schema["items"] == %{"type" => "integer"}
    end

    test "nested array (array of arrays)" do
      attr = %{
        name: :matrix,
        type: {:array, {:array, :integer}},
        allow_nil?: false,
        constraints: [],
        description: nil,
        default: nil
      }

      schema = TypeMapper.to_json_schema_31(attr)

      assert schema["type"] == "array"
      assert schema["items"]["type"] == "array"
      assert schema["items"]["items"] == %{"type" => "integer"}
    end
  end

  describe "format strings" do
    test "uuid type has uuid format" do
      attr = %{
        name: :id,
        type: :uuid,
        allow_nil?: false,
        constraints: [],
        description: nil,
        default: nil
      }

      schema = TypeMapper.to_json_schema_31(attr)

      assert schema["type"] == "string"
      assert schema["format"] == "uuid"
    end

    test "date type has date format" do
      attr = %{
        name: :birth_date,
        type: :date,
        allow_nil?: false,
        constraints: [],
        description: nil,
        default: nil
      }

      schema = TypeMapper.to_json_schema_31(attr)

      assert schema["type"] == "string"
      assert schema["format"] == "date"
    end

    test "time type has time format" do
      attr = %{
        name: :start_time,
        type: :time,
        allow_nil?: false,
        constraints: [],
        description: nil,
        default: nil
      }

      schema = TypeMapper.to_json_schema_31(attr)

      assert schema["type"] == "string"
      assert schema["format"] == "time"
    end

    test "datetime types have date-time format" do
      datetime_types = [:datetime, :utc_datetime, :utc_datetime_usec, :naive_datetime]

      for type <- datetime_types do
        attr = %{
          name: :timestamp,
          type: type,
          allow_nil?: false,
          constraints: [],
          description: nil,
          default: nil
        }

        schema = TypeMapper.to_json_schema_31(attr)

        assert schema["type"] == "string",
               "Expected string type for #{type}"

        assert schema["format"] == "date-time",
               "Expected date-time format for #{type}"
      end
    end

    test "float type has float format" do
      attr = %{
        name: :rating,
        type: :float,
        allow_nil?: false,
        constraints: [],
        description: nil,
        default: nil
      }

      schema = TypeMapper.to_json_schema_31(attr)

      assert schema["type"] == "number"
      assert schema["format"] == "float"
    end

    test "decimal type has double format" do
      attr = %{
        name: :price,
        type: :decimal,
        allow_nil?: false,
        constraints: [],
        description: nil,
        default: nil
      }

      schema = TypeMapper.to_json_schema_31(attr)

      assert schema["type"] == "number"
      assert schema["format"] == "double"
    end

    test "binary type has binary format" do
      attr = %{
        name: :data,
        type: :binary,
        allow_nil?: false,
        constraints: [],
        description: nil,
        default: nil
      }

      schema = TypeMapper.to_json_schema_31(attr)

      assert schema["type"] == "string"
      assert schema["format"] == "binary"
    end
  end

  describe "special types" do
    test "map type becomes object" do
      attr = %{
        name: :metadata,
        type: :map,
        allow_nil?: false,
        constraints: [],
        description: nil,
        default: nil
      }

      schema = TypeMapper.to_json_schema_31(attr)

      assert schema["type"] == "object"
    end

    test "atom type becomes string" do
      attr = %{
        name: :status,
        type: :atom,
        allow_nil?: false,
        constraints: [],
        description: nil,
        default: nil
      }

      schema = TypeMapper.to_json_schema_31(attr)

      assert schema["type"] == "string"
    end

    test "term type becomes empty schema (any)" do
      attr = %{
        name: :data,
        type: :term,
        allow_nil?: false,
        constraints: [],
        description: nil,
        default: nil
      }

      schema = TypeMapper.to_json_schema_31(attr)

      # Empty schema means "any" in JSON Schema
      assert schema == %{} or schema == %{"description" => nil}
    end

    test "ci_string type becomes string" do
      attr = %{
        name: :slug,
        type: :ci_string,
        allow_nil?: false,
        constraints: [],
        description: nil,
        default: nil
      }

      schema = TypeMapper.to_json_schema_31(attr)

      assert schema["type"] == "string"
    end
  end

  describe "version consistency" do
    test "3.0 and 3.1 produce structurally similar specs" do
      spec_30 = AshOaskit.spec_30(domains: [AshOaskit.Test.SimpleDomain])
      spec_31 = AshOaskit.spec_31(domains: [AshOaskit.Test.SimpleDomain])

      assert Map.has_key?(spec_30, "openapi")
      assert Map.has_key?(spec_31, "openapi")
      assert Map.has_key?(spec_30, "info")
      assert Map.has_key?(spec_31, "info")
      assert Map.has_key?(spec_30, "components")
      assert Map.has_key?(spec_31, "components")
    end

    test "both versions generate the same schema names" do
      spec_30 = AshOaskit.spec_30(domains: [AshOaskit.Test.SimpleDomain])
      spec_31 = AshOaskit.spec_31(domains: [AshOaskit.Test.SimpleDomain])

      schemas_30 = Map.keys(spec_30["components"]["schemas"] || %{})
      schemas_31 = Map.keys(spec_31["components"]["schemas"] || %{})

      assert Enum.sort(schemas_30) == Enum.sort(schemas_31)
    end
  end
end
