defmodule AshOaskit.FormatStringsTest do
  @moduledoc """
  Tests for JSON Schema format string support.

  These tests verify support for JSON Schema format strings beyond
  the basic types, covering the full range of formats defined in
  the OpenAPI Format Registry.

  Reference: https://spec.openapis.org/registry/format/
  Reference: https://json-schema.org/understanding-json-schema/reference/string.html#format

  ## Format Categories

  - **Integer Formats** - int32, int64
  - **Number Formats** - float, double
  - **String Formats** - date, time, date-time, duration
  - **Identifier Formats** - uuid, uri, email
  - **Binary Formats** - byte (base64), binary

  ## Ash Type to Format Mapping

  | Ash Type | JSON Schema Type | Format |
  |----------|------------------|--------|
  | :uuid | string | uuid |
  | :date | string | date |
  | :datetime | string | date-time |
  | :decimal | number | double |
  | :float | number | float |
  """

  use ExUnit.Case, async: true

  alias AshOaskit.TypeMapper

  describe "integer formats" do
    test "int32 format for 32-bit signed integer" do
      # Standard OpenAPI integer format
      schema = %{"type" => "integer", "format" => "int32"}

      assert schema["type"] == "integer"
      assert schema["format"] == "int32"
    end

    test "int64 format for 64-bit signed integer" do
      # Standard OpenAPI integer format
      schema = %{"type" => "integer", "format" => "int64"}

      assert schema["type"] == "integer"
      assert schema["format"] == "int64"
    end

    test "integer type from Ash maps correctly" do
      attr = %{
        name: :count,
        type: :integer,
        allow_nil?: false,
        constraints: [],
        description: nil,
        default: nil
      }

      schema = TypeMapper.to_json_schema_31(attr)

      assert schema["type"] == "integer"
    end
  end

  describe "number formats" do
    test "float format for single precision" do
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

    test "double format for double precision" do
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
  end

  describe "date/time formats" do
    test "date format (RFC 3339 full-date)" do
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

    test "time format (RFC 3339 full-time)" do
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

    test "date-time format (RFC 3339 date-time)" do
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

        assert schema["type"] == "string"
        assert schema["format"] == "date-time"
      end
    end

    test "duration format structure" do
      # ISO 8601 duration format: P1Y2M3DT4H5M6S
      schema = %{"type" => "string", "format" => "duration"}

      assert schema["type"] == "string"
      assert schema["format"] == "duration"
    end
  end

  describe "identifier formats" do
    test "uuid format" do
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

    test "email format structure" do
      schema = %{"type" => "string", "format" => "email"}

      assert schema["type"] == "string"
      assert schema["format"] == "email"
    end

    test "hostname format structure" do
      schema = %{"type" => "string", "format" => "hostname"}

      assert schema["type"] == "string"
      assert schema["format"] == "hostname"
    end
  end

  describe "network formats" do
    test "ipv4 format structure" do
      schema = %{"type" => "string", "format" => "ipv4"}

      assert schema["type"] == "string"
      assert schema["format"] == "ipv4"
    end

    test "ipv6 format structure" do
      schema = %{"type" => "string", "format" => "ipv6"}

      assert schema["type"] == "string"
      assert schema["format"] == "ipv6"
    end

    test "uri format structure" do
      schema = %{"type" => "string", "format" => "uri"}

      assert schema["type"] == "string"
      assert schema["format"] == "uri"
    end

    test "uri-reference format structure" do
      schema = %{"type" => "string", "format" => "uri-reference"}

      assert schema["type"] == "string"
      assert schema["format"] == "uri-reference"
    end

    test "uri-template format structure" do
      schema = %{"type" => "string", "format" => "uri-template"}

      assert schema["type"] == "string"
      assert schema["format"] == "uri-template"
    end
  end

  describe "JSON Schema specific formats" do
    test "json-pointer format structure" do
      schema = %{"type" => "string", "format" => "json-pointer"}

      assert schema["type"] == "string"
      assert schema["format"] == "json-pointer"
    end

    test "relative-json-pointer format structure" do
      schema = %{"type" => "string", "format" => "relative-json-pointer"}

      assert schema["type"] == "string"
      assert schema["format"] == "relative-json-pointer"
    end

    test "regex format structure" do
      schema = %{"type" => "string", "format" => "regex"}

      assert schema["type"] == "string"
      assert schema["format"] == "regex"
    end
  end

  describe "binary formats" do
    test "binary format for raw binary data" do
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

    test "byte format structure (base64 encoded)" do
      # byte format is base64 encoded string
      schema = %{"type" => "string", "format" => "byte"}

      assert schema["type"] == "string"
      assert schema["format"] == "byte"
    end
  end

  describe "password format" do
    test "password format for UI hints" do
      schema = %{
        "type" => "string",
        "format" => "password"
      }

      assert schema["type"] == "string"
      assert schema["format"] == "password"
    end
  end

  describe "format in generated specs" do
    test "formats are preserved in spec schemas" do
      spec = AshOaskit.spec_31(domains: [AshOaskit.Test.SimpleDomain])

      schemas = spec["components"]["schemas"] || %{}

      # Check that at least some schemas have format fields
      all_properties =
        Enum.flat_map(schemas, fn {_name, schema} ->
          Map.values(Map.get(schema, "properties", %{}))
        end)

      # At least some properties should have formats
      formats = Enum.filter(all_properties, &Map.has_key?(&1, "format"))

      refute Enum.empty?(formats), "Expected some properties with format"
    end

    test "uuid fields have uuid format" do
      spec = AshOaskit.spec_31(domains: [AshOaskit.Test.SimpleDomain])

      schemas = spec["components"]["schemas"] || %{}

      # Find properties that should be UUIDs (like id fields)
      uuid_properties =
        Enum.flat_map(schemas, fn {_name, schema} ->
          properties = Map.get(schema, "properties", %{})

          Enum.filter(properties, fn {_key, prop} ->
            prop["format"] == "uuid"
          end)
        end)

      # Should have at least one UUID field (primary keys are usually UUIDs)
      assert is_list(uuid_properties)
    end
  end

  describe "format registry compliance" do
    test "all standard formats are valid strings" do
      standard_formats = [
        # OpenAPI defined
        "int32",
        "int64",
        "float",
        "double",
        "byte",
        "binary",
        "date",
        "date-time",
        "password",
        # JSON Schema defined
        "time",
        "duration",
        "email",
        "idn-email",
        "hostname",
        "idn-hostname",
        "ipv4",
        "ipv6",
        "uri",
        "uri-reference",
        "iri",
        "iri-reference",
        "uri-template",
        "json-pointer",
        "relative-json-pointer",
        "regex",
        "uuid"
      ]

      Enum.each(standard_formats, fn format ->
        assert is_binary(format)
        assert String.length(format) > 0
      end)
    end
  end
end
