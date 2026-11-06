defmodule AshOaskit.SerializedPayloadTest do
  use ExUnit.Case, async: true
  import AshOaskit.Test.SchemaValidation, only: [json_schema: 2]
  alias AshOaskit.Test.{Blog, Post}

  test "serialized responses validate and reject malformed data and formats" do
    record = %Post{
      id: Ash.UUID.generate(),
      title: "Published",
      score: Decimal.new("123456789.123456789"),
      duration: ~T[14:30:45],
      local_time: ~N[2026-10-23 14:30:45.123456],
      published_at: ~U[2026-10-23 14:30:45Z]
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
      fields: %{Post => [:title, :score, :duration, :local_time, :published_at]}
    }

    page = %Ash.Page.Offset{results: [record], limit: 10, offset: 0, count: 1}
    member = Jason.decode!(AshJsonApi.Serializer.serialize_one(request, record, []))
    collection = Jason.decode!(AshJsonApi.Serializer.serialize_many(request, page, [], %{}))

    assert member["data"]["attributes"] == %{
             "title" => "Published",
             "score" => "123456789.123456789",
             "duration" => "14:30:45",
             "local_time" => "2026-10-23T14:30:45.123456",
             "published_at" => "2026-10-23T14:30:45Z"
           }

    assert collection["meta"]["page"] == %{"limit" => 10, "offset" => 0, "total" => 1}

    for version <- ["3.0", "3.1"] do
      spec = AshOaskit.spec(domains: [Blog], version: version)
      attributes = spec["components"]["schemas"]["PostAttributes"]
      attributes = json_schema(attributes, version)
      validator = JSV.build!(attributes, Oaskit.default_jsv_opts())
      assert {:ok, _} = JSV.validate(member["data"]["attributes"], validator)

      assert {:error, _} =
               JSV.validate(
                 Map.put(member["data"]["attributes"], "duration", "24:30:45"),
                 validator
               )

      for {name, payload} <- [{"PostResponse", member}, {"PostCollectionResponse", collection}] do
        schema = Map.put(spec["components"]["schemas"][name], "components", spec["components"])
        schema = json_schema(schema, version)
        validator = JSV.build!(schema, Oaskit.default_jsv_opts())
        payload = normalize_external_links(payload)
        assert {:ok, _} = JSV.validate(payload, validator)
        assert_rejects_invalid_formats(payload, validator)

        assert {:error, _} =
                 JSV.validate(Map.put(payload, "data", "not resource data"), validator)
      end
    end
  end

  defp assert_rejects_invalid_formats(payload, validator) do
    assert {:error, _} =
             JSV.validate(put_in(payload, ["links", "self"], "not a URI"), validator)

    for {field, value} <- [
          {"published_at", "2026-10-23T14:30:45"},
          {"external_id", "not-a-uuid"}
        ] do
      corrupted = Map.update!(payload, "data", &put_attribute(&1, field, value))
      assert {:error, _} = JSV.validate(corrupted, validator)
    end
  end

  defp put_attribute(records, field, value) when is_list(records),
    do: Enum.map(records, &put_attribute(&1, field, value))

  defp put_attribute(record, field, value), do: put_in(record, ["attributes", field], value)

  # AshJsonApi 1.7.1 leaves query brackets unescaped. Keep that upstream defect
  # outside these schema regressions while enforcing formats on the whole document.
  defp normalize_external_links(payload) do
    update_in(payload, ["links"], fn links ->
      Map.new(links, fn {name, url} -> {name, encode_query_brackets(url)} end)
    end)
  end

  defp encode_query_brackets(nil), do: nil

  defp encode_query_brackets(url) do
    uri = URI.parse(url)

    if uri.query do
      query = uri.query |> String.replace("[", "%5B") |> String.replace("]", "%5D")
      URI.to_string(%{uri | query: query})
    else
      url
    end
  end
end
