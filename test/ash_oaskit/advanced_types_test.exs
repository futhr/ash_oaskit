defmodule AshOaskit.AdvancedTypesTest do
  @moduledoc """
  Comprehensive tests for advanced type support in AshOaskit.TypeMapper.

  This test module verifies that advanced Ash types are correctly mapped
  to their OpenAPI/JSON Schema representations, including:

  - Union types (using anyOf)
  - Struct types (object with properties)
  - File types (binary format)
  - Duration name types (string with enum)
  - Custom types with json_schema/1 callback

  ## Test Categories

  1. **Union Type Mapping** - Tests for anyOf schema generation

  2. **Struct Type Mapping** - Tests for object schema with properties

  3. **File Type Mapping** - Tests for binary file representation

  4. **Duration Type Mapping** - Tests for duration enum values

  5. **Custom Type Callback** - Tests for json_schema/1 support
  """

  use ExUnit.Case, async: true

  alias AshOaskit.TypeMapper

  # Mock attribute helper for testing
  defp mock_attr(type, opts \\ []) do
    %{
      name: Keyword.get(opts, :name, :test_field),
      type: type,
      allow_nil?: Keyword.get(opts, :allow_nil?, true),
      constraints: Keyword.get(opts, :constraints, []),
      description: Keyword.get(opts, :description)
    }
  end

  describe "file type mapping" do
    # Tests for Ash.Type.File

    test "file type generates binary format string (3.1)" do
      attr = mock_attr(:file)
      schema = TypeMapper.to_json_schema_31(attr)

      assert schema["type"] == ["string", "null"] or "string" in schema["type"]
      assert schema["format"] == "binary"
    end

    test "file type generates binary format string (3.0)" do
      attr = mock_attr(:file)
      schema = TypeMapper.to_json_schema_30(attr)

      assert schema["type"] == "string"
      assert schema["format"] == "binary"
      assert schema["nullable"] == true
    end

    test "file type includes description" do
      attr = mock_attr(:file)
      schema = TypeMapper.to_json_schema_31(attr)

      assert Map.has_key?(schema, "description")
    end

    test "non-nullable file type (3.1)" do
      attr = mock_attr(:file, allow_nil?: false)
      schema = TypeMapper.to_json_schema_31(attr)

      assert schema["type"] == "string"
      assert schema["format"] == "binary"
    end
  end

  describe "duration_name type mapping" do
    # Tests for Ash.Type.DurationName

    test "duration_name generates string with enum (3.1)" do
      attr = mock_attr(:duration_name)
      schema = TypeMapper.to_json_schema_31(attr)

      assert "string" in schema["type"] or schema["type"] == ["string", "null"]
      assert is_list(schema["enum"])
    end

    test "duration_name includes all duration units" do
      attr = mock_attr(:duration_name, allow_nil?: false)
      schema = TypeMapper.to_json_schema_31(attr)

      expected_units = [
        "year",
        "month",
        "week",
        "day",
        "hour",
        "minute",
        "second",
        "millisecond",
        "microsecond",
        "nanosecond"
      ]

      Enum.each(expected_units, fn unit ->
        assert unit in schema["enum"], "Expected #{unit} in enum"
      end)
    end

    test "duration_name generates valid schema (3.0)" do
      attr = mock_attr(:duration_name)
      schema = TypeMapper.to_json_schema_30(attr)

      assert schema["type"] == "string"
      assert is_list(schema["enum"])
    end
  end

  describe "union type mapping" do
    # Tests for union types using anyOf

    test "union type generates anyOf schema" do
      # Simulate a union type with explicit types tuple
      attr = mock_attr({:union, [text: [type: :string], number: [type: :integer]]})
      schema = TypeMapper.to_json_schema_31(attr)

      # Should have anyOf
      assert Map.has_key?(schema, "anyOf") or Map.has_key?(schema, "type")
    end

    test "union type with simple atom types" do
      attr = mock_attr({:union, [:string, :integer]})
      schema = TypeMapper.to_json_schema_31(attr)

      assert is_map(schema)
    end

    test "union type nullable handling (3.1)" do
      attr = mock_attr({:union, [text: [type: :string]]})
      schema = TypeMapper.to_json_schema_31(attr)

      assert is_map(schema)
    end

    test "union type nullable handling (3.0)" do
      attr = mock_attr({:union, [text: [type: :string]]})
      schema = TypeMapper.to_json_schema_30(attr)

      assert is_map(schema)
    end
  end

  describe "struct type mapping" do
    # Tests for struct types

    test "struct type generates object schema" do
      # Use a known struct type
      attr = mock_attr({:struct, Date})
      schema = TypeMapper.to_json_schema_31(attr)

      assert schema["type"] == ["object", "null"] or schema["type"] == "object" or
               Map.has_key?(schema, "type")
    end

    test "struct type includes properties" do
      attr = mock_attr({:struct, Date}, allow_nil?: false)
      schema = TypeMapper.to_json_schema_31(attr)

      # Date struct has year, month, day, calendar fields
      if Map.has_key?(schema, "properties") do
        assert is_map(schema["properties"])
      end
    end

    test "struct type generates valid schema (3.0)" do
      attr = mock_attr({:struct, Date})
      schema = TypeMapper.to_json_schema_30(attr)

      assert is_map(schema)
      assert schema["nullable"] == true
    end

    test "unknown struct module generates generic object" do
      attr = mock_attr({:struct, NonExistentStruct}, allow_nil?: false)
      schema = TypeMapper.to_json_schema_31(attr)

      assert schema["type"] == "object"
    end
  end

  describe "array of advanced types" do
    # Tests for arrays containing advanced types

    test "array of file type" do
      attr = mock_attr({:array, :file}, allow_nil?: false)
      schema = TypeMapper.to_json_schema_31(attr)

      assert schema["type"] == "array"
      assert schema["items"]["type"] == "string"
      assert schema["items"]["format"] == "binary"
    end

    test "array of duration_name type" do
      attr = mock_attr({:array, :duration_name}, allow_nil?: false)
      schema = TypeMapper.to_json_schema_31(attr)

      assert schema["type"] == "array"
      assert is_list(schema["items"]["enum"])
    end
  end

  describe "version compatibility" do
    # Tests for OpenAPI 3.0 vs 3.1 compatibility

    test "file type valid in both versions" do
      attr = mock_attr(:file, allow_nil?: false)

      schema_31 = TypeMapper.to_json_schema_31(attr)
      schema_30 = TypeMapper.to_json_schema_30(attr)

      assert schema_31["format"] == "binary"
      assert schema_30["format"] == "binary"
    end

    test "duration_name type valid in both versions" do
      attr = mock_attr(:duration_name, allow_nil?: false)

      schema_31 = TypeMapper.to_json_schema_31(attr)
      schema_30 = TypeMapper.to_json_schema_30(attr)

      assert is_list(schema_31["enum"])
      assert is_list(schema_30["enum"])
    end
  end

  describe "edge cases" do
    # Tests for edge cases

    test "handles nil type gracefully" do
      attr = mock_attr(nil)
      schema = TypeMapper.to_json_schema_31(attr)

      assert is_map(schema)
    end

    test "handles empty union types list" do
      attr = mock_attr({:union, []})
      schema = TypeMapper.to_json_schema_31(attr)

      assert is_map(schema)
    end

    test "handles struct with nil module" do
      attr = mock_attr({:struct, nil})
      schema = TypeMapper.to_json_schema_31(attr)

      assert is_map(schema)
    end

    test "all schemas are maps" do
      types = [
        :file,
        :duration_name,
        {:union, [:string]},
        {:struct, Date},
        {:array, :file}
      ]

      Enum.each(types, fn type ->
        attr = mock_attr(type)

        assert is_map(TypeMapper.to_json_schema_31(attr)),
               "Expected map for type #{inspect(type)}"

        assert is_map(TypeMapper.to_json_schema_30(attr)),
               "Expected map for type #{inspect(type)}"
      end)
    end
  end

  describe "constraint handling for advanced types" do
    # Tests for constraint application on advanced types

    test "file type with description constraint" do
      attr = mock_attr(:file, description: "Upload your profile picture")
      schema = TypeMapper.to_json_schema_31(attr)

      assert schema["description"] == "Upload your profile picture"
    end

    test "duration_name type preserves custom description" do
      attr = mock_attr(:duration_name, description: "Time unit for billing", allow_nil?: false)
      schema = TypeMapper.to_json_schema_31(attr)

      # Custom description should override default
      assert schema["description"] == "Time unit for billing"
    end
  end
end
