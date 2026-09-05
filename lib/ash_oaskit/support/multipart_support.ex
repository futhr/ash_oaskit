defmodule AshOaskit.MultipartSupport do
  @moduledoc """
  Documents file uploads using AshJsonApi's `multipart/x.ash+form-data` protocol.

  Generated operations and `build_request_body/3` use route-derived input
  contracts, a JSON `data` part, and arbitrary binary upload parts referenced
  by name from the JSON data.

  The lower-level `build_multipart_schema/2`, `build_encoding/1`, and
  `build_multipart_content/2` helpers retain their legacy, conventional form
  layout for custom endpoints. They are not the AshJsonApi upload protocol.
  """

  alias AshOaskit.Config
  alias AshOaskit.SchemaBuilder.ResourceSchemas
  alias AshOaskit.TypeMapper

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

  @doc "Adds AshJsonApi's multipart media type using the same route-specific input contract."
  @spec add_route_content(map(), map(), keyword()) :: map()
  def add_route_content(operation, route, opts) do
    {attributes, arguments} = ResourceSchemas.input_fields(route)
    body = operation[:requestBody]

    if body && Enum.any?(attributes ++ arguments, &file_type?(&1.type)) do
      input = multipart_input(route, attributes, arguments, opts)
      data = body.content["application/vnd.api+json"].schema.properties.data

      data =
        if route.type == :route, do: input, else: put_in(data, [:properties, :attributes], input)

      content = %{
        schema: %{
          type: :object,
          required: ["data"],
          properties: %{data: data},
          additionalProperties: %{type: :string, format: :binary}
        },
        encoding: %{"data" => %{contentType: "application/vnd.api+json"}}
      }

      put_in(operation, [:requestBody, :content, "multipart/x.ash+form-data"], content)
    else
      operation
    end
  end

  defp multipart_input(route, attributes, arguments, opts) do
    properties =
      Map.new(attributes ++ arguments, fn field ->
        name =
          if field in arguments,
            do: Config.json_argument_name(route.resource, route.action, field.name),
            else: Config.json_field_name(route.resource, field.name)

        schema = multipart_field(field, Keyword.get(opts, :version, "3.1"))
        {name, schema}
      end)

    required = ResourceSchemas.input_required(route)
    schema = %{type: :object, properties: properties}
    if required == [], do: schema, else: Map.put(schema, :required, required)
  end

  defp multipart_field(%{type: type} = field, version) do
    cond do
      type in [:file, Ash.Type.File] ->
        %{type: :string, description: "Name of an uploaded multipart part"}

      file_type?(type) ->
        %{type: :array, items: multipart_field(%{field | type: elem(type, 1)}, version)}

      version == "3.0" ->
        TypeMapper.to_json_schema_30(field, direction: :input)

      true ->
        TypeMapper.to_json_schema_31(field, direction: :input)
    end
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
    action =
      Ash.Resource.Info.action(resource, action.name) ||
        raise ArgumentError, "action does not belong to #{inspect(resource)}"

    {type, method} =
      case action.type do
        :create -> {:post, :post}
        :update -> {:patch, :patch}
        :action -> {:route, :post}
        _ -> raise ArgumentError, "multipart request bodies require a write or generic action"
      end

    route =
      Keyword.get(opts, :route) ||
        %{resource: resource, action: action.name, type: type, method: method, route: ""}

    operation =
      AshOaskit.Generators.PathBuilder.build_operation(
        route,
        Keyword.put_new(opts, :version, "3.1")
      )

    operation[:requestBody]
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
  def build_multipart_schema(action, opts) do
    resource = Keyword.get(opts, :resource)
    file_args = file_arguments(action)
    non_file_args = non_file_arguments(action)

    # Build properties for file arguments
    file_properties =
      Map.new(file_args, fn arg ->
        {argument_name(resource, action, arg), build_file_property(arg)}
      end)

    # Build properties for non-file arguments as JSON data
    data_properties =
      Map.new(non_file_args, fn arg ->
        {argument_name(resource, action, arg), %{type: :string}}
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
      |> Enum.map(fn arg -> resource |> argument_name(action, arg) |> to_string() end)

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

  defp argument_name(nil, _, arg), do: arg.name

  defp argument_name(resource, action, arg) do
    Config.json_argument_name(resource, action.name, arg.name)
  end
end
