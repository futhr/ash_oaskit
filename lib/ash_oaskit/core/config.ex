defmodule AshOaskit.Config do
  @moduledoc """
  Reads the Ash and AshJsonApi metadata used during spec generation.

  AshJsonApi is optional. Plain Ash resources keep their Elixir field names,
  filters and sorting remain enabled, and domains without `AshJsonApi.Domain`
  contribute no routes. Invalid resource or domain modules still raise through
  Ash's introspection APIs so configuration mistakes are visible early.
  """

  @doc """
  Gets the JSON:API type name for a resource.

  The type is used in JSON:API responses as the `type` field and in
  route generation. If not explicitly configured, defaults to the
  underscored resource module name.

  ## Parameters

    - `resource` - The Ash resource module

  ## Returns

    The JSON:API type as a string.

  ## Examples

      iex> Config.resource_type(MyApp.BlogPost)
      "blog_post"

      iex> Config.resource_type(MyApp.User)
      "user"

  """
  @spec resource_type(module()) :: String.t()
  def resource_type(resource) do
    case json_api_type(resource) do
      nil -> default_type(resource)
      type -> type
    end
  end

  @doc """
  Returns the PascalCase display name for a resource, used to build schema
  and tag names.

  Derives from the resource's declared JSON:API type when present — so a
  deeply nested module like `MyApp.Reconciliation.State` with
  `type "reconciliation-state"` names its schemas `ReconciliationState*`
  instead of the ambiguous `State*`. Falls back to the module's short name
  when no type is declared.

  ## Examples

      iex> AshOaskit.Config.resource_display_name(MyApp.Blog.Post)
      "Post"

  """
  @spec resource_display_name(module()) :: String.t()
  def resource_display_name(resource) do
    case json_api_type(resource) do
      nil ->
        resource |> Module.split() |> List.last()

      type ->
        type |> to_string() |> String.replace("-", "_") |> Macro.camelize()
    end
  end

  @doc """
  Returns the JSON:API field name for a resource field.

  Applies the resource's `field_names` mapping when the resource uses
  `AshJsonApi.Resource`; otherwise falls back to the atom/string name.
  """
  @spec json_field_name(module(), atom() | String.t()) :: String.t()
  def json_field_name(resource, field_name) do
    if json_api_resource?(resource) do
      AshJsonApi.Resource.Info.field_to_json_key(resource, field_name)
    else
      to_string(field_name)
    end
  end

  @doc """
  Returns the JSON:API argument name for an action argument.

  Applies the resource's `argument_names` mapping when the resource uses
  `AshJsonApi.Resource`; otherwise falls back to the atom/string name.
  """
  @spec json_argument_name(module(), atom(), atom() | String.t()) :: String.t()
  def json_argument_name(resource, action_name, argument_name) do
    if json_api_resource?(resource) do
      AshJsonApi.Resource.Info.argument_to_json_key(resource, action_name, argument_name)
    else
      to_string(argument_name)
    end
  end

  @doc """
  Returns whether a field should be exposed in JSON:API output and specs.

  Applies `hide_fields`/`show_fields` for AshJsonApi resources and defaults
  to true for plain Ash resources.
  """
  @spec show_field?(module(), atom() | map()) :: boolean()
  def show_field?(resource, field) do
    if json_api_resource?(resource) do
      AshJsonApi.Resource.Info.show_field?(resource, field)
    else
      true
    end
  end

  @doc """
  Checks whether filter schemas should be auto-derived for a resource.

  When enabled, the OpenAPI generator will create detailed filter
  parameter schemas based on the resource's attributes.

  ## Parameters

    - `resource` - The Ash resource module

  ## Returns

    Boolean indicating if filter derivation is enabled.

  ## Examples

      iex> Config.derive_filter?(MyApp.Post)
      true

  """
  @spec derive_filter?(module()) :: boolean()
  def derive_filter?(resource) do
    if json_api_resource?(resource) do
      AshJsonApi.Resource.Info.derive_filter?(resource) != false
    else
      true
    end
  end

  @doc """
  Checks whether sort schemas should be auto-derived for a resource.

  When enabled, the OpenAPI generator will create sort parameter
  schemas listing all sortable fields.

  ## Parameters

    - `resource` - The Ash resource module

  ## Returns

    Boolean indicating if sort derivation is enabled.

  ## Examples

      iex> Config.derive_sort?(MyApp.Post)
      true

  """
  @spec derive_sort?(module()) :: boolean()
  def derive_sort?(resource) do
    if json_api_resource?(resource) do
      AshJsonApi.Resource.Info.derive_sort?(resource) != false
    else
      true
    end
  end

  @doc """
  Gets the default fields to include in responses for a resource.

  If configured, responses will only include the specified fields
  unless the client requests additional fields via sparse fieldsets.

  ## Parameters

    - `resource` - The Ash resource module

  ## Returns

    List of field names (as atoms) or `nil` for all fields.

  ## Examples

      iex> Config.default_fields(MyApp.Post)
      [:id, :title, :body]

      iex> Config.default_fields(MyApp.Comment)
      nil

  """
  @spec default_fields(module()) :: [atom()] | nil
  def default_fields(resource) do
    if json_api_resource?(resource) do
      AshJsonApi.Resource.Info.default_fields(resource)
    end
  end

  @doc """
  Gets the available relationship includes for a resource.

  Defines which relationships can be included via the `include`
  query parameter. Returns `nil` if not configured.

  ## Parameters

    - `resource` - The Ash resource module

  ## Returns

    List of includable relationship paths, or `nil` if not configured.

  ## Examples

      iex> Config.includes(MyApp.Post)
      [:author, :comments, "comments.author"]

  """
  @spec includes(module()) :: [atom() | String.t()] | nil
  def includes(resource) do
    if json_api_resource?(resource) do
      AshJsonApi.Resource.Info.includes(resource)
    end
  end

  @doc """
  Gets the primary key field name(s) for a resource.

  ## Parameters

    - `resource` - The Ash resource module

  ## Returns

    List of primary key field names (as atoms).

  ## Examples

      iex> Config.primary_key(MyApp.Post)
      [:id]

  """
  @spec primary_key(module()) :: [atom()]
  def primary_key(resource) do
    Ash.Resource.Info.primary_key(resource)
  end

  @doc """
  Gets the OpenAPI tag for a domain.

  Tags are used to group operations in OpenAPI documentation tools
  like Swagger UI.

  ## Parameters

    - `domain` - The Ash domain module

  ## Returns

    The tag name as a string, or `nil` if not configured.

  ## Examples

      iex> Config.domain_tag(MyApp.Blog)
      "Blog"

  """
  @spec domain_tag(module()) :: String.t() | nil
  def domain_tag(domain) do
    if json_api_domain?(domain) do
      AshJsonApi.Domain.Info.tag(domain)
    end
  end

  @doc """
  Gets the route prefix for a domain.

  The prefix is prepended to all resource routes in the domain.

  ## Parameters

    - `domain` - The Ash domain module

  ## Returns

    The route prefix as a string (empty string if not configured).

  ## Examples

      iex> Config.route_prefix(MyApp.Blog)
      "/api/v1"

      iex> Config.route_prefix(MyApp.Admin)
      "/admin"

  """
  @spec route_prefix(module()) :: String.t()
  def route_prefix(domain) do
    if json_api_domain?(domain) do
      AshJsonApi.Domain.Info.prefix(domain) || ""
    else
      ""
    end
  end

  @doc """
  Gets the operation grouping strategy for a domain.

  Determines how operations are grouped in the OpenAPI spec.

  ## Parameters

    - `domain` - The Ash domain module

  ## Returns

    The grouping strategy atom (e.g., `:resource`, `:domain`), or `nil`.

  ## Examples

      iex> Config.group_by(MyApp.Blog)
      :resource

  """
  @spec group_by(module()) :: atom() | nil
  def group_by(domain) do
    if json_api_domain?(domain) do
      AshJsonApi.Domain.Info.group_by(domain)
    end
  end

  @doc """
  Gets all resources in a domain.

  ## Parameters

    - `domain` - The Ash domain module

  ## Returns

    List of resource modules.

  ## Examples

      iex> Config.domain_resources(MyApp.Blog)
      [MyApp.Post, MyApp.Comment, MyApp.Author]

  """
  @spec domain_resources(module()) :: [module()]
  def domain_resources(domain) do
    Ash.Domain.Info.resources(domain)
  end

  @doc """
  Gets the JSON:API routes for a domain.

  ## Parameters

    - `domain` - The Ash domain module

  ## Returns

    List of route structs.

  ## Examples

      Config.domain_routes(MyApp.Blog)
      # => [%{type: :index, ...}, %{type: :get, ...}, ...]

  """
  @spec domain_routes(module()) :: [map()]
  def domain_routes(domain) do
    AshOaskit.RouteGathering.domain_routes(domain)
  end

  @doc """
  Gets the actions for a resource.

  ## Parameters

    - `resource` - The Ash resource module

  ## Returns

    List of action structs.

  """
  @spec resource_actions(module()) :: [map()]
  def resource_actions(resource) do
    Ash.Resource.Info.actions(resource)
  end

  @doc """
  Gets a specific action for a resource by name.

  ## Parameters

    - `resource` - The Ash resource module
    - `action_name` - The action name (atom)

  ## Returns

    The action struct or `nil` if not found.

  """
  @spec resource_action(module(), atom()) :: map() | nil
  def resource_action(resource, action_name) do
    Ash.Resource.Info.action(resource, action_name)
  end

  @doc """
  Gets the public attributes for a resource.

  Returns only attributes marked `public? true`, which are the ones
  that belong in OpenAPI schemas.

  ## Parameters

    - `resource` - The Ash resource module

  ## Returns

    List of attribute structs.

  """
  @spec public_attributes(module()) :: [map()]
  def public_attributes(resource) do
    Ash.Resource.Info.public_attributes(resource)
  end

  @doc """
  Gets the relationships for a resource.

  ## Parameters

    - `resource` - The Ash resource module

  ## Returns

    List of relationship structs.

  """
  @spec relationships(module()) :: [map()]
  def relationships(resource) do
    Ash.Resource.Info.relationships(resource)
  end

  @doc """
  Gets a specific relationship for a resource by name.

  ## Parameters

    - `resource` - The Ash resource module
    - `name` - The relationship name (atom)

  ## Returns

    The relationship struct or `nil` if not found.

  """
  @spec relationship(module(), atom()) :: map() | nil
  def relationship(resource, name) do
    Ash.Resource.Info.relationship(resource, name)
  end

  defp json_api_type(resource) do
    if json_api_resource?(resource) do
      AshJsonApi.Resource.Info.type(resource)
    end
  end

  defp json_api_resource?(resource) do
    Code.ensure_loaded?(AshJsonApi.Resource.Info) and
      Ash.Resource.Info.resource?(resource) and
      AshJsonApi.Resource in Spark.extensions(resource)
  end

  defp json_api_domain?(domain) do
    Code.ensure_loaded?(AshJsonApi.Domain.Info) and
      AshJsonApi.Domain in Spark.extensions(domain)
  end

  defp default_type(resource) do
    resource
    |> Module.split()
    |> List.last()
    |> Macro.underscore()
  end
end
