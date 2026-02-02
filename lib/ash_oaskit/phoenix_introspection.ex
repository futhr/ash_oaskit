defmodule AshOaskit.PhoenixIntrospection do
  @moduledoc """
  Extracts OpenAPI paths from Phoenix router for controllers
  implementing the `AshOaskit.OpenApiController` behaviour.

  This module enables AshOaskit to include non-Ash controller routes
  in the OpenAPI specification. Only controllers that explicitly
  implement the `OpenApiController` behaviour are included.

  ## Usage

  This module is used internally by `AshOaskit.Generators.PathBuilder`
  when a `:router` option is provided:

      paths = PathBuilder.build_paths(domains, router: MyAppWeb.Router)

  ## How It Works

  1. Calls `Phoenix.Router.routes/1` to get all routes
  2. Filters to only include routes where the plug (controller) implements
     the `AshOaskit.OpenApiController` behaviour
  3. For each matching route, calls `controller.openapi_operations/0`
     to get the operation metadata
  4. Converts routes to OpenAPI path items

  ## Route Structure

  Phoenix routes have the following structure:

      %{
        path: "/api/health",
        verb: :get,
        plug: MyAppWeb.HealthController,
        plug_opts: :index
      }

  This is converted to OpenAPI format:

      %{
        "/api/health" => %{
          "get" => %{
            operationId: "MyAppWeb.HealthController.index",
            summary: "Health check",
            responses: %{"200" => %{description: "Success"}}
          }
        }
      }
  """

  import AshOaskit.Core.PathUtils

  @doc """
  Extracts routes from a Phoenix router that implement OpenApiController.

  ## Parameters

  - `router` - A Phoenix router module

  ## Returns

  A list of route info maps with path, verb, controller, action, and operation.

  ## Examples

      PhoenixIntrospection.extract_routes(MyAppWeb.Router)
      #=> [
      #=>   %{
      #=>     path: "/api/health",
      #=>     verb: :get,
      #=>     controller: MyAppWeb.HealthController,
      #=>     action: :index,
      #=>     operation: %{summary: "Health check", ...}
      #=>   }
      #=> ]
  """
  @spec extract_routes(module()) :: [map()]
  def extract_routes(router) when is_atom(router) do
    if Code.ensure_loaded?(router) and function_exported?(router, :__routes__, 0) do
      router.__routes__()
      |> Enum.filter(&controller_with_behaviour?/1)
      |> Enum.map(&build_route_info/1)
    else
      []
    end
  end

  @doc """
  Converts extracted routes to OpenAPI paths format.

  Groups routes by path and creates path items with operations
  keyed by HTTP method.

  ## Parameters

  - `routes` - List of route info maps from `extract_routes/1`

  ## Returns

  A map of paths to path items, suitable for merging with Ash paths.

  ## Examples

      iex> routes = PhoenixIntrospection.extract_routes(MyAppWeb.Router)
      ...> PhoenixIntrospection.routes_to_paths(routes)
      %{
        "/api/health" => %{
          "get" => %{operationId: "...", summary: "..."}
        }
      }
  """
  @spec routes_to_paths([map()]) :: map()
  def routes_to_paths(routes) do
    routes
    |> Enum.group_by(& &1.path)
    |> Enum.map(fn {path, grouped_routes} ->
      operations =
        grouped_routes
        |> Enum.map(fn route ->
          {verb_to_string(route.verb), route.operation}
        end)
        |> Map.new()

      {path, operations}
    end)
    |> Map.new()
  end

  @doc """
  Extracts unique tags from controllers implementing OpenApiController.

  Collects tags from all controllers that implement the `openapi_tag/0`
  callback, or generates default tags from controller names.

  ## Parameters

  - `router` - A Phoenix router module

  ## Returns

  A list of unique tag objects for the OpenAPI spec.
  """
  @spec extract_tags(module()) :: [map()]
  def extract_tags(router) when is_atom(router) do
    if Code.ensure_loaded?(router) and function_exported?(router, :__routes__, 0) do
      router.__routes__()
      |> Enum.filter(&controller_with_behaviour?/1)
      |> Enum.map(& &1.plug)
      |> Enum.uniq()
      |> Enum.map(&get_controller_tag/1)
      |> Enum.map(&normalize_tag/1)
      |> Enum.uniq_by(& &1[:name])
    else
      []
    end
  end

  # Checks if the route's plug (controller) implements OpenApiController behaviour
  defp controller_with_behaviour?(%{plug: plug}) when is_atom(plug) do
    Code.ensure_loaded?(plug) and
      function_exported?(plug, :openapi_operations, 0)
  end

  defp controller_with_behaviour?(_), do: false

  # Builds route info from a Phoenix route
  defp build_route_info(route) do
    controller = route.plug
    action = route.plug_opts
    operations = controller.openapi_operations()

    operation =
      Map.get(operations, action) ||
        default_operation(route)

    # Ensure operation has operationId
    operation =
      Map.put_new(
        operation,
        :operationId,
        build_operation_id(controller, action)
      )

    # Add path parameters if not present
    operation = ensure_path_params(operation, route.path)

    %{
      path: convert_path_params(route.path),
      verb: route.verb,
      controller: controller,
      action: action,
      operation: operation
    }
  end

  # Converts HTTP verb atom to lowercase string
  defp verb_to_string(verb) when is_atom(verb) do
    verb |> to_string() |> String.downcase()
  end

  # Builds a default operation for actions not defined in openapi_operations
  defp default_operation(route) do
    controller_name = controller_tag_name(route.plug)
    action_name = route.plug_opts |> to_string() |> humanize()

    %{
      summary: "#{action_name} #{controller_name}",
      tags: [controller_name],
      responses: %{
        "200" => %{description: "Success"},
        "401" => %{description: "Unauthorized"},
        "404" => %{description: "Not found"}
      }
    }
  end

  # Builds operation ID from controller and action
  defp build_operation_id(controller, action) do
    controller_name =
      controller
      |> Module.split()
      |> List.last()
      |> String.replace("Controller", "")
      |> Macro.underscore()

    "#{controller_name}_#{action}"
  end

  # Ensures path parameters are in the operation if the path has params
  defp ensure_path_params(operation, path) do
    path_params = extract_path_params(path)

    if path_params == [] do
      operation
    else
      existing_params = Map.get(operation, :parameters, [])
      existing_param_names = Enum.map(existing_params, & &1[:name])

      new_params =
        path_params
        |> Enum.reject(&(&1 in existing_param_names))
        |> Enum.map(fn param ->
          %{
            name: param,
            in: :path,
            required: true,
            schema: %{type: :string}
          }
        end)

      if new_params == [] do
        operation
      else
        Map.put(operation, :parameters, existing_params ++ new_params)
      end
    end
  end

  # Gets the tag for a controller
  defp get_controller_tag(controller) do
    if function_exported?(controller, :openapi_tag, 0) do
      controller.openapi_tag()
    else
      controller_tag_name(controller)
    end
  end

  # Extracts controller name for use as tag
  defp controller_tag_name(controller) do
    controller
    |> Module.split()
    |> List.last()
    |> String.replace("Controller", "")
  end

  # Normalizes a tag to the map format
  defp normalize_tag(tag) when is_binary(tag) do
    %{name: tag}
  end

  defp normalize_tag(%{name: _} = tag) do
    # Already has atom :name key - ensure all keys are atoms
    desc = Map.get(tag, :description)
    result = %{name: tag.name}
    if desc, do: Map.put(result, :description, desc), else: result
  end

  defp normalize_tag(tag) when is_map(tag) do
    # Handle string keys or mixed keys
    name = Map.get(tag, :name) || Map.get(tag, "name")
    desc = Map.get(tag, :description) || Map.get(tag, "description")

    result = %{name: name}
    if desc, do: Map.put(result, :description, desc), else: result
  end
end
