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
    Logger.warning(fn -> "AshOaskit: ignoring invalid spec modifier: #{inspect(invalid)}" end)
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
    put_spec_value(spec, path ++ [extension_name], value)
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
    operation_ids = Keyword.get(opts, :operations)
    normalized_name = String.downcase(header_name)

    header_param = %{
      "name" => header_name,
      "in" => "header",
      "required" => Keyword.get(opts, :required, false),
      "schema" => schema
    }

    update_operations(spec, operation_ids, fn operation ->
      Map.update(operation, "parameters", [header_param], fn params ->
        Enum.reject(params, &matching_header?(&1, normalized_name)) ++ [header_param]
      end)
    end)
  end

  @doc "Adds a response header to inline responses without changing request parameters or references."
  @spec add_header_to_responses(map(), String.t(), map(), keyword()) :: map()
  def add_header_to_responses(spec, name, schema, opts \\ []) do
    update_operations(spec, Keyword.get(opts, :operations), fn operation ->
      update_responses(operation, &add_response_header(&1, name, schema))
    end)
  end

  defp add_response_header(%{"$ref" => _} = response, _, _), do: response

  defp add_response_header(response, name, schema) when is_map(response) do
    Map.update(
      response,
      "headers",
      %{name => %{"schema" => schema}},
      &Map.put(&1, name, %{"schema" => schema})
    )
  end

  defp add_response_header(response, _, _), do: response

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
    server =
      %{"url" => url}
      |> maybe_put("description", Keyword.get(opts, :description))
      |> maybe_put("variables", Keyword.get(opts, :variables))

    spec
    |> normalize_spec()
    |> Map.update("servers", [server], &(&1 ++ [server]))
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
    spec
    |> normalize_spec()
    |> Map.put("servers", servers)
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
    tag =
      %{"name" => name}
      |> maybe_put("description", Keyword.get(opts, :description))
      |> maybe_put("externalDocs", Keyword.get(opts, :external_docs))

    spec
    |> normalize_spec()
    |> Map.update("tags", [tag], &(&1 ++ [tag]))
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
    external_docs = maybe_put(%{"url" => url}, "description", Keyword.get(opts, :description))

    spec
    |> normalize_spec()
    |> Map.put("externalDocs", external_docs)
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
    put_spec_value(spec, ["components", "schemas", name], schema)
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
    put_spec_value(spec, ["components", "responses", name], response)
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
    put_spec_value(spec, ["components", "parameters", name], parameter)
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
    put_spec_value(spec, ["webhooks", name], webhook)
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
    spec
    |> normalize_spec()
    |> Map.update("info", info_updates, &Map.merge(&1, info_updates))
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
    spec = normalize_spec(spec)
    path = ["components", "schemas", schema_name]

    case get_in(spec, path) do
      nil ->
        spec

      schema ->
        put_in(spec, path, Map.put(schema, "examples", examples))
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
      update_responses(operation, &add_response_example(&1, media_type, example))
    end)
  end

  @doc """
  Creates a modifier function that adds rate limiting information.

  This is a convenience function that creates a modifier for common
  rate limiting documentation patterns.

  ## Options

  - `:limit` - Rate limit value (e.g., 100)
  - `:window` - Time window (e.g., "1 minute")
  - `:headers` - Map of custom names keyed by `:limit`, `:remaining`, and `:reset`

  ## Examples

      iex> modifier = AshOaskit.SpecModifier.rate_limiting_modifier(limit: 100, window: "1 minute")
      ...> spec = %{"paths" => %{"/posts" => %{"get" => %{}}}}
      ...> AshOaskit.SpecModifier.apply_modifier(spec, modifier)
  """
  @spec rate_limiting_modifier(keyword()) :: (map() -> map())
  def rate_limiting_modifier(opts \\ []) do
    limit = Keyword.get(opts, :limit, 100)
    window = Keyword.get(opts, :window, "1 minute")
    headers = Keyword.get(opts, :headers, %{})

    fn spec ->
      spec
      |> add_extension(["info"], "x-rateLimit", %{
        "limit" => limit,
        "window" => window
      })
      |> add_header_to_responses(Map.get(headers, :limit, "X-RateLimit-Limit"), %{
        "type" => "integer"
      })
      |> add_header_to_responses(Map.get(headers, :remaining, "X-RateLimit-Remaining"), %{
        "type" => "integer"
      })
      |> add_header_to_responses(Map.get(headers, :reset, "X-RateLimit-Reset"), %{
        "type" => "integer"
      })
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
      update_operations(spec, operation_ids, &deprecate_operation(&1, message, sunset))
    end
  end

  defp matching_header?(%{"in" => "header"} = param, name) do
    String.downcase(param["name"] || "") == name
  end

  defp matching_header?(_, _), do: false

  defp put_spec_value(spec, path, value) do
    spec
    |> normalize_spec()
    |> put_in(Enum.map(path, &Access.key(&1, %{})), value)
  end

  defp update_responses(operation, update_fn) do
    Map.update(operation, "responses", %{}, fn responses ->
      Map.new(responses, fn {code, response} -> {code, update_fn.(response)} end)
    end)
  end

  defp add_response_example(response, media_type, example) do
    path = Enum.map(["content", media_type, "examples"], &Access.key(&1, %{}))

    update_in(response, path, fn examples ->
      name = example["summary"] || "example_#{map_size(examples) + 1}"
      Map.put(examples, name, example)
    end)
  end

  defp deprecate_operation(operation, message, sunset) do
    operation
    |> Map.put("deprecated", true)
    |> put_deprecation_description(message)
    |> maybe_put("x-sunset", sunset)
  end

  defp put_deprecation_description(operation, message) do
    updated_description =
      String.trim(Map.get(operation, "description", "") <> "\n\n**Deprecated:** #{message}")

    Map.put(operation, "description", updated_description)
  end

  @spec update_operations(map(), list(String.t()) | nil, (map() -> map())) :: map()
  defp update_operations(spec, operation_ids, update_fn) do
    spec
    |> normalize_spec()
    |> Map.update("paths", %{}, fn paths ->
      Map.new(paths, fn {path, methods} ->
        {path, update_methods(methods, operation_ids, update_fn)}
      end)
    end)
  end

  defp update_methods(methods, operation_ids, update_fn) do
    Map.new(methods, fn
      {method, operation} when method in ~w(get put post delete options head patch trace) ->
        {method, maybe_update_operation(operation, operation_ids, update_fn)}

      entry ->
        entry
    end)
  end

  defp maybe_update_operation(operation, nil, update_fn) when is_map(operation) do
    update_fn.(operation)
  end

  defp maybe_update_operation(operation, operation_ids, update_fn)
       when is_map(operation) do
    if Map.get(operation, "operationId") in operation_ids do
      update_fn.(operation)
    else
      operation
    end
  end

  defp maybe_update_operation(operation, _, _), do: operation

  defp normalize_spec(%{openapi: _} = spec),
    do: spec |> AshOaskit.Core.JsonKeys.validate!() |> Oaskit.normalize_spec!()

  defp normalize_spec(spec), do: AshOaskit.Core.JsonKeys.validate!(spec)

  defp maybe_put(map, _, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
