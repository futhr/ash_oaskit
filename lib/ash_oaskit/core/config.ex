defmodule AshOaskit.Config do
  @moduledoc """
  Retrieves and normalizes configuration from AshJsonApi DSL.

  This module provides a unified interface for accessing configuration options
  defined in Ash domains and resources through the AshJsonApi DSL.

  ## Domain-Level Configuration

  Domain-level configuration is retrieved via `AshJsonApi.Domain.Info`:

  - `tag/1` - Custom OpenAPI tag for the domain
  - `group_by/1` - How operations should be grouped (e.g., by resource)
  - `prefix/1` - Route prefix for all resources in the domain

  ## Resource-Level Configuration

  Resource-level configuration is retrieved via `AshJsonApi.Resource.Info`:

  - `type/1` - JSON:API type name (defaults to underscored resource name)
  - `derive_filter?/1` - Whether to auto-generate filter schemas
  - `derive_sort?/1` - Whether to auto-generate sort schemas
  - `default_fields/1` - Default fields to include in responses
  - `includes/1` - Available relationship includes

  ## Usage

      # Get the JSON:API type for a resource
      type = Config.resource_type(MyApp.Post)
      # => "post"

      # Check if filtering should be derived
      if Config.derive_filter?(MyApp.Post) do
        # Generate filter schema
      end

      # Get route prefix for a domain
      prefix = Config.route_prefix(MyApp.Blog)
      # => "/api/v1"

  ## Error Handling

  Functions in this module follow the "let it crash" philosophy. If called
  with an invalid module (not an Ash resource or domain), they will raise
  an error. This is intentional - configuration errors should fail loudly
  rather than silently returning defaults.
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
    case AshJsonApi.Resource.Info.type(resource) do
      nil -> default_type(resource)
      type -> type
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
    AshJsonApi.Resource.Info.derive_filter?(resource)
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
    AshJsonApi.Resource.Info.derive_sort?(resource)
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
    AshJsonApi.Resource.Info.default_fields(resource)
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
    AshJsonApi.Resource.Info.includes(resource)
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
    AshJsonApi.Domain.Info.tag(domain)
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
    AshJsonApi.Domain.Info.prefix(domain) || ""
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
    AshJsonApi.Domain.Info.group_by(domain)
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
    AshJsonApi.Domain.Info.routes(domain)
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

  Returns only non-private attributes that should be included in
  OpenAPI schemas.

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

  defp default_type(resource) do
    resource
    |> Module.split()
    |> List.last()
    |> Macro.underscore()
  end
end
