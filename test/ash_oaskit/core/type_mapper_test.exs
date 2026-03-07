defmodule AshOaskit.TypeMapperTest do
  @moduledoc """
  Tests for the AshOaskit.TypeMapper module.

  This module tests the conversion of Ash types to JSON Schema types,
  covering both OpenAPI 3.0 and 3.1 specifications.

  ## Test Categories

  The tests are organized into the following categories:

  - **Basic Type Mapping** - Tests for simple types (string, integer, etc.)
  - **Nullable Handling** - Tests for 3.0 vs 3.1 nullable differences
  - **Constraints** - Tests for min/max, pattern, enum constraints
  - **Complex Types** - Tests for arrays, unions, structs, embedded
  - **Ash.Type Modules** - Tests for both atom and module type formats
  - **Custom Types** - Tests for types with json_schema/1 callback

  ## Type Conversion Flow

  ```
  Ash Attribute
       │
       ▼
  ┌─────────────┐
  │normalize_type ← Handles atoms, modules, tuples
  └──────┬──────┘
         │
         ▼
  ┌─────────────┐
  │base_schema  │ ← Maps to JSON Schema type/format
  └──────┬──────┘
         │
         ▼
  ┌─────────────┐
  │nullable?    │ ← 3.1: type array, 3.0: nullable flag
  └──────┬──────┘
         │
         ▼
  ┌─────────────┐
  │constraints  │ ← minLength, maximum, pattern, enum
  └──────┬──────┘
         │
         ▼
   JSON Schema
  ```
  """

  use ExUnit.Case, async: true

  import ExUnit.CaptureLog
  doctest AshOaskit.TypeMapper

  alias AshOaskit.TypeMapper

  describe "to_json_schema_31/1" do
    test "maps string type" do
      attr = %{type: :string, allow_nil?: false}
      assert TypeMapper.to_json_schema_31(attr) == %{"type" => "string"}
    end

    test "maps integer type" do
      attr = %{type: :integer, allow_nil?: false}
      assert TypeMapper.to_json_schema_31(attr) == %{"type" => "integer"}
    end

    test "maps boolean type" do
      attr = %{type: :boolean, allow_nil?: false}
      assert TypeMapper.to_json_schema_31(attr) == %{"type" => "boolean"}
    end

    test "maps uuid type with format" do
      attr = %{type: :uuid, allow_nil?: false}
      assert TypeMapper.to_json_schema_31(attr) == %{"type" => "string", "format" => "uuid"}
    end

    test "maps datetime types with format" do
      for type <- [:datetime, :utc_datetime, :utc_datetime_usec] do
        attr = %{type: type, allow_nil?: false}

        assert TypeMapper.to_json_schema_31(attr) == %{
                 "type" => "string",
                 "format" => "date-time"
               }
      end
    end

    test "maps date type with format" do
      attr = %{type: :date, allow_nil?: false}
      assert TypeMapper.to_json_schema_31(attr) == %{"type" => "string", "format" => "date"}
    end

    test "maps decimal type as number with double format" do
      attr = %{type: :decimal, allow_nil?: false}
      assert TypeMapper.to_json_schema_31(attr) == %{"type" => "number", "format" => "double"}
    end

    test "maps float type as number with float format" do
      attr = %{type: :float, allow_nil?: false}
      assert TypeMapper.to_json_schema_31(attr) == %{"type" => "number", "format" => "float"}
    end

    test "maps array type with items" do
      attr = %{type: {:array, :string}, allow_nil?: false}
      expected = %{"type" => "array", "items" => %{"type" => "string"}}
      assert TypeMapper.to_json_schema_31(attr) == expected
    end

    test "maps map type as object" do
      attr = %{type: :map, allow_nil?: false}
      assert TypeMapper.to_json_schema_31(attr) == %{"type" => "object"}
    end

    test "handles nullable with type array (3.1 style)" do
      attr = %{type: :string, allow_nil?: true}
      assert TypeMapper.to_json_schema_31(attr) == %{"type" => ["string", "null"]}
    end

    test "handles nullable integer with type array" do
      attr = %{type: :integer, allow_nil?: true}
      assert TypeMapper.to_json_schema_31(attr) == %{"type" => ["integer", "null"]}
    end

    test "adds min_length constraint" do
      attr = %{type: :string, allow_nil?: false, constraints: [min_length: 3]}
      result = TypeMapper.to_json_schema_31(attr)
      assert result["minLength"] == 3
    end

    test "adds max_length constraint" do
      attr = %{type: :string, allow_nil?: false, constraints: [max_length: 100]}
      result = TypeMapper.to_json_schema_31(attr)
      assert result["maxLength"] == 100
    end

    test "adds description when present" do
      attr = %{type: :string, allow_nil?: false, description: "User email address"}
      result = TypeMapper.to_json_schema_31(attr)
      assert result["description"] == "User email address"
    end

    test "adds static default value" do
      attr = %{type: :string, allow_nil?: false, default: "pending"}
      result = TypeMapper.to_json_schema_31(attr)
      assert result["default"] == "pending"
    end

    test "skips function default values" do
      attr = %{type: :string, allow_nil?: false, default: fn -> "generated" end}
      result = TypeMapper.to_json_schema_31(attr)
      refute Map.has_key?(result, "default")
    end

    # Additional type tests for coverage
    test "maps ci_string type as string" do
      attr = %{type: :ci_string, allow_nil?: false}
      assert TypeMapper.to_json_schema_31(attr) == %{"type" => "string"}
    end

    test "maps time type with format" do
      attr = %{type: :time, allow_nil?: false}
      assert TypeMapper.to_json_schema_31(attr) == %{"type" => "string", "format" => "time"}
    end

    test "maps naive_datetime type with format" do
      attr = %{type: :naive_datetime, allow_nil?: false}
      assert TypeMapper.to_json_schema_31(attr) == %{"type" => "string", "format" => "date-time"}
    end

    test "maps binary type with format" do
      attr = %{type: :binary, allow_nil?: false}
      assert TypeMapper.to_json_schema_31(attr) == %{"type" => "string", "format" => "binary"}
    end

    test "maps atom type as string" do
      attr = %{type: :atom, allow_nil?: false}
      assert TypeMapper.to_json_schema_31(attr) == %{"type" => "string"}
    end

    test "maps term type as empty schema" do
      attr = %{type: :term, allow_nil?: false}
      assert TypeMapper.to_json_schema_31(attr) == %{}
    end

    test "maps unknown type as string (fallback)" do
      attr = %{type: :unknown_type, allow_nil?: false}
      assert TypeMapper.to_json_schema_31(attr) == %{"type" => "string"}
    end

    # Additional constraint tests
    test "adds min constraint as minimum" do
      attr = %{type: :integer, allow_nil?: false, constraints: [min: 0]}
      result = TypeMapper.to_json_schema_31(attr)
      assert result["minimum"] == 0
    end

    test "adds max constraint as maximum" do
      attr = %{type: :integer, allow_nil?: false, constraints: [max: 100]}
      result = TypeMapper.to_json_schema_31(attr)
      assert result["maximum"] == 100
    end

    test "adds match constraint as pattern" do
      attr = %{type: :string, allow_nil?: false, constraints: [match: ~r/^[a-z]+$/]}
      result = TypeMapper.to_json_schema_31(attr)
      assert result["pattern"] == "^[a-z]+$"
    end

    test "adds one_of constraint as enum with string values" do
      attr = %{type: :atom, allow_nil?: false, constraints: [one_of: [:draft, :published]]}
      result = TypeMapper.to_json_schema_31(attr)
      # Enum values are converted to strings for JSON Schema compatibility
      assert result["enum"] == ["draft", "published"]
    end

    test "ignores unknown constraints" do
      attr = %{type: :string, allow_nil?: false, constraints: [unknown_constraint: "value"]}
      result = TypeMapper.to_json_schema_31(attr)
      assert result == %{"type" => "string"}
    end

    test "combines multiple constraints" do
      attr = %{
        type: :string,
        allow_nil?: false,
        constraints: [min_length: 1, max_length: 100]
      }

      result = TypeMapper.to_json_schema_31(attr)
      assert result["minLength"] == 1
      assert result["maxLength"] == 100
      assert result["type"] == "string"
    end

    test "handles array with nested integer type" do
      attr = %{type: {:array, :integer}, allow_nil?: false}
      expected = %{"type" => "array", "items" => %{"type" => "integer"}}
      assert TypeMapper.to_json_schema_31(attr) == expected
    end

    test "handles nested array type" do
      attr = %{type: {:array, {:array, :string}}, allow_nil?: false}

      expected = %{
        "type" => "array",
        "items" => %{"type" => "array", "items" => %{"type" => "string"}}
      }

      assert TypeMapper.to_json_schema_31(attr) == expected
    end

    test "defaults to allow_nil? true when not specified" do
      attr = %{type: :string}
      result = TypeMapper.to_json_schema_31(attr)
      assert result["type"] == ["string", "null"]
    end

    test "handles default value of false" do
      attr = %{type: :boolean, allow_nil?: false, default: false}
      result = TypeMapper.to_json_schema_31(attr)
      assert result["default"] == false
    end

    test "handles default value of 0" do
      attr = %{type: :integer, allow_nil?: false, default: 0}
      result = TypeMapper.to_json_schema_31(attr)
      assert result["default"] == 0
    end

    test "handles default value of empty string" do
      attr = %{type: :string, allow_nil?: false, default: ""}
      result = TypeMapper.to_json_schema_31(attr)
      assert result["default"] == ""
    end

    test "handles already nullable type array (doesn't duplicate null)" do
      # This tests the make_nullable_31 with type list
      attr = %{type: :string, allow_nil?: true}
      result = TypeMapper.to_json_schema_31(attr)
      # Should only have one "null" in the array
      assert result["type"] == ["string", "null"]
      assert Enum.count(result["type"], &(&1 == "null")) == 1
    end

    test "handles missing constraints key" do
      attr = %{type: :string, allow_nil?: false}
      result = TypeMapper.to_json_schema_31(attr)
      assert result == %{"type" => "string"}
    end

    test "handles nil description" do
      attr = %{type: :string, allow_nil?: false, description: nil}
      result = TypeMapper.to_json_schema_31(attr)
      refute Map.has_key?(result, "description")
    end

    test "handles nil default" do
      attr = %{type: :string, allow_nil?: false, default: nil}
      result = TypeMapper.to_json_schema_31(attr)
      refute Map.has_key?(result, "default")
    end
  end

  describe "to_json_schema_30/1" do
    test "maps string type" do
      attr = %{type: :string, allow_nil?: false}
      assert TypeMapper.to_json_schema_30(attr) == %{"type" => "string"}
    end

    test "handles nullable with nullable flag (3.0 style)" do
      attr = %{type: :string, allow_nil?: true}
      assert TypeMapper.to_json_schema_30(attr) == %{"type" => "string", "nullable" => true}
    end

    test "handles nullable integer with nullable flag" do
      attr = %{type: :integer, allow_nil?: true}
      assert TypeMapper.to_json_schema_30(attr) == %{"type" => "integer", "nullable" => true}
    end

    test "handles nullable uuid with nullable flag" do
      attr = %{type: :uuid, allow_nil?: true}
      expected = %{"type" => "string", "format" => "uuid", "nullable" => true}
      assert TypeMapper.to_json_schema_30(attr) == expected
    end

    # Additional 3.0 specific tests
    test "maps ci_string type as string" do
      attr = %{type: :ci_string, allow_nil?: false}
      assert TypeMapper.to_json_schema_30(attr) == %{"type" => "string"}
    end

    test "maps time type with format" do
      attr = %{type: :time, allow_nil?: false}
      assert TypeMapper.to_json_schema_30(attr) == %{"type" => "string", "format" => "time"}
    end

    test "maps binary type with format" do
      attr = %{type: :binary, allow_nil?: false}
      assert TypeMapper.to_json_schema_30(attr) == %{"type" => "string", "format" => "binary"}
    end

    test "maps atom type as string" do
      attr = %{type: :atom, allow_nil?: false}
      assert TypeMapper.to_json_schema_30(attr) == %{"type" => "string"}
    end

    test "maps term type as empty schema with nullable" do
      attr = %{type: :term, allow_nil?: true}
      assert TypeMapper.to_json_schema_30(attr) == %{"nullable" => true}
    end

    test "adds constraints in 3.0 format" do
      attr = %{
        type: :integer,
        allow_nil?: true,
        constraints: [min: 0, max: 100]
      }

      result = TypeMapper.to_json_schema_30(attr)
      assert result["type"] == "integer"
      assert result["nullable"] == true
      assert result["minimum"] == 0
      assert result["maximum"] == 100
    end
  end

  describe "nullable handling comparison" do
    test "3.1 uses type array, 3.0 uses nullable flag" do
      attr = %{type: :string, allow_nil?: true}

      result_31 = TypeMapper.to_json_schema_31(attr)
      result_30 = TypeMapper.to_json_schema_30(attr)

      # 3.1 style: type array
      assert result_31["type"] == ["string", "null"]
      refute Map.has_key?(result_31, "nullable")

      # 3.0 style: nullable flag
      assert result_30["type"] == "string"
      assert result_30["nullable"] == true
    end
  end

  describe "Ash.Type module atom normalization" do
    # These test the normalize_type/1 function with module atoms (real Ash types)
    test "normalizes Ash.Type.String module" do
      attr = %{type: Ash.Type.String, allow_nil?: false}
      assert TypeMapper.to_json_schema_31(attr) == %{"type" => "string"}
    end

    test "normalizes Ash.Type.Integer module" do
      attr = %{type: Ash.Type.Integer, allow_nil?: false}
      assert TypeMapper.to_json_schema_31(attr) == %{"type" => "integer"}
    end

    test "normalizes Ash.Type.Boolean module" do
      attr = %{type: Ash.Type.Boolean, allow_nil?: false}
      assert TypeMapper.to_json_schema_31(attr) == %{"type" => "boolean"}
    end

    test "normalizes Ash.Type.UUID module" do
      attr = %{type: Ash.Type.UUID, allow_nil?: false}
      assert TypeMapper.to_json_schema_31(attr) == %{"type" => "string", "format" => "uuid"}
    end

    test "normalizes Ash.Type.Date module" do
      attr = %{type: Ash.Type.Date, allow_nil?: false}
      assert TypeMapper.to_json_schema_31(attr) == %{"type" => "string", "format" => "date"}
    end

    test "normalizes Ash.Type.Time module" do
      attr = %{type: Ash.Type.Time, allow_nil?: false}
      assert TypeMapper.to_json_schema_31(attr) == %{"type" => "string", "format" => "time"}
    end

    test "normalizes Ash.Type.DateTime module" do
      attr = %{type: Ash.Type.DateTime, allow_nil?: false}
      assert TypeMapper.to_json_schema_31(attr) == %{"type" => "string", "format" => "date-time"}
    end

    test "normalizes Ash.Type.UtcDatetime module" do
      attr = %{type: Ash.Type.UtcDatetime, allow_nil?: false}
      assert TypeMapper.to_json_schema_31(attr) == %{"type" => "string", "format" => "date-time"}
    end

    test "normalizes Ash.Type.UtcDatetimeUsec module" do
      attr = %{type: Ash.Type.UtcDatetimeUsec, allow_nil?: false}
      assert TypeMapper.to_json_schema_31(attr) == %{"type" => "string", "format" => "date-time"}
    end

    test "normalizes Ash.Type.NaiveDatetime module" do
      attr = %{type: Ash.Type.NaiveDatetime, allow_nil?: false}
      assert TypeMapper.to_json_schema_31(attr) == %{"type" => "string", "format" => "date-time"}
    end

    test "normalizes Ash.Type.Decimal module" do
      attr = %{type: Ash.Type.Decimal, allow_nil?: false}
      assert TypeMapper.to_json_schema_31(attr) == %{"type" => "number", "format" => "double"}
    end

    test "normalizes Ash.Type.Float module" do
      attr = %{type: Ash.Type.Float, allow_nil?: false}
      assert TypeMapper.to_json_schema_31(attr) == %{"type" => "number", "format" => "float"}
    end

    test "normalizes Ash.Type.Binary module" do
      attr = %{type: Ash.Type.Binary, allow_nil?: false}
      assert TypeMapper.to_json_schema_31(attr) == %{"type" => "string", "format" => "binary"}
    end

    test "normalizes Ash.Type.Map module" do
      attr = %{type: Ash.Type.Map, allow_nil?: false}
      assert TypeMapper.to_json_schema_31(attr) == %{"type" => "object"}
    end

    test "normalizes Ash.Type.Atom module" do
      attr = %{type: Ash.Type.Atom, allow_nil?: false}
      assert TypeMapper.to_json_schema_31(attr) == %{"type" => "string"}
    end

    test "normalizes Ash.Type.Term module" do
      attr = %{type: Ash.Type.Term, allow_nil?: false}
      assert TypeMapper.to_json_schema_31(attr) == %{}
    end

    test "normalizes Ash.Type.CiString module" do
      attr = %{type: Ash.Type.CiString, allow_nil?: false}
      assert TypeMapper.to_json_schema_31(attr) == %{"type" => "string"}
    end

    test "normalizes array with Ash.Type module" do
      attr = %{type: {:array, Ash.Type.String}, allow_nil?: false}

      assert TypeMapper.to_json_schema_31(attr) == %{
               "type" => "array",
               "items" => %{"type" => "string"}
             }
    end
  end

  describe "Ash.Type tuple normalization (legacy format)" do
    # These test the normalize_type/1 function with tuple types
    test "normalizes Ash.Type.String tuple" do
      attr = %{type: {Ash.Type.String, []}, allow_nil?: false}
      assert TypeMapper.to_json_schema_31(attr) == %{"type" => "string"}
    end

    test "normalizes Ash.Type.Integer tuple" do
      attr = %{type: {Ash.Type.Integer, []}, allow_nil?: false}
      assert TypeMapper.to_json_schema_31(attr) == %{"type" => "integer"}
    end

    test "normalizes Ash.Type.Boolean tuple" do
      attr = %{type: {Ash.Type.Boolean, []}, allow_nil?: false}
      assert TypeMapper.to_json_schema_31(attr) == %{"type" => "boolean"}
    end

    test "normalizes Ash.Type.UUID tuple" do
      attr = %{type: {Ash.Type.UUID, []}, allow_nil?: false}
      assert TypeMapper.to_json_schema_31(attr) == %{"type" => "string", "format" => "uuid"}
    end

    test "normalizes Ash.Type.Date tuple" do
      attr = %{type: {Ash.Type.Date, []}, allow_nil?: false}
      assert TypeMapper.to_json_schema_31(attr) == %{"type" => "string", "format" => "date"}
    end

    test "normalizes Ash.Type.Time tuple" do
      attr = %{type: {Ash.Type.Time, []}, allow_nil?: false}
      assert TypeMapper.to_json_schema_31(attr) == %{"type" => "string", "format" => "time"}
    end

    test "normalizes Ash.Type.DateTime tuple" do
      attr = %{type: {Ash.Type.DateTime, []}, allow_nil?: false}
      assert TypeMapper.to_json_schema_31(attr) == %{"type" => "string", "format" => "date-time"}
    end

    test "normalizes Ash.Type.UtcDatetime tuple" do
      attr = %{type: {Ash.Type.UtcDatetime, []}, allow_nil?: false}
      assert TypeMapper.to_json_schema_31(attr) == %{"type" => "string", "format" => "date-time"}
    end

    test "normalizes Ash.Type.UtcDatetimeUsec tuple" do
      attr = %{type: {Ash.Type.UtcDatetimeUsec, []}, allow_nil?: false}
      assert TypeMapper.to_json_schema_31(attr) == %{"type" => "string", "format" => "date-time"}
    end

    test "normalizes Ash.Type.NaiveDatetime tuple" do
      attr = %{type: {Ash.Type.NaiveDatetime, []}, allow_nil?: false}
      assert TypeMapper.to_json_schema_31(attr) == %{"type" => "string", "format" => "date-time"}
    end

    test "normalizes Ash.Type.Decimal tuple" do
      attr = %{type: {Ash.Type.Decimal, []}, allow_nil?: false}
      assert TypeMapper.to_json_schema_31(attr) == %{"type" => "number", "format" => "double"}
    end

    test "normalizes Ash.Type.Float tuple" do
      attr = %{type: {Ash.Type.Float, []}, allow_nil?: false}
      assert TypeMapper.to_json_schema_31(attr) == %{"type" => "number", "format" => "float"}
    end

    test "normalizes Ash.Type.Binary tuple" do
      attr = %{type: {Ash.Type.Binary, []}, allow_nil?: false}
      assert TypeMapper.to_json_schema_31(attr) == %{"type" => "string", "format" => "binary"}
    end

    test "normalizes Ash.Type.Map tuple" do
      attr = %{type: {Ash.Type.Map, []}, allow_nil?: false}
      assert TypeMapper.to_json_schema_31(attr) == %{"type" => "object"}
    end

    test "normalizes Ash.Type.Atom tuple" do
      attr = %{type: {Ash.Type.Atom, []}, allow_nil?: false}
      assert TypeMapper.to_json_schema_31(attr) == %{"type" => "string"}
    end

    test "normalizes Ash.Type.Term tuple" do
      attr = %{type: {Ash.Type.Term, []}, allow_nil?: false}
      assert TypeMapper.to_json_schema_31(attr) == %{}
    end

    test "normalizes Ash.Type.CiString tuple" do
      attr = %{type: {Ash.Type.CiString, []}, allow_nil?: false}
      assert TypeMapper.to_json_schema_31(attr) == %{"type" => "string"}
    end

    test "normalizes unknown Ash.Type tuple as string" do
      attr = %{type: {Ash.Type.Unknown, []}, allow_nil?: false}
      assert TypeMapper.to_json_schema_31(attr) == %{"type" => "string"}
    end
  end

  describe "file and duration_name types" do
    test "maps file type for 3.1" do
      attr = %{type: :file, allow_nil?: false}
      result = TypeMapper.to_json_schema_31(attr)
      assert result["type"] == "string"
      assert result["format"] == "binary"
      assert result["description"] == "File content (binary)"
    end

    test "maps duration_name type for 3.1" do
      attr = %{type: :duration_name, allow_nil?: false}
      result = TypeMapper.to_json_schema_31(attr)
      assert result["type"] == "string"
      assert is_list(result["enum"])
      assert "year" in result["enum"]
      assert "second" in result["enum"]
      assert result["description"] == "Duration unit name"
    end

    test "maps Ash.Type.File module" do
      attr = %{type: Ash.Type.File, allow_nil?: false}
      result = TypeMapper.to_json_schema_31(attr)
      assert result["type"] == "string"
      assert result["format"] == "binary"
    end

    test "maps Ash.Type.DurationName module" do
      attr = %{type: Ash.Type.DurationName, allow_nil?: false}
      result = TypeMapper.to_json_schema_31(attr)
      assert result["type"] == "string"
      assert is_list(result["enum"])
    end
  end

  describe "union types" do
    test "maps union type with named types to anyOf schema" do
      attr = %{
        type:
          {:union,
           [
             string_value: [type: :string],
             integer_value: [type: :integer]
           ]},
        allow_nil?: false
      }

      result = TypeMapper.to_json_schema_31(attr)
      assert Map.has_key?(result, "anyOf")
      any_of = result["anyOf"]
      assert length(any_of) == 2

      # Check that named union types have titles
      string_schema = Enum.find(any_of, &(&1["type"] == "string"))
      assert string_schema["title"] == "string_value"

      integer_schema = Enum.find(any_of, &(&1["type"] == "integer"))
      assert integer_schema["title"] == "integer_value"
    end

    test "maps union type with atom types to anyOf schema" do
      attr = %{type: {:union, [:string, :integer]}, allow_nil?: false}
      result = TypeMapper.to_json_schema_31(attr)
      assert Map.has_key?(result, "anyOf")
      any_of = result["anyOf"]
      assert length(any_of) == 2
      types = Enum.map(any_of, & &1["type"])
      assert "string" in types
      assert "integer" in types
    end

    test "maps empty union type to empty schema" do
      attr = %{type: {:union, "not_a_list"}, allow_nil?: false}
      result = TypeMapper.to_json_schema_31(attr)
      assert result == %{}
    end
  end

  describe "struct types" do
    test "maps struct type to object schema with properties" do
      # Using a real struct module that exists
      attr = %{type: {:struct, Date}, allow_nil?: false}
      result = TypeMapper.to_json_schema_31(attr)
      assert result["type"] == "object"
      assert Map.has_key?(result, "properties")
      # Date struct has year, month, day, calendar fields
      assert Map.has_key?(result["properties"], "year")
      assert Map.has_key?(result["properties"], "month")
      assert Map.has_key?(result["properties"], "day")
      assert result["description"] =~ "Struct of type"
    end

    test "maps struct type with non-loaded module to object" do
      attr = %{type: {:struct, NonExistentModule}, allow_nil?: false}
      result = TypeMapper.to_json_schema_31(attr)
      assert result == %{"type" => "object"}
    end

    test "maps struct with non-atom to object" do
      attr = %{type: {:struct, "not_a_module"}, allow_nil?: false}
      result = TypeMapper.to_json_schema_31(attr)
      assert result == %{"type" => "object"}
    end

    test "maps struct type with module that doesn't define __struct__" do
      # Kernel is loaded but doesn't have __struct__
      attr = %{type: {:struct, Kernel}, allow_nil?: false}
      result = TypeMapper.to_json_schema_31(attr)
      # Should fall back to basic object
      assert result["type"] == "object"
    end
  end

  describe "custom types with json_schema callback" do
    defmodule CustomTypeWithJsonSchema do
      @moduledoc false
      @spec json_schema(keyword()) :: map()
      def json_schema(_) do
        %{"type" => "string", "format" => "custom-format", "x-custom" => true}
      end
    end

    defmodule CustomTypeWithFailingJsonSchema do
      @moduledoc false
      @spec json_schema(keyword()) :: no_return()
      def json_schema(_) do
        raise "intentional error"
      end
    end

    defmodule CustomTypeWithObjectSchema do
      @moduledoc false
      @spec json_schema(keyword()) :: map()
      def json_schema(_) do
        %{"type" => "object", "properties" => %{"key" => %{"type" => "string"}}}
      end
    end

    test "maps custom type with json_schema callback" do
      attr = %{type: CustomTypeWithJsonSchema, allow_nil?: false}
      result = TypeMapper.to_json_schema_31(attr)
      assert result["type"] == "string"
      assert result["format"] == "custom-format"
      assert result["x-custom"] == true
    end

    test "maps custom type with object json_schema callback" do
      attr = %{type: CustomTypeWithObjectSchema, allow_nil?: false}
      result = TypeMapper.to_json_schema_31(attr)
      assert result["type"] == "object"
      assert result["properties"]["key"]["type"] == "string"
    end

    test "maps custom type with failing json_schema callback to string" do
      attr = %{type: CustomTypeWithFailingJsonSchema, allow_nil?: false}

      {result, log} =
        with_log(fn ->
          TypeMapper.to_json_schema_31(attr)
        end)

      # Should fall back to string when json_schema raises
      assert result["type"] == "string"
      assert log =~ "Failed to get json_schema"
    end
  end

  describe "union type modules (Ash.Type.NewType)" do
    defmodule UnionTypeModule do
      @moduledoc false
      @spec constraints() :: keyword()
      def constraints do
        [
          types: [
            text: [type: :string],
            number: [type: :integer]
          ]
        ]
      end
    end

    defmodule NonUnionTypeModule do
      @moduledoc false
      @spec constraints() :: keyword()
      def constraints do
        [min: 0, max: 100]
      end
    end

    defmodule FailingConstraintsModule do
      @moduledoc false
      @spec constraints() :: no_return()
      def constraints do
        raise "intentional error"
      end
    end

    test "maps union type module to anyOf schema" do
      attr = %{type: UnionTypeModule, allow_nil?: false}
      result = TypeMapper.to_json_schema_31(attr)
      assert Map.has_key?(result, "anyOf")
      any_of = result["anyOf"]
      assert length(any_of) == 2
    end

    test "maps non-union type module with constraints to string" do
      attr = %{type: NonUnionTypeModule, allow_nil?: false}
      result = TypeMapper.to_json_schema_31(attr)
      # Non-union constraint types fall back to string
      assert result["type"] == "string"
    end

    test "raises when module constraints callback fails" do
      attr = %{type: FailingConstraintsModule, allow_nil?: false}

      assert_raise RuntimeError, "intentional error", fn ->
        TypeMapper.to_json_schema_31(attr)
      end
    end
  end

  describe "normalize_type edge cases" do
    test "handles non-atom, non-tuple type (fallback)" do
      attr = %{type: "string_as_binary", allow_nil?: false}
      result = TypeMapper.to_json_schema_31(attr)
      # Binary strings fall back to :string
      assert result["type"] == "string"
    end

    test "handles nil type (fallback)" do
      attr = %{type: nil, allow_nil?: false}
      result = TypeMapper.to_json_schema_31(attr)
      assert result["type"] == "string"
    end

    test "handles list type (fallback)" do
      attr = %{type: [:string, :integer], allow_nil?: false}
      result = TypeMapper.to_json_schema_31(attr)
      assert result["type"] == "string"
    end

    test "handles module that is not an Ash resource" do
      # GenServer is a module but not an Ash resource
      attr = %{type: GenServer, allow_nil?: false}
      result = TypeMapper.to_json_schema_31(attr)
      assert result["type"] == "string"
    end
  end

  describe "make_nullable_31 edge cases" do
    test "doesn't duplicate null in already nullable type array" do
      # Create an attribute that would result in a type array
      # then make it nullable again
      attr = %{type: :string, allow_nil?: true}
      result = TypeMapper.to_json_schema_31(attr)
      # Type should be ["string", "null"]
      assert result["type"] == ["string", "null"]
      # null should appear only once
      assert Enum.count(result["type"], &(&1 == "null")) == 1
    end

    test "handles schema without type key" do
      # term type produces empty schema {}
      attr = %{type: :term, allow_nil?: true}
      result = TypeMapper.to_json_schema_31(attr)
      # Empty schema with no type key should remain unchanged
      assert result == %{}
    end
  end

  describe "constraint handling edge cases" do
    test "handles Spark.Regex cached pattern constraint" do
      # Spark stores compiled regex as {Spark.Regex, :cache, [pattern, opts]}
      spark_regex = {Spark.Regex, :cache, ["^[a-z]+$", []]}
      attr = %{type: :string, allow_nil?: false, constraints: [match: spark_regex]}
      result = TypeMapper.to_json_schema_31(attr)
      assert result["pattern"] == "^[a-z]+$"
    end

    test "handles empty constraints list" do
      attr = %{type: :string, allow_nil?: false, constraints: []}
      result = TypeMapper.to_json_schema_31(attr)
      assert result == %{"type" => "string"}
    end
  end

  describe "description handling" do
    test "ignores non-string description" do
      attr = %{type: :string, allow_nil?: false, description: 123}
      result = TypeMapper.to_json_schema_31(attr)
      refute Map.has_key?(result, "description")
    end

    test "ignores atom description" do
      attr = %{type: :string, allow_nil?: false, description: :some_atom}
      result = TypeMapper.to_json_schema_31(attr)
      refute Map.has_key?(result, "description")
    end
  end

  describe "complex_type_schema fallback" do
    test "unknown tuple type falls back to string" do
      attr = %{type: {:unknown_complex, "some_data"}, allow_nil?: false}
      result = TypeMapper.to_json_schema_31(attr)
      assert result["type"] == "string"
    end

    test "three-element tuple falls back to string" do
      attr = %{type: {:foo, :bar, :baz}, allow_nil?: false}
      result = TypeMapper.to_json_schema_31(attr)
      assert result["type"] == "string"
    end

    test "custom type with json_schema/1 callback uses the returned schema" do
      # Types with a json_schema/1 callback go through normalize_complex_type
      # which wraps them as {:custom, schema} for complex_type_schema
      attr = %{type: AshOaskit.Test.PhoneType, allow_nil?: false}
      result = TypeMapper.to_json_schema_31(attr)
      assert result["type"] == "string"
      assert result["format"] == "phone"
    end

    test "custom type with json_schema/1 callback and nullable" do
      attr = %{type: AshOaskit.Test.PhoneType, allow_nil?: true}
      result = TypeMapper.to_json_schema_31(attr)
      assert result["type"] == ["string", "null"]
      assert result["format"] == "phone"
    end
  end

  describe "number constraint parsing" do
    test "handles string integer minimum constraint" do
      attr = %{type: :integer, allow_nil?: false, constraints: [min: "10"]}
      result = TypeMapper.to_json_schema_31(attr)
      assert result["minimum"] == 10
    end

    test "handles string float minimum constraint" do
      attr = %{type: :float, allow_nil?: false, constraints: [min: "3.14"]}
      result = TypeMapper.to_json_schema_31(attr)
      assert result["minimum"] == 3.14
    end

    test "handles unparseable string constraint" do
      attr = %{type: :integer, allow_nil?: false, constraints: [min: "not_a_number"]}
      result = TypeMapper.to_json_schema_31(attr)
      assert result["minimum"] == "not_a_number"
    end

    test "handles Decimal constraint" do
      attr = %{type: :decimal, allow_nil?: false, constraints: [min: Decimal.new("1.5")]}
      result = TypeMapper.to_json_schema_31(attr)
      assert result["minimum"] == 1.5
    end

    test "handles non-numeric constraint value" do
      attr = %{type: :integer, allow_nil?: false, constraints: [min: :infinity]}
      result = TypeMapper.to_json_schema_31(attr)
      assert result["minimum"] == :infinity
    end
  end

  describe "normalize_type fallback" do
    test "non-atom non-tuple type falls back to string" do
      attr = %{type: 42, allow_nil?: false}
      result = TypeMapper.to_json_schema_31(attr)
      assert result["type"] == "string"
    end
  end

  describe "struct type handling" do
    test "handles loaded struct module" do
      attr = %{type: {:struct, URI}, allow_nil?: false}
      result = TypeMapper.to_json_schema_31(attr)
      assert result["type"] == "object"
      assert is_map(result["properties"])
    end

    test "handles non-loaded struct module" do
      attr = %{type: {:struct, NonExistent.Module}, allow_nil?: false}
      result = TypeMapper.to_json_schema_31(attr)
      assert result["type"] == "object"
    end

    test "handles non-atom struct argument" do
      attr = %{type: {:struct, "not_a_module"}, allow_nil?: false}
      result = TypeMapper.to_json_schema_31(attr)
      assert result["type"] == "object"
    end
  end

  describe "default value handling" do
    test "skips function defaults" do
      attr = %{type: :string, allow_nil?: false, default: &String.upcase/1}
      result = TypeMapper.to_json_schema_31(attr)
      refute Map.has_key?(result, "default")
    end

    test "skips nil defaults" do
      attr = %{type: :string, allow_nil?: false, default: nil}
      result = TypeMapper.to_json_schema_31(attr)
      refute Map.has_key?(result, "default")
    end

    test "includes static defaults" do
      attr = %{type: :string, allow_nil?: false, default: "hello"}
      result = TypeMapper.to_json_schema_31(attr)
      assert result["default"] == "hello"
    end
  end

  describe "custom type json_schema/1 in 3.0 mode" do
    defmodule EmailType do
      @moduledoc false
      @spec json_schema(keyword()) :: map()
      def json_schema(_), do: %{"type" => "string", "format" => "email"}
    end

    test "resolves custom type via json_schema/1 in 3.0 mode with nullable" do
      attr = %{type: EmailType, allow_nil?: true}
      result = TypeMapper.to_json_schema_30(attr)
      assert result["format"] == "email"
      assert result["nullable"] == true
    end
  end

  describe "struct type introspection failure" do
    defmodule BrokenStruct do
      @moduledoc false
      @spec __struct__() :: no_return()
      def __struct__, do: raise("boom")
    end

    test "raises when struct introspection fails" do
      attr = %{type: {:struct, BrokenStruct}, allow_nil?: false}

      assert_raise RuntimeError, "boom", fn ->
        TypeMapper.to_json_schema_31(attr)
      end
    end
  end
end
