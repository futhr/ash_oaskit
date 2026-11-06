defmodule AshOaskit.SensitiveDefaultsTest do
  @moduledoc false

  use ExUnit.Case, async: true

  for version <- ["3.0", "3.1"] do
    @version version

    test "OpenAPI #{version} serving omits sensitive attribute defaults" do
      {spec, body} = served_spec(@version)
      schemas = spec["components"]["schemas"]

      for name <- ["SensitiveDefaultsAttributes", "SensitiveDefaultsCreateInput"] do
        credential = schemas[name]["properties"]["credential"]
        assert credential["minLength"] == 8
        refute Map.has_key?(credential, "default")
      end

      refute body =~ "synthetic-attribute-secret"
    end

    test "OpenAPI #{version} serving omits sensitive action argument defaults" do
      {spec, body} = served_spec(@version)
      input = spec["components"]["schemas"]["SensitiveDefaultsCreateInput"]
      password = input["properties"]["password"]

      assert password["minLength"] == 8
      refute Map.has_key?(password, "default")
      refute body =~ "synthetic-argument-secret"
    end

    test "OpenAPI #{version} serving retains ordinary defaults and private-field exclusion" do
      {spec, body} = served_spec(@version)
      attributes = spec["components"]["schemas"]["SensitiveDefaultsAttributes"]

      assert attributes["properties"]["label"]["default"] == "ordinary-default"
      refute Map.has_key?(attributes["properties"], "internal_note")
      refute body =~ "synthetic-private-default"
    end
  end

  defp served_spec(version) do
    conn =
      :get
      |> Plug.Test.conn("/openapi.json")
      |> AshOaskit.Router.Plug.call(%{
        domains: [AshOaskit.Test.SensitiveDefaultsDomain],
        openapi_version: version
      })

    assert conn.status == 200
    {Jason.decode!(conn.resp_body), conn.resp_body}
  end
end
