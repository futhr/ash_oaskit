defmodule AshOaskit.SerializedPayloadTest do
  use ExUnit.Case, async: true
  alias AshOaskit.Test.{Blog, Post}

  test "real AshJsonApi member and paginated output validate, and corrupted data fails" do
    record = %Post{
      id: Ash.UUID.generate(),
      title: "Published",
      score: Decimal.new("123456789.123456789")
    }

    route = Enum.find(AshOaskit.RouteGathering.domain_routes(Blog), &(&1.type == :index))

    request = %AshJsonApi.Request{
      domain: Blog,
      all_domains: [Blog],
      resource: Post,
      route: route,
      url: "https://example.com/posts",
      path_params: %{},
      includes_keyword: [],
      fields: %{Post => [:title, :score]}
    }

    page = %Ash.Page.Offset{results: [record], limit: 10, offset: 0, count: 1}
    member = AshJsonApi.Serializer.serialize_one(request, record, []) |> Jason.decode!()
    collection = AshJsonApi.Serializer.serialize_many(request, page, [], %{}) |> Jason.decode!()

    assert member["data"]["attributes"] == %{
             "title" => "Published",
             "score" => "123456789.123456789"
           }

    assert collection["meta"]["page"] == %{"limit" => 10, "offset" => 0, "total" => 1}

    for version <- ["3.0", "3.1"],
        {name, payload} <- [{"PostResponse", member}, {"PostCollectionResponse", collection}] do
      spec = AshOaskit.spec(domains: [Blog], version: version)
      schema = spec["components"]["schemas"][name] |> Map.put("components", spec["components"])
      schema = if version == "3.0", do: upgrade_nullable(schema), else: schema
      validator = JSV.build!(schema)
      assert {:ok, _} = JSV.validate(payload, validator)
      assert {:error, _} = JSV.validate(Map.put(payload, "data", "not resource data"), validator)
    end
  end

  # JSV consumes JSON Schema, not OpenAPI 3.0's nullable extension.
  defp upgrade_nullable(value) when is_map(value) do
    nullable = value["nullable"]

    value =
      Map.new(Map.delete(value, "nullable"), fn {key, item} -> {key, upgrade_nullable(item)} end)

    if nullable && value["type"], do: Map.update!(value, "type", &[&1, "null"]), else: value
  end

  defp upgrade_nullable(value) when is_list(value), do: Enum.map(value, &upgrade_nullable/1)
  defp upgrade_nullable(value), do: value
end
