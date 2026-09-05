defmodule AshOaskit.RouteGatheringTest do
  @moduledoc false
  use ExUnit.Case, async: true

  defmodule TenantDomain do
    @moduledoc false
    use Ash.Domain, extensions: [AshJsonApi.Domain], validate_config_inclusion?: false

    resources do
      resource AshOaskit.Test.Post
    end

    json_api do
      prefix "/tenants/:tenant2"

      routes do
        base_route "/posts", AshOaskit.Test.Post do
          get :read
        end
      end
    end
  end

  test "effective paths and operation parameters both include domain prefix parameters" do
    [{path, route}] = AshOaskit.RouteGathering.routes_with_paths(TenantDomain)
    assert path == "/tenants/:tenant2/posts/:id"
    assert route.route == path

    spec = AshOaskit.spec(domains: [TenantDomain])
    operation = spec["paths"]["/tenants/{tenant2}/posts/{id}"]["get"]
    params = Enum.filter(operation["parameters"], &(&1["in"] == "path"))
    assert Enum.map(params, & &1["name"]) == ["tenant2", "id"]
    assert Enum.all?(params, & &1["required"])
  end
end
