defmodule AshOaskit.GenericRoutesTest do
  @moduledoc """
  Tests for generic action routes (`route :method, "path", :action`).

  Generic routes declare their HTTP method in the DSL and expose Ash
  generic actions. Operations are derived from the action: query
  parameters from `query_params` + action arguments, and the response
  schema from the action's `returns` type (honoring `wrap_in_result?`),
  mirroring how AshJsonApi serializes generic action results.
  """

  use ExUnit.Case, async: true

  setup_all do
    {:ok, spec: AshOaskit.spec_31(domains: [AshOaskit.Test.Workshop])}
  end

  describe "HTTP methods" do
    test "generic routes emit their declared method, not the route type", %{spec: spec} do
      assert Map.keys(spec["paths"]["/gadgets/{id}/activate"]) == ["post"]
      assert Map.keys(spec["paths"]["/gadgets/search"]) == ["get"]

      for {_, operations} <- spec["paths"], {method, _} <- operations do
        assert method in ~w(get post patch put delete head options trace),
               "invalid HTTP method #{inspect(method)}"
      end
    end

    test "operation ids use the declared method", %{spec: spec} do
      operation = spec["paths"]["/gadgets/{id}/activate"]["post"]

      assert operation["operationId"] == "post_gadget_activate"
    end
  end

  describe "parameters" do
    test "path params are extracted", %{spec: spec} do
      operation = spec["paths"]["/gadgets/{id}/activate"]["post"]
      [param] = operation["parameters"]

      assert param["name"] == "id"
      assert param["in"] == "path"
      assert param["required"] == true
    end

    test "query_params map to typed query parameters from action arguments", %{spec: spec} do
      operation = spec["paths"]["/gadgets/search"]["get"]
      param = Enum.find(operation["parameters"], &(&1["name"] == "query"))

      assert param["in"] == "query"
      assert param["required"] == true
      assert param["schema"]["type"] == "string"
    end
  end

  describe "responses" do
    test "post-method generic routes use 201", %{spec: spec} do
      operation = spec["paths"]["/gadgets/{id}/activate"]["post"]

      assert Map.has_key?(operation["responses"], "201")
      refute Map.has_key?(operation["responses"], "200")
    end

    test "get-method generic routes use 200", %{spec: spec} do
      operation = spec["paths"]["/gadgets/search"]["get"]

      assert Map.has_key?(operation["responses"], "200")
    end

    test "actions without returns respond with the success shape", %{spec: spec} do
      operation = spec["paths"]["/gadgets/{id}/activate"]["post"]
      schema = operation["responses"]["201"]["content"]["application/vnd.api+json"]["schema"]

      assert schema["type"] == "object"
      assert schema["properties"]["success"]["enum"] == [true]
      assert schema["required"] == ["success"]
    end

    test "actions with returns use the TypeMapper schema", %{spec: spec} do
      operation = spec["paths"]["/gadgets/search"]["get"]
      schema = operation["responses"]["200"]["content"]["application/vnd.api+json"]["schema"]

      assert schema["type"] == "array"
      assert schema["items"]["type"] == "string"
    end

    test "wrap_in_result? wraps the return type in a result object", %{spec: spec} do
      operation = spec["paths"]["/gadgets/recalibrate"]["post"]
      schema = operation["responses"]["201"]["content"]["application/vnd.api+json"]["schema"]

      assert schema["type"] == "object"
      assert schema["properties"]["result"]["type"] == "integer"
      assert schema["required"] == ["result"]
    end
  end

  describe "spec validity" do
    test "specs with generic routes pass Oaskit validation", %{spec: spec} do
      assert {:ok, %Oaskit.Spec.OpenAPI{}} = AshOaskit.validate(spec)
    end

    test "3.0 specs with generic routes pass Oaskit validation" do
      spec = AshOaskit.spec_30(domains: [AshOaskit.Test.Workshop])

      assert {:ok, %Oaskit.Spec.OpenAPI{}} = AshOaskit.validate(spec)
    end
  end
end
