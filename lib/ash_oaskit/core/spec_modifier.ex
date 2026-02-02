defmodule AshOaskit.SpecModifier do
  @moduledoc """
  Provides support for modifying OpenAPI specifications after generation.

  This module enables users to customize the generated OpenAPI spec through
  callback functions, similar to AshJsonApi's `modify_open_api` option.
  This is useful for adding custom extensions, modifying schemas, or
  integrating with external documentation systems.

  ## Modification Patterns

  ### Function Callback
  Pass a function that receives the spec and returns a modified spec:
  ```elixir
  AshOaskit.spec_31(
    domains: [MyApp.Blog],
    modify_open_api: fn spec ->
      put_in(spec, ["info", "x-custom"], "value")
    end
  )
  ```

  ### MFA Tuple
  Pass a module, function, args tuple for more complex modifications:
  ```elixir
  AshOaskit.spec_31(
    domains: [MyApp.Blog],
    modify_open_api: {MyApp.OpenApiCustomizer, :customize, [extra_arg]}
  )
  ```

  ### Multiple Modifiers
  Chain multiple modifications:
  ```elixir
  AshOaskit.spec_31(
    domains: [MyApp.Blog],
    modify_open_api: [
      &add_custom_headers/1,
      &add_rate_limiting_info/1,
      {MyApp.Docs, :add_examples, []}
    ]
  )
  ```

  ## Common Modifications

  - Adding custom headers to all operations
  - Adding x-* extension fields
  - Modifying security schemes
  - Adding webhook definitions
  - Customizing server URLs per environment
  - Adding examples to schemas
  """

  require Logger

  @doc """
  Applies modifications to an OpenAPI specification.

  The modifier can be:
  - A function that takes the spec and returns the modified spec
  - An MFA tuple `{module, function, args}` where the spec is prepended to args
  - A list of modifiers to apply in sequence

  ## Examples

      iex> spec = %{"info" => %{"title" => "My API"}}
      ...>
      ...> AshOaskit.SpecModifier.apply_modifier(spec, fn s ->
      ...>   put_in(s, ["info", "version"], "2.0")
      ...> end)
      %{"info" => %{"title" => "My API", "version" => "2.0"}}

      iex> spec = %{"info" => %{}}
      ...> AshOaskit.SpecModifier.apply_modifier(spec, {Map, :put, ["info", %{"title" => "New"}]})
      %{"info" => %{"title" => "New"}}
  """
  @type modifier ::
          (map() -> map())
          | {module(), atom(), list()}
          | list()
          | nil

  @spec apply_modifier(map(), modifier()) :: map()
  def apply_modifier(spec, nil), do: spec

  def apply_modifier(spec, fun) when is_function(fun, 1) do
    fun.(spec)
  end

  def apply_modifier(spec, {mod, fun, args})
      when is_atom(mod) and is_atom(fun) and is_list(args) do
    apply(mod, fun, [spec | args])
  end

  def apply_modifier(spec, modifiers) when is_list(modifiers) do
    Enum.reduce(modifiers, spec, &apply_modifier(&2, &1))
  end

  def apply_modifier(spec, invalid) do
    Logger.warning("AshOaskit: ignoring invalid spec modifier: #{inspect(invalid)}")
    spec
  end

  @doc """
  Adds a custom extension field to the spec at the specified path.

  Extension fields in OpenAPI start with "x-" and can contain any value.

  ## Examples

      iex> spec = %{"info" => %{"title" => "API"}}
      ...> AshOaskit.SpecModifier.add_extension(spec, ["info"], "x-logo", %{"url" => "logo.png"})
      %{"info" => %{"title" => "API", "x-logo" => %{"url" => "logo.png"}}}
  """
  @spec add_extension(map(), list(String.t()), String.t(), any()) :: map()
  def add_extension(spec, path, extension_name, value) do
    full_path = path ++ [extension_name]
    put_in_path(spec, full_path, value)
  end

  @doc """
  Adds custom headers to all operations in the spec.

  This is useful for documenting common headers like correlation IDs,
  API versions, or custom authentication headers.

  ## Options

  - `:operations` - List of operation IDs to modify. If nil, modifies all operations.
  - `:required` - Whether the header is required. Defaults to false.

  ## Examples

      iex> spec = %{"paths" => %{"/posts" => %{"get" => %{"operationId" => "listPosts"}}}}
      ...>
      ...> AshOaskit.SpecModifier.add_header_to_operations(spec, "X-Request-ID", %{
      ...>   "type" => "string",
      ...>   "format" => "uuid"
      ...> })
  """
  @spec add_header_to_operations(map(), String.t(), map(), keyword()) :: map()
  def add_header_to_operations(spec, header_name, schema, opts \\ []) do
    required = Keyword.get(opts, :required, false)
    operation_ids = Keyword.get(opts, :operations)

    header_param = %{
      "name" => header_name,
      "in" => "header",
      "required" => required,
      "schema" => schema
    }

    update_operations(spec, operation_ids, fn operation ->
      params = Map.get(operation, "parameters", [])
      Map.put(operation, "parameters", params ++ [header_param])
    end)
  end

  @doc """
  Adds a server to the spec's servers list.

  ## Examples

      iex> spec = %{"servers" => [%{"url" => "https://api.example.com"}]}
      ...>
      ...> AshOaskit.SpecModifier.add_server(spec, "https://staging.example.com",
      ...>   description: "Staging"
      ...> )
      %{
        "servers" => [
          %{"url" => "https://api.example.com"},
          %{"url" => "https://staging.example.com", "description" => "Staging"}
        ]
      }
  """
  @spec add_server(map(), String.t(), keyword()) :: map()
  def add_server(spec, url, opts \\ []) do
    description = Keyword.get(opts, :description)
    variables = Keyword.get(opts, :variables)

    server = %{"url" => url}
    server = if description, do: Map.put(server, "description", description), else: server
    server = if variables, do: Map.put(server, "variables", variables), else: server

    servers = Map.get(spec, "servers", [])
    Map.put(spec, "servers", servers ++ [server])
  end

  @doc """
  Replaces the servers list in the spec.

  Useful for environment-specific server configuration.

  ## Examples

      iex> spec = %{"servers" => [%{"url" => "/"}]}
      ...> servers = [%{"url" => "https://api.prod.example.com"}]
      ...> AshOaskit.SpecModifier.set_servers(spec, servers)
      %{"servers" => [%{"url" => "https://api.prod.example.com"}]}
  """
  @spec set_servers(map(), list(map())) :: map()
  def set_servers(spec, servers) when is_list(servers) do
    Map.put(spec, "servers", servers)
  end

  @doc """
  Adds a tag to the spec's tags list.

  Tags are used to group operations in documentation tools.

  ## Examples

      iex> spec = %{"tags" => [%{"name" => "Posts"}]}
      ...> AshOaskit.SpecModifier.add_tag(spec, "Comments", description: "Comment operations")
      %{
        "tags" => [
          %{"name" => "Posts"},
          %{"name" => "Comments", "description" => "Comment operations"}
        ]
      }
  """
  @spec add_tag(map(), String.t(), keyword()) :: map()
  def add_tag(spec, name, opts \\ []) do
    description = Keyword.get(opts, :description)
    external_docs = Keyword.get(opts, :external_docs)

    tag = %{"name" => name}
    tag = if description, do: Map.put(tag, "description", description), else: tag
    tag = if external_docs, do: Map.put(tag, "externalDocs", external_docs), else: tag

    tags = Map.get(spec, "tags", [])
    Map.put(spec, "tags", tags ++ [tag])
  end

  @doc """
  Adds external documentation link to the spec.

  ## Examples

      iex> spec = %{"info" => %{"title" => "API"}}
      ...>
      ...> AshOaskit.SpecModifier.add_external_docs(spec, "https://docs.example.com",
      ...>   description: "Full documentation"
      ...> )
      %{
        "info" => %{"title" => "API"},
        "externalDocs" => %{
          "url" => "https://docs.example.com",
          "description" => "Full documentation"
        }
      }
  """
  @spec add_external_docs(map(), String.t(), keyword()) :: map()
  def add_external_docs(spec, url, opts \\ []) do
    description = Keyword.get(opts, :description)

    external_docs = %{"url" => url}

    external_docs =
      if description, do: Map.put(external_docs, "description", description), else: external_docs

    Map.put(spec, "externalDocs", external_docs)
  end

  @doc """
  Adds or updates a schema in the components section.

  ## Examples

      iex> spec = %{"components" => %{"schemas" => %{}}}
      ...> schema = %{"type" => "object", "properties" => %{"id" => %{"type" => "string"}}}
      ...> AshOaskit.SpecModifier.add_schema(spec, "CustomResource", schema)
      %{"components" => %{"schemas" => %{"CustomResource" => %{...}}}}
  """
  @spec add_schema(map(), String.t(), map()) :: map()
  def add_schema(spec, name, schema) do
    components = Map.get(spec, "components", %{})
    schemas = Map.get(components, "schemas", %{})
    updated_schemas = Map.put(schemas, name, schema)
    updated_components = Map.put(components, "schemas", updated_schemas)
    Map.put(spec, "components", updated_components)
  end

  @doc """
  Adds a response definition to the components section.

  ## Examples

      iex> spec = %{"components" => %{}}
      ...> response = %{"description" => "Rate limit exceeded"}
      ...> AshOaskit.SpecModifier.add_response(spec, "RateLimitError", response)
  """
  @spec add_response(map(), String.t(), map()) :: map()
  def add_response(spec, name, response) do
    components = Map.get(spec, "components", %{})
    responses = Map.get(components, "responses", %{})
    updated_responses = Map.put(responses, name, response)
    updated_components = Map.put(components, "responses", updated_responses)
    Map.put(spec, "components", updated_components)
  end

  @doc """
  Adds a parameter definition to the components section.

  ## Examples

      iex> spec = %{"components" => %{}}
      ...> param = %{"name" => "page", "in" => "query", "schema" => %{"type" => "integer"}}
      ...> AshOaskit.SpecModifier.add_parameter(spec, "PageParam", param)
  """
  @spec add_parameter(map(), String.t(), map()) :: map()
  def add_parameter(spec, name, parameter) do
    components = Map.get(spec, "components", %{})
    parameters = Map.get(components, "parameters", %{})
    updated_parameters = Map.put(parameters, name, parameter)
    updated_components = Map.put(components, "parameters", updated_parameters)
    Map.put(spec, "components", updated_components)
  end

  @doc """
  Adds a webhook definition to the spec.

  Webhooks are callbacks that the API can send to client-specified URLs.

  ## Examples

      iex> spec = %{}
      ...>
      ...> webhook = %{
      ...>   "post" => %{
      ...>     "summary" => "New post created",
      ...>     "requestBody" => %{...}
      ...>   }
      ...> }
      ...>
      ...> AshOaskit.SpecModifier.add_webhook(spec, "newPost", webhook)
  """
  @spec add_webhook(map(), String.t(), map()) :: map()
  def add_webhook(spec, name, webhook) do
    webhooks = Map.get(spec, "webhooks", %{})
    updated_webhooks = Map.put(webhooks, name, webhook)
    Map.put(spec, "webhooks", updated_webhooks)
  end

  @doc """
  Modifies the info section of the spec.

  ## Examples

      iex> spec = %{"info" => %{"title" => "API", "version" => "1.0"}}
      ...>
      ...> AshOaskit.SpecModifier.update_info(spec, %{
      ...>   "contact" => %{"email" => "support@example.com"},
      ...>   "license" => %{"name" => "MIT"}
      ...> })
  """
  @spec update_info(map(), map()) :: map()
  def update_info(spec, info_updates) do
    info = Map.get(spec, "info", %{})
    updated_info = Map.merge(info, info_updates)
    Map.put(spec, "info", updated_info)
  end

  @doc """
  Adds examples to a schema in the components section.

  ## Examples

      iex> spec = %{"components" => %{"schemas" => %{"Post" => %{"type" => "object"}}}}
      ...> examples = [%{"id" => "1", "title" => "Hello World"}]
      ...> AshOaskit.SpecModifier.add_schema_examples(spec, "Post", examples)
  """
  @spec add_schema_examples(map(), String.t(), list(map())) :: map()
  def add_schema_examples(spec, schema_name, examples) do
    path = ["components", "schemas", schema_name]

    case get_in_path(spec, path) do
      nil ->
        spec

      schema ->
        updated_schema = Map.put(schema, "examples", examples)
        put_in_path(spec, path, updated_schema)
    end
  end

  @doc """
  Adds an example to an operation.

  ## Examples

      iex> spec = %{"paths" => %{"/posts" => %{"get" => %{"operationId" => "listPosts"}}}}
      ...> example = %{"summary" => "List posts", "value" => %{"data" => []}}
      ...>
      ...> AshOaskit.SpecModifier.add_operation_example(
      ...>   spec,
      ...>   "listPosts",
      ...>   "application/json",
      ...>   example
      ...> )
  """
  @spec add_operation_example(map(), String.t(), String.t(), map()) :: map()
  def add_operation_example(spec, operation_id, media_type, example) do
    update_operations(spec, [operation_id], fn operation ->
      responses = Map.get(operation, "responses", %{})

      updated_responses =
        Enum.reduce(responses, %{}, fn {code, response}, acc ->
          content = Map.get(response, "content", %{})
          media = Map.get(content, media_type, %{})
          examples = Map.get(media, "examples", %{})

          example_key = example["summary"] || "example_#{map_size(examples) + 1}"
          updated_examples = Map.put(examples, example_key, example)
          updated_media = Map.put(media, "examples", updated_examples)
          updated_content = Map.put(content, media_type, updated_media)
          updated_response = Map.put(response, "content", updated_content)

          Map.put(acc, code, updated_response)
        end)

      Map.put(operation, "responses", updated_responses)
    end)
  end

  @doc """
  Creates a modifier function that adds rate limiting information.

  This is a convenience function that creates a modifier for common
  rate limiting documentation patterns.

  ## Options

  - `:limit` - Rate limit value (e.g., 100)
  - `:window` - Time window (e.g., "1 minute")
  - `:headers` - Custom header names for rate limit info

  ## Examples

      iex> modifier = AshOaskit.SpecModifier.rate_limiting_modifier(limit: 100, window: "1 minute")
      ...> spec = %{"paths" => %{"/posts" => %{"get" => %{}}}}
      ...> AshOaskit.SpecModifier.apply_modifier(spec, modifier)
  """
  @spec rate_limiting_modifier(keyword()) :: (map() -> map())
  def rate_limiting_modifier(opts \\ []) do
    limit = Keyword.get(opts, :limit, 100)
    window = Keyword.get(opts, :window, "1 minute")

    fn spec ->
      spec
      |> add_extension(["info"], "x-rateLimit", %{
        "limit" => limit,
        "window" => window
      })
      |> add_header_to_operations("X-RateLimit-Limit", %{"type" => "integer"})
      |> add_header_to_operations("X-RateLimit-Remaining", %{"type" => "integer"})
      |> add_header_to_operations("X-RateLimit-Reset", %{"type" => "integer"})
    end
  end

  @doc """
  Creates a modifier function that adds deprecation notices to operations.

  ## Examples

      iex> modifier =
      ...>   AshOaskit.SpecModifier.deprecation_modifier(
      ...>     operations: ["oldGetPosts"],
      ...>     message: "Use listPosts instead",
      ...>     sunset: "2024-12-31"
      ...>   )
  """
  @spec deprecation_modifier(keyword()) :: (map() -> map())
  def deprecation_modifier(opts \\ []) do
    operation_ids = Keyword.get(opts, :operations, [])
    message = Keyword.get(opts, :message, "This operation is deprecated")
    sunset = Keyword.get(opts, :sunset)

    fn spec ->
      update_operations(spec, operation_ids, fn operation ->
        operation = Map.put(operation, "deprecated", true)

        updated_description =
          String.trim(Map.get(operation, "description", "") <> "\n\n**Deprecated:** #{message}")

        operation = Map.put(operation, "description", updated_description)

        if sunset do
          Map.put(operation, "x-sunset", sunset)
        else
          operation
        end
      end)
    end
  end

  # Private helper functions

  @spec update_operations(map(), list(String.t()) | nil, (map() -> map())) :: map()
  defp update_operations(spec, operation_ids, update_fn) do
    paths = Map.get(spec, "paths", %{})

    updated_paths =
      Enum.reduce(paths, %{}, fn {path, methods}, acc ->
        updated_methods =
          Enum.reduce(methods, %{}, fn {method, operation}, method_acc ->
            should_update =
              is_nil(operation_ids) or
                Map.get(operation, "operationId") in operation_ids

            updated_operation =
              if should_update and is_map(operation) do
                update_fn.(operation)
              else
                operation
              end

            Map.put(method_acc, method, updated_operation)
          end)

        Map.put(acc, path, updated_methods)
      end)

    Map.put(spec, "paths", updated_paths)
  end

  @spec put_in_path(map(), list(String.t()), any()) :: map()
  defp put_in_path(map, [key], value) do
    Map.put(map, key, value)
  end

  defp put_in_path(map, [key | rest], value) do
    nested = Map.get(map, key, %{})
    Map.put(map, key, put_in_path(nested, rest, value))
  end

  @spec get_in_path(map(), list(String.t())) :: any()
  defp get_in_path(map, [key]) do
    Map.get(map, key)
  end

  defp get_in_path(map, [key | rest]) do
    case Map.get(map, key) do
      nil -> nil
      nested -> get_in_path(nested, rest)
    end
  end
end
