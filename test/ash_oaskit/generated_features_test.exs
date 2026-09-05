defmodule AshOaskit.GeneratedFeaturesTest do
  use ExUnit.Case, async: true

  test "domain grouping uses the serving domain rather than the resource's default domain" do
    spec = AshOaskit.spec(domains: [AshOaskit.Test.Blog], group_by: :domain)
    tags = Enum.map(spec["tags"], & &1["name"])
    assert spec["paths"]["/posts"]["get"]["tags"] == ["Blog"]
    assert "Blog" in tags
  end

  test "generated documents connect errors, included data, links, metadata, and multipart input" do
    for version <- ["3.0", "3.1"] do
      spec =
        AshOaskit.spec(
          domains: [AshOaskit.Test.Publishing, AshOaskit.Test.SchemaAuditDomain],
          version: version
        )

      schemas = spec["components"]["schemas"]
      assert schemas["ArticleResponse"]["properties"]["included"]["items"]["oneOf"] != nil
      assert schemas["ArticleResource"]["properties"]["links"] != nil

      assert schemas["ArticleCollectionResponse"]["properties"]["meta"]["properties"]["page"][
               "properties"
             ]["total"]["type"] == "integer"

      operation = spec["paths"]["/schema-audit/upload"]["post"]

      assert operation["responses"]["403"]["content"]["application/vnd.api+json"]["schema"] == %{
               "$ref" => "#/components/schemas/JsonApiError"
             }

      body = operation["requestBody"]["content"]["multipart/x.ash+form-data"]
      assert Enum.sort(body["schema"]["properties"]["data"]["required"]) == ["caption", "file"]
      assert body["schema"]["properties"]["data"]["properties"]["file"]["type"] == "string"
      refute body["schema"]["properties"]["data"]["properties"]["file"]["format"]
      assert body["schema"]["additionalProperties"]["format"] == "binary"
      assert body["encoding"]["data"]["contentType"] == "application/vnd.api+json"
    end
  end
end
