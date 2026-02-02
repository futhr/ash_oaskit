defmodule AshOaskit.Generators.Generator do
  @moduledoc """
  Main OpenAPI specification generator.

  This module orchestrates the generation of complete OpenAPI specifications
  from Ash domains, delegating to specialized builders for each section.

  ## Overview

  The generator produces a complete OpenAPI document with:

  - **openapi** - Version string ("3.0.0" or "3.1.0")
  - **info** - API metadata (title, version, description)
  - **servers** - Server URLs for the API
  - **paths** - All operations organized by path
  - **components** - Reusable schemas
  - **tags** - Resource groupings
  - **security** - Optional security requirements

  ## Module Delegation

  The generator delegates to focused builders:

  - `InfoBuilder` - Info object, servers, and tags
  - `PathBuilder` - Paths and operations
  - `PhoenixIntrospection` - Controller route extraction (optional)
  - `ComponentsBuilder` - Schemas (internal to this module)

  ## Usage

      spec = Generator.generate([MyApp.Domain], version: "3.1", title: "My API")

  ## Options

  | Option | Type | Description |
  |--------|------|-------------|
  | `:version` | `"3.0"` or `"3.1"` | OpenAPI version (required) |
  | `:title` | string | API title |
  | `:api_version` | string | API version |
  | `:description` | string | API description |
  | `:terms_of_service` | string | Terms URL |
  | `:contact` | map | Contact info |
  | `:license` | map | License info |
  | `:servers` | list | Server URLs |
  | `:security` | list | Security requirements |
  | `:router` | module | Phoenix router for controller introspection |
  | `:modify_open_api` | function or MFA | Post-processing hook for spec customization |
  """

  import AshOaskit.Core.SchemaRef, only: [schema_ref: 1]

  alias AshOaskit.Generators.InfoBuilder
  alias AshOaskit.Generators.PathBuilder
  alias AshOaskit.PhoenixIntrospection
  alias AshOaskit.TypeMapper

  require Logger

  @type opts :: keyword()

  @doc """
  Generate an OpenAPI specification from the given domains.

  ## Parameters

  - `domains` - List of Ash domain modules to include in the spec
  - `opts` - Generation options (see module docs)

  ## Returns

  A complete OpenAPI specification as a map.

  ## Examples

      iex> Generator.generate([MyApp.Blog], version: "3.1")
      %{
        "openapi" => "3.1.0",
        "info" => %{"title" => "API", "version" => "1.0.0"},
        "servers" => [%{"url" => "/"}],
        "paths" => %{...},
        "components" => %{"schemas" => %{...}},
        "tags" => [%{"name" => "Post"}, ...]
      }

      # With Phoenix router for controller routes
      iex> Generator.generate([MyApp.Blog], version: "3.1", router: MyAppWeb.Router)

      # With post-processing hook
      iex> Generator.generate([MyApp.Blog],
      ...>   version: "3.1",
      ...>   modify_open_api: fn spec -> Map.put(spec, "x-custom", true) end
      ...> )
  """
  @spec generate(list(module()), opts()) :: map()
  def generate(domains, opts) do
    version = Keyword.fetch!(opts, :version)
    openapi_version = if version == "3.0", do: "3.0.0", else: "3.1.0"

    %{
      openapi: openapi_version,
      info: InfoBuilder.build_info(opts),
      servers: InfoBuilder.build_servers(opts),
      paths: PathBuilder.build_paths(domains, opts),
      components: build_components(domains, opts),
      tags: build_all_tags(domains, opts),
      security: Keyword.get(opts, :security)
    }
    |> reject_nil_values()
    |> apply_modify_hook(opts)
  end

  @doc """
  Builds components (schemas) from domains.

  Generates schema definitions for all resources in the provided domains,
  using the appropriate type mapper for the OpenAPI version.

  ## Parameters

  - `domains` - List of Ash domain modules
  - `opts` - Options including `:version`

  ## Returns

  A components object containing schemas.
  """
  @spec build_components(list(module()), opts()) :: map()
  def build_components(domains, opts) do
    version = Keyword.fetch!(opts, :version)

    schemas =
      domains
      |> Enum.flat_map(&get_domain_resources/1)
      |> Enum.flat_map(&build_resource_schemas(&1, version))
      |> Map.new()

    %{schemas: schemas}
  end

  # Builds all tags from domains and optionally from router
  defp build_all_tags(domains, opts) do
    domain_tags = InfoBuilder.build_tags(domains)

    controller_tags =
      case Keyword.get(opts, :router) do
        nil -> []
        router -> PhoenixIntrospection.extract_tags(router)
      end

    merged_tags = domain_tags ++ controller_tags

    case merged_tags do
      [] -> nil
      tags -> Enum.uniq_by(tags, &(&1[:name] || &1["name"]))
    end
  end

  # Applies the modify_open_api hook if provided
  defp apply_modify_hook(spec, opts) do
    case Keyword.get(opts, :modify_open_api) do
      nil ->
        spec

      {mod, fun, args} when is_atom(mod) and is_atom(fun) and is_list(args) ->
        apply(mod, fun, [spec | args])

      fun when is_function(fun, 1) ->
        fun.(spec)

      other ->
        Logger.warning("AshOaskit: ignoring invalid modify_open_api hook: #{inspect(other)}")
        spec
    end
  end

  # Gets all resources from a domain
  defp get_domain_resources(domain) do
    Ash.Domain.Info.resources(domain)
  end

  # Builds attribute and response schemas for a resource
  defp build_resource_schemas(resource, version) do
    schema_name =
      resource
      |> Module.split()
      |> List.last()

    attributes = get_resource_attributes(resource)

    attributes_schema = %{
      type: :object,
      properties: build_attribute_properties(attributes, version)
    }

    response_schema = %{
      type: :object,
      properties: %{
        data: %{
          type: :object,
          properties: %{
            id: %{type: :string},
            type: %{type: :string},
            attributes: schema_ref("#{schema_name}Attributes")
          }
        }
      }
    }

    [
      {"#{schema_name}Attributes", attributes_schema},
      {"#{schema_name}Response", response_schema}
    ]
  end

  # Gets attributes from a resource
  defp get_resource_attributes(resource) do
    Ash.Resource.Info.attributes(resource)
  end

  # Builds attribute properties using the appropriate type mapper
  defp build_attribute_properties(attributes, version) do
    type_mapper_fn =
      if version == "3.0",
        do: &TypeMapper.to_json_schema_30/1,
        else: &TypeMapper.to_json_schema_31/1

    attributes
    |> Enum.reject(fn attr ->
      attr.name in [:id, :inserted_at, :updated_at] or
        Map.get(attr, :private?, false)
    end)
    |> Enum.map(fn attr ->
      {to_string(attr.name), type_mapper_fn.(attr)}
    end)
    |> Map.new()
  end

  # Removes nil values from a map
  defp reject_nil_values(map) do
    map
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end
end
