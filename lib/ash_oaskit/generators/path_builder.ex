defmodule AshOaskit.Generators.PathBuilder do
  @moduledoc """
  OpenAPI paths and operations builder.

  This module generates the `paths` section of OpenAPI specifications,
  converting Ash domain routes into OpenAPI path items with operations.

  ## Overview

  For each route defined in an Ash domain, this module generates:

  - Path item with the appropriate HTTP method
  - Operation with operationId, summary, tags
  - Parameters (path, query)
  - Request body (for POST/PATCH)
  - Response definitions

  ## Route Types

  Standard CRUD routes are mapped to HTTP methods:

  | Route Type | HTTP Method | Success Code |
  |------------|-------------|--------------|
  | `:index` | GET | 200 |
  | `:get` | GET | 200 |
  | `:post` | POST | 201 |
  | `:patch` | PATCH | 200 |
  | `:delete` | DELETE | 204 |

  Relationship routes are delegated to `AshOaskit.RelationshipRoutes`.

  ## Query Parameters

  For GET operations, the following parameters are added:

  - **filter** - Field-specific filtering (from FilterBuilder)
  - **sort** - Sorting specification (from SortBuilder)
  - **page** - Pagination (offset, limit, cursor-based)
  - **include** - Relationship inclusion paths

  ## Phoenix Controller Routes

  When a `:router` option is provided, this module also includes routes from
  Phoenix controllers that implement `AshOaskit.OpenApiController` behaviour.

  ## Usage

      # Ash routes only
      paths = PathBuilder.build_paths([MyApp.Domain], version: "3.1")

      # Ash routes + Phoenix controller routes
      paths = PathBuilder.build_paths([MyApp.Domain], version: "3.1", router: MyAppWeb.Router)
  """

  import AshOaskit.Core.PathUtils
  import AshOaskit.Core.SchemaRef, only: [schema_ref: 1]

  alias Ash.Resource.Info, as: ResourceInfo

  alias AshOaskit.Config
  alias AshOaskit.FilterBuilder
  alias AshOaskit.PhoenixIntrospection
  alias AshOaskit.RelationshipRoutes
  alias AshOaskit.RouteGathering
  alias AshOaskit.SchemaBuilder.ResourceSchemas
  alias AshOaskit.SortBuilder
  alias AshOaskit.TypeMapper

  @type opts :: keyword()

  @doc """
  Builds paths from domains and optionally from Phoenix router.

  Extracts all routes from the given domains and converts them
  to OpenAPI path items grouped by path. If a `:router` option
  is provided, also includes routes from Phoenix controllers
  implementing `AshOaskit.OpenApiController`.

  ## Parameters

  - `domains` - List of Ash domain modules
  - `opts` - Options including:
    - `:version` - OpenAPI version ("3.0" or "3.1")
    - `:router` - Optional Phoenix router module for controller introspection

  ## Returns

  A map of path strings to path item objects.

  ## Examples

      iex> PathBuilder.build_paths([MyApp.Blog], version: "3.1")
      %{
        "/posts" => %{
          "get" => %{...},
          "post" => %{...}
        },
        "/posts/{id}" => %{
          "get" => %{...},
          "patch" => %{...},
          "delete" => %{...}
        }
      }

      iex> PathBuilder.build_paths([MyApp.Blog], version: "3.1", router: MyAppWeb.Router)
      %{
        "/posts" => %{...},
        "/api/health" => %{
          # From HealthController
          "get" => %{...}
        }
      }
  """
  @spec build_paths(list(module()), opts()) :: map()
  def build_paths(domains, opts) do
    ash_paths = build_ash_paths(domains, opts)
    controller_paths = build_controller_paths(opts)

    deep_merge_paths(ash_paths, controller_paths)
  end

  @doc """
  Builds an operation object for a route.

  ## Parameters

  - `route` - The AshJsonApi route struct
  - `opts` - Options including `:version`

  ## Returns

  An OpenAPI operation object.
  """
  @spec build_operation(map(), opts()) :: map()
  def build_operation(route, opts) do
    version = Keyword.fetch!(opts, :version)

    cond do
      RelationshipRoutes.relationship_route?(route) ->
        RelationshipRoutes.build_operation(route, opts)

      route.type == :route ->
        build_generic_operation(route, version)

      true ->
        reject_nil_values(%{
          operationId: build_operation_id(route),
          summary: build_operation_summary(route),
          description: build_operation_description(route),
          responses: build_responses(route),
          tags: build_operation_tags(route),
          parameters: build_parameters(route, version),
          requestBody: build_request_body(route)
        })
    end
  end

  # Builds an operation for a generic action route (`route :post, "...", :action`)
  defp build_generic_operation(route, version) do
    reject_nil_values(%{
      operationId: build_operation_id(route),
      summary: build_operation_summary(route),
      description: build_operation_description(route),
      responses: build_generic_responses(route, version),
      tags: build_operation_tags(route),
      parameters: build_generic_parameters(route, version),
      requestBody: build_generic_request_body(route)
    })
  end

  # The route's name when set, otherwise "{Action} {Resource}"
  defp build_operation_summary(%{name: name}) when is_binary(name) do
    name |> to_string() |> humanize()
  end

  defp build_operation_summary(route) do
    action = route.action |> to_string() |> humanize()
    resource = route.resource |> Module.split() |> List.last()

    "#{action} #{resource}"
  end

  # The route's description when set, otherwise the action's description
  # (the same precedence AshJsonApi uses)
  defp build_operation_description(%{description: description}) when is_binary(description) do
    description
  end

  defp build_operation_description(route) do
    case ResourceInfo.action(route.resource, route.action) do
      nil -> nil
      action -> action.description
    end
  end

  # Builds paths from Ash domain routes
  defp build_ash_paths(domains, opts) do
    domains
    |> Enum.flat_map(&get_domain_routes/1)
    |> Enum.group_by(fn {path, _} -> convert_path_params(path) end)
    |> Enum.map(fn {path, routes} ->
      operations =
        routes
        |> Enum.map(fn {_, route} ->
          {route_to_method(route), build_operation(route, opts)}
        end)
        |> Map.new()

      {path, operations}
    end)
    |> Map.new()
  end

  # Builds paths from Phoenix controller routes (if router is provided)
  defp build_controller_paths(opts) do
    case Keyword.get(opts, :router) do
      nil ->
        %{}

      router ->
        router
        |> PhoenixIntrospection.extract_routes()
        |> PhoenixIntrospection.routes_to_paths()
    end
  end

  # Deep merges two path maps, combining operations for the same path
  defp deep_merge_paths(map1, map2) do
    Map.merge(map1, map2, fn _, ops1, ops2 ->
      Map.merge(ops1, ops2)
    end)
  end

  # Gets routes from a domain with their served paths (domain-level and
  # resource-level routes, with the domain prefix applied)
  defp get_domain_routes(domain) do
    RouteGathering.routes_with_paths(domain)
  end

  # Resolves the HTTP method for a route. Every AshJsonApi route entity
  # carries an authoritative :method field (generic routes require it);
  # the type-based mapping remains as a fallback for hand-built maps.
  defp route_to_method(%{method: method}) when is_atom(method) and not is_nil(method) do
    to_string(method)
  end

  defp route_to_method(route) do
    if RelationshipRoutes.relationship_route?(route) do
      RelationshipRoutes.route_method(route)
    else
      route_type_to_method(route.type)
    end
  end

  # Maps Ash route types to HTTP methods (fallback when :method is absent)
  defp route_type_to_method(:index), do: "get"
  defp route_type_to_method(:get), do: "get"
  defp route_type_to_method(:post), do: "post"
  defp route_type_to_method(:patch), do: "patch"
  defp route_type_to_method(:delete), do: "delete"

  # Builds operation ID from resource, action, route type, and path
  # The path prefix is included for nested routes to ensure uniqueness
  defp build_operation_id(route) do
    method = route_to_method(route)

    resource_name =
      route.resource
      |> Module.split()
      |> List.last()
      |> Macro.underscore()

    action_name = to_string(route.action)

    # Add route type suffix for index routes to distinguish from get routes
    type_suffix = if route.type == :index, do: "_list", else: ""

    # For nested routes, include parent path segment to ensure uniqueness
    # e.g., /devices/{device_id}/commands -> "devices_device_command_send"
    # vs /commands -> "device_command_send"
    path_prefix = extract_path_prefix(route.route, resource_name)

    if path_prefix do
      "#{method}_#{path_prefix}_#{resource_name}_#{action_name}#{type_suffix}"
    else
      "#{method}_#{resource_name}_#{action_name}#{type_suffix}"
    end
  end

  # Extracts a path prefix for nested routes
  # Returns nil for top-level routes, or the parent segment for nested routes
  defp extract_path_prefix(route_path, resource_name) do
    # Get first segment that isn't the resource itself
    segments =
      route_path
      |> String.trim_leading("/")
      |> String.split("/")
      |> Enum.reject(&(String.starts_with?(&1, ":") or String.starts_with?(&1, "{")))

    resource_plural = pluralize(resource_name)

    case segments do
      # Top-level route
      [^resource_plural | _] -> nil
      # Top-level route (singular)
      [^resource_name | _] -> nil
      [parent | _] -> String.replace(parent, "-", "_")
      _ -> nil
    end
  end

  # Simple pluralization for common cases
  defp pluralize(name) do
    cond do
      String.ends_with?(name, "y") ->
        String.slice(name, 0..-2//1) <> "ies"

      String.ends_with?(name, "s") || String.ends_with?(name, "x") ->
        name <> "es"

      true ->
        name <> "s"
    end
  end

  # Builds operation tags from resource name
  defp build_operation_tags(route) do
    resource_name =
      route.resource
      |> Module.split()
      |> List.last()

    [resource_name]
  end

  # Builds parameters for an operation (path + query params)
  defp build_parameters(route, version) do
    path_params =
      route.route
      |> extract_path_params()
      |> Enum.map(fn param ->
        %{
          name: param,
          in: :path,
          required: true,
          schema: %{type: :string}
        }
      end)

    params =
      if route.type in [:index, :get] do
        path_params ++ build_query_parameters(route, version)
      else
        path_params
      end

    case params do
      [] -> nil
      params -> params
    end
  end

  # Builds query parameters for GET operations
  defp build_query_parameters(route, version) do
    resource = route.resource

    filter_param = FilterBuilder.build_filter_parameter(resource, version: version)
    sort_param = SortBuilder.build_sort_parameter(resource, version: version)

    base_params = [
      %{
        name: "page",
        in: :query,
        required: false,
        schema: %{
          type: :object,
          properties: %{
            offset: %{type: :integer, minimum: 0},
            limit: %{type: :integer, minimum: 1},
            after: %{type: :string},
            before: %{type: :string},
            count: %{type: :boolean}
          }
        },
        style: :deepObject,
        description: "Pagination parameters"
      },
      %{
        name: "include",
        in: :query,
        required: false,
        schema: %{type: :string},
        description: "Comma-separated list of relationship paths to include"
      }
    ]

    params = if sort_param, do: [sort_param | base_params], else: base_params
    if filter_param, do: [filter_param | params], else: params
  end

  # Builds request body for POST/PATCH operations, referencing the
  # action-derived input schema in a JSON:API envelope
  defp build_request_body(%{type: type} = route) when type in [:post, :patch] do
    data =
      reject_nil_values(%{
        type: :object,
        required: if(type == :patch, do: [:id]),
        properties:
          reject_nil_values(%{
            id: if(type == :patch, do: %{type: :string}),
            type: json_api_type_member(route.resource),
            attributes: action_input_ref(route)
          })
      })

    %{
      required: true,
      content: %{
        "application/vnd.api+json" => %{
          schema: %{
            type: :object,
            required: [:data],
            properties: %{data: data}
          }
        }
      }
    }
  end

  defp build_request_body(_), do: nil

  # Generic action routes wrap the input object directly in `data`
  defp build_generic_request_body(%{method: method}) when method in [:get, :delete], do: nil

  defp build_generic_request_body(route) do
    %{
      required: true,
      content: %{
        "application/vnd.api+json" => %{
          schema: %{
            type: :object,
            required: [:data],
            properties: %{data: action_input_ref(route)}
          }
        }
      }
    }
  end

  defp action_input_ref(route) do
    schema_name =
      route.resource
      |> Module.split()
      |> List.last()

    schema_ref(ResourceSchemas.action_input_schema_name(schema_name, route.action))
  end

  defp json_api_type_member(resource) do
    %{type: :string, enum: [Config.resource_type(resource)]}
  end

  # Builds response definitions for an operation
  defp build_responses(route) do
    success_code =
      case route.type do
        :post -> "201"
        :delete -> "204"
        _ -> "200"
      end

    schema_name =
      route.resource
      |> Module.split()
      |> List.last()

    success_response =
      if route.type == :delete do
        %{description: "Deleted successfully"}
      else
        %{
          description: "Successful response",
          content: %{
            "application/vnd.api+json" => %{
              schema: schema_ref("#{schema_name}Response")
            }
          }
        }
      end

    %{
      success_code => success_response,
      "400" => %{description: "Bad request"},
      "401" => %{description: "Unauthorized"},
      "404" => %{description: "Not found"},
      "422" => %{description: "Unprocessable entity"}
    }
  end

  # Builds parameters for a generic action route: path params plus the
  # route's :query_params, typed from the action's arguments (or the
  # resource attribute of the same name)
  defp build_generic_parameters(route, version) do
    path_params =
      route.route
      |> extract_path_params()
      |> Enum.map(fn param ->
        %{
          name: param,
          in: :path,
          required: true,
          schema: %{type: :string}
        }
      end)

    case path_params ++ build_generic_query_parameters(route, version) do
      [] -> nil
      params -> params
    end
  end

  defp build_generic_query_parameters(route, version) do
    action = ResourceInfo.action(route.resource, route.action)
    arguments = if action, do: Map.new(action.arguments, &{&1.name, &1}), else: %{}

    route
    |> Map.get(:query_params, [])
    |> Enum.map(fn name ->
      case Map.get(arguments, name) do
        nil ->
          attribute = ResourceInfo.attribute(route.resource, name)
          schema = if attribute, do: version_schema(attribute, version), else: %{type: :string}
          %{name: to_string(name), in: :query, required: false, schema: schema}

        argument ->
          %{
            name: to_string(name),
            in: :query,
            required: not argument.allow_nil? and is_nil(argument.default),
            schema: version_schema(argument, version)
          }
      end
    end)
  end

  # Builds responses for a generic action route, mirroring how AshJsonApi
  # serializes generic action results
  defp build_generic_responses(route, version) do
    success_code = if route.method == :post, do: "201", else: "200"

    %{
      success_code => %{
        description: "Successful response",
        content: %{
          "application/vnd.api+json" => %{
            schema: generic_result_schema(route, version)
          }
        }
      },
      "400" => %{description: "Bad request"},
      "401" => %{description: "Unauthorized"},
      "404" => %{description: "Not found"},
      "422" => %{description: "Unprocessable entity"}
    }
  end

  defp generic_result_schema(route, version) do
    action = ResourceInfo.action(route.resource, route.action)

    if action && action.returns do
      returns = %{type: action.returns, constraints: action.constraints, allow_nil?: false}
      schema = version_schema(returns, version)

      if Map.get(route, :wrap_in_result?, false) do
        %{type: :object, properties: %{result: schema}, required: [:result]}
      else
        schema
      end
    else
      # Actions without a return type respond with {"success": true}
      %{type: :object, properties: %{success: %{enum: [true]}}, required: [:success]}
    end
  end

  defp version_schema(attr_or_arg, "3.0"), do: TypeMapper.to_json_schema_30(attr_or_arg)
  defp version_schema(attr_or_arg, _), do: TypeMapper.to_json_schema_31(attr_or_arg)

  # Removes nil values from a map
  defp reject_nil_values(map) do
    map
    |> Enum.reject(fn {_, v} -> is_nil(v) end)
    |> Map.new()
  end
end
