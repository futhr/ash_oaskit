defmodule AshOaskit.ErrorSchemasTest do
  @moduledoc """
  Comprehensive tests for the AshOaskit.ErrorSchemas module.

  This test module verifies that JSON:API compliant error schemas are
  generated correctly, including:

  - Error object schema structure
  - Error response envelope
  - Status code-specific responses
  - Operation type error responses
  - Component schema generation

  ## Test Categories

  1. **Error Object Schema** - Tests for single error object structure

  2. **Error Response Schema** - Tests for errors array envelope

  3. **Status Code Responses** - Tests for specific HTTP status codes

  4. **Operation Responses** - Tests for CRUD operation error sets

  5. **Component Integration** - Tests for adding to components
  """

  use ExUnit.Case, async: true

  alias AshOaskit.ErrorSchemas

  describe "error_object_schema/0" do
    # Tests for single error object structure

    test "returns object type schema" do
      schema = ErrorSchemas.error_object_schema()

      assert schema["type"] == "object"
    end

    test "includes id property" do
      schema = ErrorSchemas.error_object_schema()

      assert Map.has_key?(schema["properties"], "id")
      assert schema["properties"]["id"]["type"] == "string"
    end

    test "includes status property" do
      schema = ErrorSchemas.error_object_schema()

      assert Map.has_key?(schema["properties"], "status")
      assert schema["properties"]["status"]["type"] == "string"
    end

    test "includes code property" do
      schema = ErrorSchemas.error_object_schema()

      assert Map.has_key?(schema["properties"], "code")
    end

    test "includes title property" do
      schema = ErrorSchemas.error_object_schema()

      assert Map.has_key?(schema["properties"], "title")
    end

    test "includes detail property" do
      schema = ErrorSchemas.error_object_schema()

      assert Map.has_key?(schema["properties"], "detail")
    end

    test "includes source object with pointer and parameter" do
      schema = ErrorSchemas.error_object_schema()

      assert Map.has_key?(schema["properties"], "source")
      source = schema["properties"]["source"]
      assert source["type"] == "object"
      assert Map.has_key?(source["properties"], "pointer")
      assert Map.has_key?(source["properties"], "parameter")
    end

    test "includes meta property" do
      schema = ErrorSchemas.error_object_schema()

      assert Map.has_key?(schema["properties"], "meta")
      assert schema["properties"]["meta"]["type"] == "object"
    end

    test "all properties have descriptions" do
      schema = ErrorSchemas.error_object_schema()

      Enum.each(schema["properties"], fn {_name, prop} ->
        assert Map.has_key?(prop, "description"),
               "Property #{inspect(prop)} should have description"
      end)
    end
  end

  describe "error_response_schema/0" do
    # Tests for error response envelope

    test "returns object type schema" do
      schema = ErrorSchemas.error_response_schema()

      assert schema["type"] == "object"
    end

    test "requires errors array" do
      schema = ErrorSchemas.error_response_schema()

      assert "errors" in schema["required"]
    end

    test "errors property is array type" do
      schema = ErrorSchemas.error_response_schema()

      assert schema["properties"]["errors"]["type"] == "array"
    end

    test "errors array has minItems of 1" do
      schema = ErrorSchemas.error_response_schema()

      assert schema["properties"]["errors"]["minItems"] == 1
    end

    test "includes optional meta property" do
      schema = ErrorSchemas.error_response_schema()

      assert Map.has_key?(schema["properties"], "meta")
    end

    test "includes optional jsonapi property" do
      schema = ErrorSchemas.error_response_schema()

      assert Map.has_key?(schema["properties"], "jsonapi")
    end

    test "jsonapi property has version" do
      schema = ErrorSchemas.error_response_schema()

      jsonapi = schema["properties"]["jsonapi"]
      assert Map.has_key?(jsonapi["properties"], "version")
    end
  end

  describe "error_response/1" do
    # Tests for status code-specific responses

    test "returns response with description" do
      response = ErrorSchemas.error_response("404")

      assert Map.has_key?(response, "description")
      assert is_binary(response["description"])
    end

    test "returns response with content" do
      response = ErrorSchemas.error_response("404")

      assert Map.has_key?(response, "content")
      assert Map.has_key?(response["content"], "application/vnd.api+json")
    end

    test "content references JsonApiError schema" do
      response = ErrorSchemas.error_response("404")

      schema = response["content"]["application/vnd.api+json"]["schema"]
      assert schema["$ref"] == "#/components/schemas/JsonApiError"
    end

    test "400 has appropriate description" do
      response = ErrorSchemas.error_response("400")

      assert response["description"] =~ "Bad request"
    end

    test "401 has appropriate description" do
      response = ErrorSchemas.error_response("401")

      assert response["description"] =~ "Unauthorized"
    end

    test "403 has appropriate description" do
      response = ErrorSchemas.error_response("403")

      assert response["description"] =~ "Forbidden"
    end

    test "404 has appropriate description" do
      response = ErrorSchemas.error_response("404")

      assert response["description"] =~ "Not found"
    end

    test "409 has appropriate description" do
      response = ErrorSchemas.error_response("409")

      assert response["description"] =~ "Conflict"
    end

    test "422 has appropriate description" do
      response = ErrorSchemas.error_response("422")

      assert response["description"] =~ "Unprocessable"
    end

    test "500 has appropriate description" do
      response = ErrorSchemas.error_response("500")

      assert response["description"] =~ "Internal server error"
    end

    test "unknown status code has generic description" do
      response = ErrorSchemas.error_response("418")

      assert response["description"] == "Error response"
    end
  end

  describe "error_responses/1" do
    # Tests for multiple status code responses

    test "returns map of responses" do
      responses = ErrorSchemas.error_responses(["400", "404"])

      assert is_map(responses)
      assert Map.has_key?(responses, "400")
      assert Map.has_key?(responses, "404")
    end

    test "each response has correct structure" do
      responses = ErrorSchemas.error_responses(["400", "404", "422"])

      Enum.each(responses, fn {_code, response} ->
        assert Map.has_key?(response, "description")
        assert Map.has_key?(response, "content")
      end)
    end

    test "returns empty map for empty list" do
      responses = ErrorSchemas.error_responses([])

      assert responses == %{}
    end
  end

  describe "all_error_responses/0" do
    # Tests for all standard error responses

    test "includes all common error codes" do
      responses = ErrorSchemas.all_error_responses()

      expected_codes = ["400", "401", "403", "404", "409", "422", "500"]

      Enum.each(expected_codes, fn code ->
        assert Map.has_key?(responses, code), "Expected response for #{code}"
      end)
    end

    test "returns 7 responses" do
      responses = ErrorSchemas.all_error_responses()

      assert map_size(responses) == 7
    end
  end

  describe "read_error_responses/0" do
    # Tests for read operation errors

    test "includes 400, 401, 403, 404" do
      responses = ErrorSchemas.read_error_responses()

      assert Map.has_key?(responses, "400")
      assert Map.has_key?(responses, "401")
      assert Map.has_key?(responses, "403")
      assert Map.has_key?(responses, "404")
    end

    test "does not include 422" do
      responses = ErrorSchemas.read_error_responses()

      refute Map.has_key?(responses, "422")
    end
  end

  describe "create_error_responses/0" do
    # Tests for create operation errors

    test "includes 400, 401, 403, 409, 422" do
      responses = ErrorSchemas.create_error_responses()

      assert Map.has_key?(responses, "400")
      assert Map.has_key?(responses, "401")
      assert Map.has_key?(responses, "403")
      assert Map.has_key?(responses, "409")
      assert Map.has_key?(responses, "422")
    end

    test "does not include 404" do
      responses = ErrorSchemas.create_error_responses()

      refute Map.has_key?(responses, "404")
    end
  end

  describe "update_error_responses/0" do
    # Tests for update operation errors

    test "includes 400, 401, 403, 404, 409, 422" do
      responses = ErrorSchemas.update_error_responses()

      assert Map.has_key?(responses, "400")
      assert Map.has_key?(responses, "401")
      assert Map.has_key?(responses, "403")
      assert Map.has_key?(responses, "404")
      assert Map.has_key?(responses, "409")
      assert Map.has_key?(responses, "422")
    end
  end

  describe "delete_error_responses/0" do
    # Tests for delete operation errors

    test "includes 401, 403, 404" do
      responses = ErrorSchemas.delete_error_responses()

      assert Map.has_key?(responses, "401")
      assert Map.has_key?(responses, "403")
      assert Map.has_key?(responses, "404")
    end

    test "does not include 400 or 422" do
      responses = ErrorSchemas.delete_error_responses()

      refute Map.has_key?(responses, "400")
      refute Map.has_key?(responses, "422")
    end
  end

  describe "add_error_components/1" do
    # Tests for component integration

    test "adds JsonApiError schema" do
      components = ErrorSchemas.add_error_components(%{"schemas" => %{}})

      assert Map.has_key?(components["schemas"], "JsonApiError")
    end

    test "adds JsonApiErrorObject schema" do
      components = ErrorSchemas.add_error_components(%{"schemas" => %{}})

      assert Map.has_key?(components["schemas"], "JsonApiErrorObject")
    end

    test "preserves existing schemas" do
      existing = %{"schemas" => %{"Post" => %{"type" => "object"}}}
      components = ErrorSchemas.add_error_components(existing)

      assert Map.has_key?(components["schemas"], "Post")
      assert Map.has_key?(components["schemas"], "JsonApiError")
    end

    test "handles empty components" do
      components = ErrorSchemas.add_error_components(%{})

      assert Map.has_key?(components, "schemas")
      assert Map.has_key?(components["schemas"], "JsonApiError")
    end
  end

  describe "responses_for_operation/1" do
    # Tests for operation type mapping

    test "read returns read_error_responses" do
      responses = ErrorSchemas.responses_for_operation(:read)

      assert responses == ErrorSchemas.read_error_responses()
    end

    test "index returns read_error_responses" do
      responses = ErrorSchemas.responses_for_operation(:index)

      assert responses == ErrorSchemas.read_error_responses()
    end

    test "get returns read_error_responses" do
      responses = ErrorSchemas.responses_for_operation(:get)

      assert responses == ErrorSchemas.read_error_responses()
    end

    test "create returns create_error_responses" do
      responses = ErrorSchemas.responses_for_operation(:create)

      assert responses == ErrorSchemas.create_error_responses()
    end

    test "post returns create_error_responses" do
      responses = ErrorSchemas.responses_for_operation(:post)

      assert responses == ErrorSchemas.create_error_responses()
    end

    test "update returns update_error_responses" do
      responses = ErrorSchemas.responses_for_operation(:update)

      assert responses == ErrorSchemas.update_error_responses()
    end

    test "patch returns update_error_responses" do
      responses = ErrorSchemas.responses_for_operation(:patch)

      assert responses == ErrorSchemas.update_error_responses()
    end

    test "delete returns delete_error_responses" do
      responses = ErrorSchemas.responses_for_operation(:delete)

      assert responses == ErrorSchemas.delete_error_responses()
    end

    test "destroy returns delete_error_responses" do
      responses = ErrorSchemas.responses_for_operation(:destroy)

      assert responses == ErrorSchemas.delete_error_responses()
    end

    test "unknown operation returns all_error_responses" do
      responses = ErrorSchemas.responses_for_operation(:unknown)

      assert responses == ErrorSchemas.all_error_responses()
    end
  end

  describe "inline_error_response/1" do
    # Tests for inline error schemas

    test "includes inline schema instead of $ref" do
      response = ErrorSchemas.inline_error_response("400")

      schema = response["content"]["application/vnd.api+json"]["schema"]
      refute Map.has_key?(schema, "$ref")
      assert schema["type"] == "object"
    end

    test "has same description as regular response" do
      inline = ErrorSchemas.inline_error_response("404")
      regular = ErrorSchemas.error_response("404")

      assert inline["description"] == regular["description"]
    end
  end

  describe "edge cases" do
    # Tests for edge cases

    test "all schemas are valid maps" do
      assert is_map(ErrorSchemas.error_object_schema())
      assert is_map(ErrorSchemas.error_response_schema())
      assert is_map(ErrorSchemas.error_response("400"))
    end

    test "all response maps have string keys" do
      responses = ErrorSchemas.all_error_responses()

      Enum.each(Map.keys(responses), fn key ->
        assert is_binary(key), "Key should be string: #{inspect(key)}"
      end)
    end

    test "schema references use correct path format" do
      response = ErrorSchemas.error_response("400")
      ref = response["content"]["application/vnd.api+json"]["schema"]["$ref"]

      assert String.starts_with?(ref, "#/components/schemas/")
    end
  end
end
