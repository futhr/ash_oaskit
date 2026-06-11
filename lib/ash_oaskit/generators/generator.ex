defmodule AshOaskit.Generators.Generator do
  @moduledoc """
  Main OpenAPI specification generator.

  This module orchestrates the generation of complete OpenAPI specifications
  from Ash domains, delegating to specialized builders for each section.

  ## Overview

  The generator produces a complete OpenAPI document with:

  - **openapi** - Version string ("3.0.3" or "3.1.0")
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
  | `:resource_scope` | `:all` or `:routed` | Which resources seed schemas and tags (default `:all`) |

  ## Resource scope

  With the default `:all`, every resource of every listed domain
  contributes a schema and a tag — including resources no route exposes.
  With `:routed`, only resources that contribute at least one JSON:API
  route seed the components; the schema builder still pulls relationship
  and embedded destinations in transitively, so the output is exactly the
  closure the served paths reference. Use `:routed` when listed domains
  contain internal resources whose shape should not appear in a public
  spec.
  """

  alias AshOaskit.Generators.InfoBuilder
  alias AshOaskit.Generators.PathBuilder
  alias AshOaskit.PhoenixIntrospection
  alias AshOaskit.RouteGathering
  alias AshOaskit.SchemaBuilder

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
    openapi_version = if version == "3.0", do: "3.0.3", else: "3.1.0"

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
    input_actions = collect_input_actions(domains)

    builder =
      domains
      |> seed_resources(Keyword.get(opts, :resource_scope, :all))
      |> Enum.reduce(SchemaBuilder.new(version: version), fn resource, builder ->
        SchemaBuilder.add_resource_schemas(builder, resource,
          input_actions: Map.get(input_actions, resource, [])
        )
      end)

    %{schemas: builder.schemas}
  end

  # :all seeds every resource of every domain; :routed seeds only the
  # resources that contribute at least one JSON:API route. Relationship
  # and embedded destinations are pulled in transitively by the schema
  # builder either way, so :routed yields the closure the paths reference.
  defp seed_resources(domains, :all) do
    Enum.flat_map(domains, &get_domain_resources/1)
  end

  defp seed_resources(domains, :routed) do
    domains
    |> Enum.flat_map(&RouteGathering.domain_routes/1)
    |> Enum.map(& &1.resource)
    |> Enum.uniq()
  end

  # Collects {action, route} pairs per resource for every route that
  # carries a request body, so components contain exactly the input
  # schemas the operations reference
  defp collect_input_actions(domains) do
    domains
    |> Enum.flat_map(&RouteGathering.domain_routes/1)
    |> Enum.filter(&body_bearing_route?/1)
    |> Enum.group_by(& &1.resource)
    |> Map.new(fn {resource, routes} ->
      {resource, routes |> Enum.uniq_by(& &1.action) |> Enum.map(&{&1.action, &1})}
    end)
  end

  defp body_bearing_route?(%{type: type}) when type in [:post, :patch], do: true
  defp body_bearing_route?(%{type: :route, method: method}), do: method not in [:get, :delete]
  defp body_bearing_route?(_), do: false

  # Builds all tags from domains and optionally from router
  defp build_all_tags(domains, opts) do
    domain_tags =
      domains
      |> seed_resources(Keyword.get(opts, :resource_scope, :all))
      |> InfoBuilder.build_resource_tags()

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
        Logger.warning(fn ->
          "AshOaskit: ignoring invalid modify_open_api hook: #{inspect(other)}"
        end)

        spec
    end
  end

  # Gets all resources from a domain
  defp get_domain_resources(domain) do
    Ash.Domain.Info.resources(domain)
  end

  # Removes nil values from a map
  defp reject_nil_values(map) do
    map
    |> Enum.reject(fn {_, v} -> is_nil(v) end)
    |> Map.new()
  end
end
