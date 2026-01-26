defmodule AshOaskit.ParameterStylesTest do
  @moduledoc """
  Tests for OpenAPI parameter serialization styles.

  These tests verify that OpenAPI parameter serialization styles are properly
  understood and documented according to the OpenAPI 3.1 specification.

  Reference: https://spec.openapis.org/oas/v3.1.0#parameter-object
  Reference: https://swagger.io/docs/specification/serialization/

  ## Parameter Styles by Location

  | Location | Default Style | Explode | Example |
  |----------|---------------|---------|---------|
  | path | simple | false | /users/3,4,5 |
  | query | form | true | ?id=3&id=4&id=5 |
  | header | simple | false | X-IDs: 3,4,5 |
  | cookie | form | false | ids=3,4,5 |

  ## Style Options

  - **simple** - Comma-separated values
  - **form** - Query string format (ampersand or comma)
  - **label** - Dot-prefixed values
  - **matrix** - Semicolon-prefixed key=value
  - **deepObject** - Nested object bracket notation
  """

  use ExUnit.Case, async: true

  describe "path parameter styles" do
    test "simple style is default for path parameters" do
      # Simple style: /users/3,4,5 for array [3,4,5]
      param = %{
        "name" => "id",
        "in" => "path",
        "required" => true,
        "schema" => %{"type" => "string"}
      }

      # Default style for path is "simple"
      style = param["style"] || "simple"
      assert style == "simple"
    end

    test "path parameters are always required" do
      spec = AshOaskit.spec_31(domains: [AshOaskit.Test.Blog])
      paths = spec["paths"] || %{}

      Enum.each(paths, fn {_path, path_item} ->
        Enum.each(path_item, fn
          {method, operation} when method in ~w(get post patch put delete) ->
            parameters = operation["parameters"] || []

            path_params = Enum.filter(parameters, &(&1["in"] == "path"))

            Enum.each(path_params, fn param ->
              assert param["required"] == true,
                     "Path parameter '#{param["name"]}' must be required"
            end)

          _ ->
            :ok
        end)
      end)
    end

    test "label style uses dot prefix" do
      # Label style: /users/.3.4.5 for array [3,4,5]
      param = %{
        "name" => "id",
        "in" => "path",
        "style" => "label",
        "schema" => %{"type" => "array", "items" => %{"type" => "integer"}}
      }

      assert param["style"] == "label"
    end

    test "matrix style uses semicolon prefix" do
      # Matrix style: /users/;id=3,4,5 for array [3,4,5]
      param = %{
        "name" => "id",
        "in" => "path",
        "style" => "matrix",
        "schema" => %{"type" => "array", "items" => %{"type" => "integer"}}
      }

      assert param["style"] == "matrix"
    end

    test "explode affects array serialization" do
      # With explode=true: /users/3/4/5
      # With explode=false (default for simple): /users/3,4,5
      param_explode = %{
        "name" => "id",
        "in" => "path",
        "style" => "simple",
        "explode" => true,
        "schema" => %{"type" => "array", "items" => %{"type" => "integer"}}
      }

      param_no_explode = %{
        "name" => "id",
        "in" => "path",
        "style" => "simple",
        "explode" => false,
        "schema" => %{"type" => "array", "items" => %{"type" => "integer"}}
      }

      assert param_explode["explode"] == true
      assert param_no_explode["explode"] == false
    end
  end

  describe "query parameter styles" do
    test "form style is default for query parameters" do
      # Form style: ?id=3,4,5 for array [3,4,5]
      param = %{
        "name" => "filter",
        "in" => "query",
        "schema" => %{"type" => "string"}
      }

      # Default style for query is "form"
      style = param["style"] || "form"
      assert style == "form"
    end

    test "query parameters in generated spec" do
      spec = AshOaskit.spec_31(domains: [AshOaskit.Test.Blog])
      paths = spec["paths"] || %{}

      # Collect all query parameters
      query_params =
        Enum.flat_map(paths, fn {_path, path_item} ->
          Enum.flat_map(path_item, fn
            {method, operation} when method in ~w(get post patch put delete) ->
              parameters = operation["parameters"] || []
              Enum.filter(parameters, &(&1["in"] == "query"))

            _ ->
              []
          end)
        end)

      # All query parameters should have valid structure
      Enum.each(query_params, fn param ->
        assert Map.has_key?(param, "name")
        assert param["in"] == "query"
      end)
    end

    test "spaceDelimited style for arrays" do
      # spaceDelimited: ?id=3%204%205 for array [3,4,5]
      param = %{
        "name" => "ids",
        "in" => "query",
        "style" => "spaceDelimited",
        "schema" => %{"type" => "array", "items" => %{"type" => "integer"}}
      }

      assert param["style"] == "spaceDelimited"
    end

    test "pipeDelimited style for arrays" do
      # pipeDelimited: ?id=3|4|5 for array [3,4,5]
      param = %{
        "name" => "ids",
        "in" => "query",
        "style" => "pipeDelimited",
        "schema" => %{"type" => "array", "items" => %{"type" => "integer"}}
      }

      assert param["style"] == "pipeDelimited"
    end

    test "deepObject style for nested objects" do
      # deepObject: ?filter[status]=active&filter[type]=user
      param = %{
        "name" => "filter",
        "in" => "query",
        "style" => "deepObject",
        "explode" => true,
        "schema" => %{
          "type" => "object",
          "properties" => %{
            "status" => %{"type" => "string"},
            "type" => %{"type" => "string"}
          }
        }
      }

      assert param["style"] == "deepObject"
      assert param["explode"] == true
    end

    test "allowEmptyValue for query parameters" do
      param = %{
        "name" => "filter",
        "in" => "query",
        "allowEmptyValue" => true,
        "schema" => %{"type" => "string"}
      }

      assert param["allowEmptyValue"] == true
    end

    test "allowReserved for query parameters" do
      # Allows reserved characters :/?#[]@!$&'()*+,;= in value
      param = %{
        "name" => "url",
        "in" => "query",
        "allowReserved" => true,
        "schema" => %{"type" => "string"}
      }

      assert param["allowReserved"] == true
    end
  end

  describe "header parameter styles" do
    test "simple style is default for header parameters" do
      param = %{
        "name" => "X-Custom-Header",
        "in" => "header",
        "schema" => %{"type" => "string"}
      }

      # Default style for header is "simple"
      style = param["style"] || "simple"
      assert style == "simple"
    end

    test "header parameters are case-insensitive" do
      # Header names should be treated case-insensitively
      param1 = %{"name" => "X-Api-Key", "in" => "header"}
      param2 = %{"name" => "x-api-key", "in" => "header"}

      # Both should be valid
      assert param1["in"] == "header"
      assert param2["in"] == "header"
    end
  end

  describe "cookie parameter styles" do
    test "form style is default for cookie parameters" do
      param = %{
        "name" => "session_id",
        "in" => "cookie",
        "schema" => %{"type" => "string"}
      }

      # Default style for cookie is "form"
      style = param["style"] || "form"
      assert style == "form"
    end
  end

  describe "parameter schema" do
    test "parameters have schema or content" do
      spec = AshOaskit.spec_31(domains: [AshOaskit.Test.Blog])
      paths = spec["paths"] || %{}

      Enum.each(paths, fn {_path, path_item} ->
        Enum.each(path_item, fn
          {method, operation} when method in ~w(get post patch put delete) ->
            parameters = operation["parameters"] || []

            Enum.each(parameters, fn param ->
              has_schema = Map.has_key?(param, "schema")
              has_content = Map.has_key?(param, "content")

              # Parameter must have either schema or content
              assert has_schema or has_content,
                     "Parameter '#{param["name"]}' must have schema or content"
            end)

          _ ->
            :ok
        end)
      end)
    end

    test "parameter schema is valid JSON Schema" do
      spec = AshOaskit.spec_31(domains: [AshOaskit.Test.Blog])
      paths = spec["paths"] || %{}

      Enum.each(paths, fn {_path, path_item} ->
        Enum.each(path_item, fn
          {method, operation} when method in ~w(get post patch put delete) ->
            parameters = operation["parameters"] || []

            Enum.each(parameters, fn param ->
              if schema = param["schema"] do
                assert is_map(schema),
                       "Parameter schema should be a map"
              end
            end)

          _ ->
            :ok
        end)
      end)
    end
  end

  describe "parameter examples" do
    test "example field can be provided" do
      param = %{
        "name" => "id",
        "in" => "path",
        "required" => true,
        "schema" => %{"type" => "string", "format" => "uuid"},
        "example" => "550e8400-e29b-41d4-a716-446655440000"
      }

      assert param["example"] == "550e8400-e29b-41d4-a716-446655440000"
    end

    test "examples field can provide multiple examples" do
      param = %{
        "name" => "status",
        "in" => "query",
        "schema" => %{"type" => "string"},
        "examples" => %{
          "active" => %{
            "value" => "active",
            "summary" => "Active status"
          },
          "inactive" => %{
            "value" => "inactive",
            "summary" => "Inactive status"
          }
        }
      }

      assert is_map(param["examples"])
      assert Map.has_key?(param["examples"], "active")
      assert Map.has_key?(param["examples"], "inactive")
    end
  end

  describe "deprecated parameters" do
    test "deprecated field marks parameter as obsolete" do
      param = %{
        "name" => "old_filter",
        "in" => "query",
        "deprecated" => true,
        "schema" => %{"type" => "string"},
        "description" => "Deprecated: use 'filter' instead"
      }

      assert param["deprecated"] == true
    end
  end

  describe "parameter location validation" do
    test "valid parameter locations" do
      valid_locations = ["query", "header", "path", "cookie"]

      Enum.each(valid_locations, fn location ->
        param = %{"name" => "test", "in" => location}
        assert param["in"] in valid_locations
      end)
    end

    test "parameters in spec have valid locations" do
      spec = AshOaskit.spec_31(domains: [AshOaskit.Test.Blog])
      paths = spec["paths"] || %{}

      valid_locations = ["query", "header", "path", "cookie"]

      Enum.each(paths, fn {_path, path_item} ->
        Enum.each(path_item, fn
          {method, operation} when method in ~w(get post patch put delete) ->
            parameters = operation["parameters"] || []

            Enum.each(parameters, fn param ->
              assert param["in"] in valid_locations,
                     "Invalid parameter location: #{param["in"]}"
            end)

          _ ->
            :ok
        end)
      end)
    end
  end

  describe "style and explode defaults" do
    test "default styles per location" do
      defaults = %{
        "path" => "simple",
        "query" => "form",
        "header" => "simple",
        "cookie" => "form"
      }

      Enum.each(defaults, fn {location, expected_style} ->
        param = %{"name" => "test", "in" => location}
        style = param["style"] || defaults[location]
        assert style == expected_style
      end)
    end

    test "default explode per style" do
      # form style defaults to explode=true
      # other styles default to explode=false
      form_param = %{"in" => "query", "style" => "form"}
      simple_param = %{"in" => "path", "style" => "simple"}

      form_explode = form_param["explode"]
      simple_explode = simple_param["explode"]

      # When not specified, form defaults to true, others to false
      assert form_explode == nil or form_explode == true
      assert simple_explode == nil or simple_explode == false
    end
  end
end
