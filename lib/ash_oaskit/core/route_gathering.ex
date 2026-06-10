defmodule AshOaskit.RouteGathering do
  @moduledoc """
  Collects AshJsonApi routes for a domain, including resource-level routes.

  AshJsonApi routes can be declared in two places:

  - On the domain: `json_api do routes do base_route ... end end`
  - On the resource: `json_api do routes do ... end end`

  `AshJsonApi.Domain.Info.routes/1` returns only the former. This module
  unions both sources — resource-level route entities are read directly
  off each resource, so domain routes are never duplicated — and applies
  the domain-wide `prefix` to produce the paths AshJsonApi actually
  serves.

  Resource `base` and domain `base_route` prefixes are already baked
  into `route.route` at compile time by AshJsonApi transformers; only
  the domain `prefix` needs to be applied at spec time.
  """

  alias AshOaskit.Config

  @doc """
  Returns all AshJsonApi routes for a domain.

  Combines domain-level routes with the routes declared on each of the
  domain's resources. Resources without the AshJsonApi extension
  contribute nothing.

  ## Parameters

    - `domain` - The Ash domain module

  ## Returns

  List of `AshJsonApi.Resource.Route` structs.

  ## Examples

      iex> routes = AshOaskit.RouteGathering.domain_routes(AshOaskit.Test.Blog)
      ...> Enum.any?(routes, &(&1.type == :index))
      true
  """
  @spec domain_routes(module()) :: [struct()]
  def domain_routes(domain) do
    domain_level = AshJsonApi.Domain.Info.routes(domain)

    # Resource-level route entities carry resource: nil (AshJsonApi
    # resolves it from context); fill it in so downstream builders can
    # introspect the resource uniformly
    resource_level =
      domain
      |> Ash.Domain.Info.resources()
      |> Enum.flat_map(fn resource ->
        resource
        |> AshJsonApi.Resource.Info.routes()
        |> Enum.map(fn route -> %{route | resource: route.resource || resource} end)
      end)

    Enum.uniq(domain_level ++ resource_level)
  end

  @doc """
  Returns `{path, route}` pairs for a domain with the `prefix` applied.

  The path is the route's compile-time path prepended with the domain's
  `json_api do prefix "..." end` setting, normalized to a leading slash —
  the same path AshJsonApi serves the route under.

  ## Parameters

    - `domain` - The Ash domain module

  ## Returns

  List of `{path, route}` tuples.

  ## Examples

      iex> pairs = AshOaskit.RouteGathering.routes_with_paths(AshOaskit.Test.Blog)
      ...> Enum.any?(pairs, fn {path, _route} -> path == "/posts" end)
      true
  """
  @spec routes_with_paths(module()) :: [{String.t(), struct()}]
  def routes_with_paths(domain) do
    prefix = Config.route_prefix(domain)

    domain
    |> domain_routes()
    |> Enum.map(fn route -> {prefixed_path(prefix, route.route), route} end)
  end

  defp prefixed_path("", path), do: ensure_leading_slash(path)
  defp prefixed_path(prefix, path), do: ensure_leading_slash(Path.join(prefix, path))

  defp ensure_leading_slash("/" <> _ = path), do: path
  defp ensure_leading_slash(path), do: "/" <> path
end
