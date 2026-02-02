defmodule AshOaskit.MultipartSupport do
  @moduledoc """
  Generates OpenAPI schemas for file upload and multipart/form-data requests.

  This module handles the detection and schema generation for actions that
  accept file uploads, generating appropriate multipart/form-data request
  body schemas.

  ## File Upload Detection

  An action is considered to support file uploads if any of its arguments
  have a type of `Ash.Type.File` or if the action is explicitly marked
  for file upload.

  ## Generated Schema Structure

  For actions with file arguments, the request body includes both
  `application/vnd.api+json` and `multipart/form-data` content types:

      %{
        requestBody: %{
          content: %{
            "application/vnd.api+json" => %{
              schema: json_schema
            },
            "multipart/form-data" => %{
              schema: multipart_schema
            }
          }
        }
      }

  ## Multipart Schema Format

  The multipart schema uses standard OpenAPI binary format:

      %{
        type: :object,
        properties: %{
          file: %{
            type: :string,
            format: :binary,
            description: "The file to upload"
          },
          data: %{
            type: :object,
            description: "JSON:API resource data"
          }
        }
      }

  ## Usage

      # Check if an action supports file uploads
      MultipartSupport.has_file_upload?(action)

      # Build multipart request body schema
      request_body = MultipartSupport.build_request_body(action, resource, opts)

      # Build just the multipart content schema
      schema = MultipartSupport.build_multipart_schema(action, opts)
  """

  import AshOaskit.Core.SchemaRef, only: [schema_ref: 1]

  @doc """
  Checks if an action has any file upload arguments.

  Returns `true` if the action has any argument of type `Ash.Type.File`
  or any embedded type containing a file.

  ## Parameters

    - `action` - The Ash action struct

  ## Returns

    Boolean indicating if the action accepts file uploads.

  ## Examples

      iex> MultipartSupport.has_file_upload?(upload_action)
      true

      iex> MultipartSupport.has_file_upload?(simple_create_action)
      false

  """
  @spec has_file_upload?(map() | struct()) :: boolean()
  def has_file_upload?(action) do
    arguments = Map.get(action, :arguments, [])

    Enum.any?(arguments, fn arg ->
      file_type?(arg.type)
    end)
  end

  @doc """
  Gets the file arguments from an action.

  Returns a list of arguments that have file types.

  ## Parameters

    - `action` - The Ash action struct

  ## Returns

    List of argument structs with file types.

  ## Examples

      MultipartSupport.file_arguments(upload_action)
      # => [%{name: :avatar, type: Ash.Type.File, ...}]

  """
  @spec file_arguments(map() | struct()) :: [map()]
  def file_arguments(action) do
    arguments = Map.get(action, :arguments, [])

    Enum.filter(arguments, fn arg ->
      file_type?(arg.type)
    end)
  end

  @doc """
  Builds a complete request body schema with multipart support.

  If the action has file arguments, generates a request body that
  supports both JSON:API and multipart/form-data content types.

  ## Parameters

    - `action` - The Ash action struct
    - `resource` - The Ash resource module
    - `opts` - Options keyword list
      - `:version` - OpenAPI version ("3.0" or "3.1")

  ## Returns

    A map representing the OpenAPI request body object.

  ## Examples

      iex> MultipartSupport.build_request_body(upload_action, MyApp.User, [])
      %{
        required: true,
        content: %{
          "application/vnd.api+json" => %{...},
          "multipart/form-data" => %{...}
        }
      }

  """
  @spec build_request_body(map() | struct(), module(), keyword()) :: map()
  def build_request_body(action, resource, opts) do
    schema_name = resource |> Module.split() |> List.last()

    json_schema = %{
      type: :object,
      properties: %{
        data: %{
          type: :object,
          properties: %{
            type: %{type: :string},
            attributes: schema_ref("#{schema_name}Attributes")
          }
        }
      }
    }

    content = %{
      "application/vnd.api+json" => %{
        schema: json_schema
      }
    }

    content =
      if has_file_upload?(action) do
        Map.put(content, "multipart/form-data", %{
          schema: build_multipart_schema(action, opts)
        })
      else
        content
      end

    %{
      required: true,
      content: content
    }
  end

  @doc """
  Builds the multipart/form-data schema for an action.

  Creates an OpenAPI schema that describes the multipart form structure,
  including file fields and JSON data fields.

  ## Parameters

    - `action` - The Ash action struct
    - `opts` - Options keyword list

  ## Returns

    A map representing the OpenAPI schema for multipart encoding.

  ## Examples

      iex> MultipartSupport.build_multipart_schema(upload_action, [])
      %{
        type: :object,
        properties: %{
          file: %{type: :string, format: :binary},
          data: %{type: :object}
        }
      }

  """
  @spec build_multipart_schema(map() | struct(), keyword()) :: map()
  def build_multipart_schema(action, _opts) do
    file_args = file_arguments(action)
    non_file_args = non_file_arguments(action)

    # Build properties for file arguments
    file_properties =
      Map.new(file_args, fn arg ->
        {arg.name, build_file_property(arg)}
      end)

    # Build properties for non-file arguments as JSON data
    data_properties =
      Map.new(non_file_args, fn arg ->
        {arg.name, %{type: :string}}
      end)

    # Combine with standard JSON:API data envelope
    properties =
      file_properties
      |> Map.merge(%{
        data: %{
          type: :string,
          description: "JSON:API resource data (as JSON string in multipart)"
        }
      })
      |> Map.merge(data_properties)

    # Determine required fields
    required =
      file_args
      |> Enum.filter(fn arg -> !Map.get(arg, :allow_nil?, true) end)
      |> Enum.map(fn arg -> to_string(arg.name) end)

    schema = %{
      type: :object,
      properties: properties
    }

    if required != [] do
      Map.put(schema, :required, required)
    else
      schema
    end
  end

  @doc """
  Builds encoding hints for multipart fields.

  OpenAPI 3.0+ supports encoding objects that specify how each field
  should be serialized in multipart requests.

  ## Parameters

    - `action` - The Ash action struct

  ## Returns

    A map of field names to encoding specifications.

  ## Examples

      iex> MultipartSupport.build_encoding(upload_action)
      %{
        "avatar" => %{contentType: "application/octet-stream"},
        "data" => %{contentType: "application/json"}
      }

  """
  @spec build_encoding(map() | struct()) :: map()
  def build_encoding(action) do
    file_args = file_arguments(action)

    file_encodings =
      Map.new(file_args, fn arg ->
        {to_string(arg.name), %{contentType: "application/octet-stream"}}
      end)

    # Add encoding for JSON data
    Map.put(file_encodings, "data", %{contentType: "application/json"})
  end

  @doc """
  Builds a complete multipart content specification with encoding.

  Returns a content object suitable for direct inclusion in a
  request body's content map.

  ## Parameters

    - `action` - The Ash action struct
    - `opts` - Options keyword list

  ## Returns

    A map with schema and encoding for multipart/form-data.

  ## Examples

      iex> MultipartSupport.build_multipart_content(upload_action, [])
      %{
        schema: %{...},
        encoding: %{...}
      }

  """
  @spec build_multipart_content(map() | struct(), keyword()) :: map()
  def build_multipart_content(action, opts) do
    %{
      schema: build_multipart_schema(action, opts),
      encoding: build_encoding(action)
    }
  end

  defp file_type?(type) do
    case type do
      Ash.Type.File -> true
      :file -> true
      {:array, inner} -> file_type?(inner)
      _ -> false
    end
  end

  defp non_file_arguments(action) do
    arguments = Map.get(action, :arguments, [])

    Enum.reject(arguments, fn arg ->
      file_type?(arg.type)
    end)
  end

  defp build_file_property(arg) do
    base_schema = %{
      type: :string,
      format: :binary
    }

    base_schema =
      if description = Map.get(arg, :description) do
        Map.put(base_schema, :description, description)
      else
        Map.put(base_schema, :description, "File upload for #{arg.name}")
      end

    # Handle array of files
    case arg.type do
      {:array, _} ->
        %{
          type: :array,
          items: base_schema
        }

      _ ->
        base_schema
    end
  end
end
