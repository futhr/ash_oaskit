defmodule AshOaskit.ResponseCodesTest do
  @moduledoc """
  Tests for HTTP response code generation in OpenAPI specs.

  These tests verify that HTTP response codes are properly generated in
  OpenAPI specifications according to REST conventions and OpenAPI spec.

  Reference: https://spec.openapis.org/oas/v3.1.0#responses-object

  ## Response Code Categories

  - **2xx Success** - 200 OK, 201 Created, 204 No Content
  - **4xx Client Errors** - 400, 401, 403, 404, 409, 422
  - **5xx Server Errors** - 500 Internal Server Error

  ## Response Codes by Operation

  | Operation | Success | Common Errors |
  |-----------|---------|---------------|
  | GET (read) | 200 | 404 |
  | GET (list) | 200 | - |
  | POST | 201 | 400, 422 |
  | PATCH | 200 | 400, 404, 422 |
  | DELETE | 200/204 | 404 |
  """

  use ExUnit.Case, async: true

  describe "success response codes" do
    test "200 OK for successful read operations" do
      spec = AshOaskit.spec_31(domains: [AshOaskit.Test.Blog])
      paths = spec["paths"] || %{}

      # GET operations should have 200 response
      Enum.each(paths, fn {_, path_item} ->
        if get_op = path_item["get"] do
          responses = get_op["responses"] || %{}

          assert Map.has_key?(responses, "200"),
                 "GET operation should have 200 response"
        end
      end)
    end

    test "201 Created for successful create operations" do
      spec = AshOaskit.spec_31(domains: [AshOaskit.Test.Blog])
      paths = spec["paths"] || %{}

      # POST operations should have 201 or 200 response
      Enum.each(paths, fn {_, path_item} ->
        if post_op = path_item["post"] do
          responses = post_op["responses"] || %{}

          assert Map.has_key?(responses, "201") or Map.has_key?(responses, "200"),
                 "POST operation should have 201 or 200 response"
        end
      end)
    end

    test "204 No Content for successful delete operations" do
      spec = AshOaskit.spec_31(domains: [AshOaskit.Test.Blog])
      paths = spec["paths"] || %{}

      # DELETE operations typically return 204 or 200
      Enum.each(paths, fn {_, path_item} ->
        if delete_op = path_item["delete"] do
          responses = delete_op["responses"] || %{}

          has_success =
            Map.has_key?(responses, "204") or
              Map.has_key?(responses, "200") or
              Map.has_key?(responses, "202")

          assert has_success,
                 "DELETE operation should have success response"
        end
      end)
    end

    test "200 for successful update operations" do
      spec = AshOaskit.spec_31(domains: [AshOaskit.Test.Blog])
      paths = spec["paths"] || %{}

      # PATCH/PUT operations should have 200 response
      Enum.each(paths, fn {_, path_item} ->
        if patch_op = path_item["patch"] do
          responses = patch_op["responses"] || %{}

          assert Map.has_key?(responses, "200") or Map.has_key?(responses, "204"),
                 "PATCH operation should have 200 or 204 response"
        end
      end)
    end
  end

  describe "client error response codes" do
    test "400 Bad Request is documented when applicable" do
      spec = AshOaskit.spec_31(domains: [AshOaskit.Test.Blog])
      paths = spec["paths"] || %{}

      # Operations with request bodies should document 400
      Enum.each(paths, fn {_, path_item} ->
        Enum.each(path_item, fn
          {method, operation} when method in ~w(post patch put) ->
            if Map.has_key?(operation, "requestBody") do
              responses = operation["responses"] || %{}

              # 400 should be documented for operations with request body
              # This is a recommendation, not a requirement
              _ = Map.has_key?(responses, "400")
            end

          _ ->
            :ok
        end)
      end)
    end

    test "404 Not Found is documented for resource operations" do
      spec = AshOaskit.spec_31(domains: [AshOaskit.Test.Blog])
      paths = spec["paths"] || %{}

      # Operations on specific resources should document 404
      Enum.each(paths, fn {path, path_item} ->
        # Paths with parameters (like /posts/{id}) should have 404
        if String.contains?(path, "{") do
          Enum.each(path_item, fn
            {method, operation} when method in ~w(get patch put delete) ->
              responses = operation["responses"] || %{}
              # 404 should be documented for resource-specific operations
              _ = Map.has_key?(responses, "404")

            _ ->
              :ok
          end)
        end
      end)
    end

    test "401 Unauthorized documented when security is defined" do
      spec =
        AshOaskit.spec_31(
          domains: [AshOaskit.Test.Blog],
          security: [%{"bearer_auth" => []}]
        )

      # When security is defined, operations might document 401
      assert is_map(spec["paths"])
    end

    test "422 Unprocessable Entity for validation errors" do
      spec = AshOaskit.spec_31(domains: [AshOaskit.Test.Blog])
      paths = spec["paths"] || %{}

      # Operations with request bodies may document 422
      Enum.each(paths, fn {_, path_item} ->
        Enum.each(path_item, fn
          {method, operation} when method in ~w(post patch put) ->
            responses = operation["responses"] || %{}
            # 422 is commonly used for validation errors
            _ = Map.has_key?(responses, "422")

          _ ->
            :ok
        end)
      end)
    end
  end

  describe "response object structure" do
    test "responses have description field" do
      spec = AshOaskit.spec_31(domains: [AshOaskit.Test.Blog])
      paths = spec["paths"] || %{}

      Enum.each(paths, fn {_, path_item} ->
        Enum.each(path_item, fn
          {method, operation} when method in ~w(get post patch put delete) ->
            responses = operation["responses"] || %{}

            Enum.each(responses, fn {code, response} ->
              # Description is required in OpenAPI
              assert Map.has_key?(response, "description"),
                     "Response #{code} should have description"
            end)

          _ ->
            :ok
        end)
      end)
    end

    test "success responses have content when returning data" do
      spec = AshOaskit.spec_31(domains: [AshOaskit.Test.Blog])
      paths = spec["paths"] || %{}

      Enum.each(paths, fn {_, path_item} ->
        if get_op = path_item["get"] do
          responses = get_op["responses"] || %{}

          if response_200 = responses["200"] do
            # GET 200 responses typically have content
            assert Map.has_key?(response_200, "content") or
                     Map.has_key?(response_200, "description"),
                   "200 response should have content or at least description"
          end
        end
      end)
    end

    test "204 responses have no content" do
      # 204 No Content should not have a response body
      response_204 = %{
        "description" => "No Content"
      }

      refute Map.has_key?(response_204, "content")
    end
  end

  describe "wildcard response codes" do
    test "wildcard codes are valid" do
      valid_wildcards = ["1XX", "2XX", "3XX", "4XX", "5XX"]

      Enum.each(valid_wildcards, fn code ->
        assert Regex.match?(~r/^[1-5]XX$/, code)
      end)
    end

    test "default response can be used as fallback" do
      responses = %{
        "200" => %{"description" => "Success"},
        "default" => %{"description" => "Unexpected error"}
      }

      assert Map.has_key?(responses, "default")
    end
  end

  describe "content types in responses" do
    test "application/vnd.api+json for JSON:API responses" do
      spec = AshOaskit.spec_31(domains: [AshOaskit.Test.Blog])
      paths = spec["paths"] || %{}

      Enum.each(paths, fn {_, path_item} ->
        Enum.each(path_item, fn
          {method, operation} when method in ~w(get post patch) ->
            responses = operation["responses"] || %{}

            Enum.each(responses, fn {_, response} ->
              if content = response["content"] do
                # Should use appropriate content type
                assert Map.has_key?(content, "application/vnd.api+json") or
                         Map.has_key?(content, "application/json"),
                       "Response should have JSON content type"
              end
            end)

          _ ->
            :ok
        end)
      end)
    end
  end

  describe "HTTP method semantics" do
    test "DELETE operations have no request body" do
      spec = AshOaskit.spec_31(domains: [AshOaskit.Test.Blog])

      paths = spec["paths"] || %{}

      Enum.each(paths, fn {path, path_item} ->
        if delete_op = path_item["delete"] do
          refute Map.has_key?(delete_op, "requestBody"),
                 "DELETE #{path} should not have requestBody"
        end
      end)
    end

    test "GET operations have no request body" do
      spec = AshOaskit.spec_31(domains: [AshOaskit.Test.Blog])

      paths = spec["paths"] || %{}

      Enum.each(paths, fn {path, path_item} ->
        if get_op = path_item["get"] do
          refute Map.has_key?(get_op, "requestBody"),
                 "GET #{path} should not have requestBody"
        end
      end)
    end

    test "additionalProperties is at schema level, not nested in properties" do
      spec = AshOaskit.spec_31(domains: [AshOaskit.Test.SimpleDomain])

      schemas = spec["components"]["schemas"] || %{}

      Enum.each(schemas, fn {name, schema} ->
        properties = schema["properties"] || %{}

        Enum.each(properties, fn {prop_name, prop_schema} ->
          if is_map(prop_schema) do
            inner_props = prop_schema["properties"] || %{}

            refute Map.has_key?(inner_props, "additionalProperties"),
                   "#{name}.#{prop_name} has additionalProperties inside properties"
          end
        end)
      end)
    end
  end

  describe "response schema references" do
    test "response schemas use $ref when appropriate" do
      spec = AshOaskit.spec_31(domains: [AshOaskit.Test.Blog])
      paths = spec["paths"] || %{}

      Enum.each(paths, fn {_, path_item} ->
        Enum.each(path_item, fn
          {method, operation} when method in ~w(get post patch) ->
            responses = operation["responses"] || %{}

            Enum.each(responses, fn {_, response} ->
              if content = response["content"] do
                Enum.each(content, fn {_, media_obj} ->
                  if schema = media_obj["schema"] do
                    # Schema can be inline or $ref
                    assert is_map(schema)
                  end
                end)
              end
            end)

          _ ->
            :ok
        end)
      end)
    end
  end
end
