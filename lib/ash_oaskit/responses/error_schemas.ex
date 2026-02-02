defmodule AshOaskit.ErrorSchemas do
  @moduledoc """
  Generates JSON:API compliant error response schemas for OpenAPI specs.

  This module provides standard error response schemas following the JSON:API
  specification format. These schemas can be used in OpenAPI response definitions
  for error status codes.

  ## JSON:API Error Format

  The JSON:API specification defines a standard error object structure:

      {
        "errors": [
          {
            "id": "unique-error-id",
            "status": "422",
            "code": "validation_error",
            "title": "Invalid Attribute",
            "detail": "First name must be at least 2 characters",
            "source": {
              "pointer": "/data/attributes/first_name",
              "parameter": "filter[name]"
            },
            "meta": {
              "field": "first_name"
            }
          }
        ]
      }

  ## Error Response Codes

  This module generates schemas for common HTTP error status codes:

  - `400` - Bad Request (malformed request syntax)
  - `401` - Unauthorized (authentication required)
  - `403` - Forbidden (authorization failed)
  - `404` - Not Found (resource doesn't exist)
  - `409` - Conflict (resource conflict, e.g., duplicate)
  - `422` - Unprocessable Entity (validation errors)
  - `500` - Internal Server Error (server-side failures)

  ## Usage

      # Get the standard JSON:API error schema
      schema = ErrorSchemas.error_response_schema()

      # Get error responses for a specific set of status codes
      responses = ErrorSchemas.error_responses(["400", "404", "422"])

      # Get all standard error responses
      responses = ErrorSchemas.all_error_responses()

      # Add error schemas to components
      components = ErrorSchemas.add_error_components(existing_components)
  """

  import AshOaskit.Core.SchemaRef, only: [schema_ref: 1]

  @doc """
  Returns the standard JSON:API error object schema.

  This schema represents a single error object as defined by the JSON:API
  specification.

  ## Returns

    A map representing the OpenAPI schema for a single error object.

  ## Examples

      iex> schema = ErrorSchemas.error_object_schema()
      ...> schema[:type]
      :object
      iex> Map.has_key?(schema[:properties], :id)
      true
      iex> Map.has_key?(schema[:properties], :status)
      true

  """
  @spec error_object_schema() :: map()
  def error_object_schema do
    %{
      type: :object,
      properties: %{
        id: %{
          type: :string,
          description: "A unique identifier for this particular occurrence of the problem"
        },
        status: %{
          type: :string,
          description: "The HTTP status code applicable to this problem, as a string"
        },
        code: %{
          type: :string,
          description: "An application-specific error code"
        },
        title: %{
          type: :string,
          description: "A short, human-readable summary of the problem"
        },
        detail: %{
          type: :string,
          description: "A human-readable explanation specific to this occurrence"
        },
        source: %{
          type: :object,
          description: "An object containing references to the source of the error",
          properties: %{
            pointer: %{
              type: :string,
              description: "A JSON Pointer to the value in the request that caused the error"
            },
            parameter: %{
              type: :string,
              description: "A string indicating which query parameter caused the error"
            },
            header: %{
              type: :string,
              description: "A string indicating which header caused the error"
            }
          }
        },
        meta: %{
          type: :object,
          description: "A meta object containing non-standard meta-information",
          additionalProperties: true
        }
      }
    }
  end

  @doc """
  Returns the JSON:API error response envelope schema.

  This wraps error objects in the standard `errors` array format.

  ## Returns

    A map representing the OpenAPI schema for an error response.

  ## Examples

      iex> ErrorSchemas.error_response_schema()
      %{
        type: :object,
        properties: %{
          errors: %{
            type: :array,
            items: %{...}
          }
        }
      }

  """
  @spec error_response_schema() :: map()
  def error_response_schema do
    %{
      type: :object,
      required: ["errors"],
      properties: %{
        errors: %{
          type: :array,
          items: error_object_schema(),
          minItems: 1,
          description: "An array of error objects"
        },
        meta: %{
          type: :object,
          description: "A meta object containing non-standard meta-information",
          additionalProperties: true
        },
        jsonapi: %{
          type: :object,
          description: "The JSON:API version object",
          properties: %{
            version: %{
              type: :string,
              description: "The JSON:API version"
            }
          }
        }
      }
    }
  end

  @doc """
  Returns an error response object for a specific status code.

  Generates an OpenAPI response object with appropriate description
  and schema for the given HTTP status code.

  ## Parameters

    - `status_code` - The HTTP status code as a string

  ## Returns

    A map representing the OpenAPI response object.

  ## Examples

      iex> ErrorSchemas.error_response("404")
      %{
        description: "Resource not found",
        content: %{
          "application/vnd.api+json" => %{
            schema: %{"$ref" => "#/components/schemas/JsonApiError"}
          }
        }
      }

  """
  @spec error_response(String.t()) :: map()
  def error_response(status_code) do
    %{
      description: error_description(status_code),
      content: %{
        "application/vnd.api+json" => %{
          schema: schema_ref("JsonApiError")
        }
      }
    }
  end

  @doc """
  Returns error responses for the specified status codes.

  ## Parameters

    - `status_codes` - List of HTTP status codes as strings

  ## Returns

    A map of status codes to response objects.

  ## Examples

      iex> ErrorSchemas.error_responses(["400", "404"])
      %{
        "400" => %{...},
        "404" => %{...}
      }

  """
  @spec error_responses([String.t()]) :: map()
  def error_responses(status_codes) do
    Map.new(status_codes, fn code -> {code, error_response(code)} end)
  end

  @doc """
  Returns all standard error responses.

  Includes responses for: 400, 401, 403, 404, 409, 422, 500.

  ## Returns

    A map of status codes to response objects.

  """
  @spec all_error_responses() :: map()
  def all_error_responses do
    error_responses(["400", "401", "403", "404", "409", "422", "500"])
  end

  @doc """
  Returns common error responses for read operations.

  Includes: 400, 401, 403, 404.

  ## Returns

    A map of status codes to response objects.

  """
  @spec read_error_responses() :: map()
  def read_error_responses do
    error_responses(["400", "401", "403", "404"])
  end

  @doc """
  Returns common error responses for create operations.

  Includes: 400, 401, 403, 409, 422.

  ## Returns

    A map of status codes to response objects.

  """
  @spec create_error_responses() :: map()
  def create_error_responses do
    error_responses(["400", "401", "403", "409", "422"])
  end

  @doc """
  Returns common error responses for update operations.

  Includes: 400, 401, 403, 404, 409, 422.

  ## Returns

    A map of status codes to response objects.

  """
  @spec update_error_responses() :: map()
  def update_error_responses do
    error_responses(["400", "401", "403", "404", "409", "422"])
  end

  @doc """
  Returns common error responses for delete operations.

  Includes: 401, 403, 404.

  ## Returns

    A map of status codes to response objects.

  """
  @spec delete_error_responses() :: map()
  def delete_error_responses do
    error_responses(["401", "403", "404"])
  end

  @doc """
  Adds error schema components to an existing components map.

  This adds the `JsonApiError` and `JsonApiErrorObject` schemas to
  the components schemas section.

  ## Parameters

    - `components` - Existing OpenAPI components map

  ## Returns

    Updated components map with error schemas added.

  ## Examples

      iex> ErrorSchemas.add_error_components(%{schemas: %{}})
      %{
        schemas: %{
          "JsonApiError" => %{...},
          "JsonApiErrorObject" => %{...}
        }
      }

  """
  @spec add_error_components(map()) :: map()
  def add_error_components(components) do
    schemas = Map.get(components, :schemas, %{})

    updated_schemas =
      schemas
      |> Map.put("JsonApiError", error_response_schema())
      |> Map.put("JsonApiErrorObject", error_object_schema())

    Map.put(components, :schemas, updated_schemas)
  end

  @doc """
  Returns responses for a specific operation type.

  ## Parameters

    - `operation_type` - One of `:read`, `:create`, `:update`, `:delete`

  ## Returns

    A map of status codes to response objects.

  """
  @spec responses_for_operation(atom()) :: map()
  def responses_for_operation(operation_type) do
    case operation_type do
      :read -> read_error_responses()
      :index -> read_error_responses()
      :get -> read_error_responses()
      :create -> create_error_responses()
      :post -> create_error_responses()
      :update -> update_error_responses()
      :patch -> update_error_responses()
      :delete -> delete_error_responses()
      :destroy -> delete_error_responses()
      _ -> all_error_responses()
    end
  end

  @doc """
  Returns a simple error response without $ref (inline schema).

  Useful when you don't want to use component references.

  ## Parameters

    - `status_code` - The HTTP status code as a string

  ## Returns

    A map with inline error schema.

  """
  @spec inline_error_response(String.t()) :: map()
  def inline_error_response(status_code) do
    %{
      description: error_description(status_code),
      content: %{
        "application/vnd.api+json" => %{
          schema: error_response_schema()
        }
      }
    }
  end

  defp error_description(status_code) do
    case status_code do
      "400" -> "Bad request - the request was malformed or invalid"
      "401" -> "Unauthorized - authentication is required"
      "403" -> "Forbidden - the authenticated user lacks permission"
      "404" -> "Not found - the requested resource does not exist"
      "409" -> "Conflict - the request conflicts with current state"
      "422" -> "Unprocessable entity - validation errors occurred"
      "500" -> "Internal server error - an unexpected error occurred"
      _ -> "Error response"
    end
  end
end
