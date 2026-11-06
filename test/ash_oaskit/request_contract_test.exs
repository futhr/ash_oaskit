defmodule AshOaskit.RequestContractTest do
  use ExUnit.Case, async: true
  import AshOaskit.Test.SchemaValidation, only: [json_schema: 2]

  alias AshOaskit.Test.RequestContract.{Domain, Item, Router}

  @media_type "application/vnd.api+json"

  for version <- ["3.0", "3.1"] do
    describe "OpenAPI #{version}" do
      setup do
        spec = AshOaskit.spec(domains: [Domain], version: unquote(version))
        {:ok, spec: spec, version: unquote(version)}
      end

      test "write routes offer fieldsets and configured includes", %{spec: spec} do
        for {method, path} <- [{"post", "/items"}, {"patch", "/items/{id}"}] do
          names = parameter_names(spec, method, path)
          assert "fields" in names
          assert "include" in names
          refute "filter" in names
          refute "sort" in names
          refute "page" in names
        end
      end

      test "member routes do not offer collection controls", %{spec: spec} do
        names = parameter_names(spec, "get", "/items/{id}")
        assert "fields" in names
        assert "include" in names
        refute "filter" in names
        refute "sort" in names
        refute "page" in names
        index_names = parameter_names(spec, "get", "/items")
        assert "filter" in index_names
        assert "sort" in index_names
        assert "page" in index_names
      end

      test "unknown attributes and generic action keys are rejected", context do
        create = validator(context, "post", "/items")
        body = create_body(%{"name" => "x", "note" => "n"})
        assert {:ok, _} = JSV.validate(body, create)

        assert {:error, _} =
                 JSV.validate(put_in(body, ["data", "attributes", "bogus"], 1), create)

        archive = validator(context, "post", "/items/{id}/archive")
        assert {:ok, _} = JSV.validate(%{"data" => %{"reason" => "r"}}, archive)
        assert {:error, _} = JSV.validate(%{"data" => %{"reason" => "r", "bogus" => 1}}, archive)
      end

      test "require_attributes rejects null independently of omission", context do
        create = validator(context, "post", "/items")
        assert {:error, _} = JSV.validate(create_body(%{"name" => "x", "note" => nil}), create)
        assert {:error, _} = JSV.validate(create_body(%{"name" => "x"}), create)
      end

      test "embedded input rejects unknown fields", context do
        body =
          create_body(%{
            "name" => "x",
            "note" => "n",
            "address" => %{"street" => "s", "city" => "c"}
          })

        create = validator(context, "post", "/items")
        assert {:ok, _} = JSV.validate(body, create)

        assert {:error, _} =
                 JSV.validate(put_in(body, ["data", "attributes", "address", "zip"], "z"), create)
      end

      test "embedded update permits partial fields while create needs complete input", context do
        body = create_body(%{"name" => "x", "note" => "n", "address" => %{"city" => "c"}})
        assert {:error, _} = JSV.validate(body, validator(context, "post", "/items"))

        patch = %{
          "data" => %{
            "id" => Ash.UUID.generate(),
            "attributes" => %{"address" => %{"city" => "c"}}
          }
        }

        assert {:ok, _} = JSV.validate(patch, validator(context, "patch", "/items/{id}"))
      end

      test "PATCH body retains an argument also used to locate the record", context do
        body = %{"data" => %{"attributes" => %{"note" => "new"}}}
        validator = validator(context, "patch", "/items/by_note/{note}/relabel")
        assert {:ok, _} = JSV.validate(body, validator)
        assert {:error, _} = JSV.validate(put_in(body, ["data", "attributes"], %{}), validator)
      end

      test "HTTP writes honor fieldsets and includes", %{spec: spec} do
        body = create_body(%{"name" => "x", "note" => "n"})
        assert {201, response} = request(:post, "/items?fields[item]=name", body)
        assert Map.keys(response["data"]["attributes"]) == ["name"]
        assert "fields" in parameter_names(spec, "post", "/items")

        id = response["data"]["id"]

        assert {200, response} =
                 request(:patch, "/items/#{id}?fields[item]=name", create_body(%{"name" => "y"}))

        assert response["data"]["attributes"] == %{"name" => "y"}
        assert "fields" in parameter_names(spec, "patch", "/items/{id}")
        assert {201, _} = request(:post, "/items?include=owner", body)
        assert "include" in parameter_names(spec, "post", "/items")
      end

      test "HTTP validation and schemas reject unknown keys and required nulls", context do
        for {attributes, status} <- [
              {%{"name" => "x", "note" => "n", "bogus" => 1}, 400},
              {%{"name" => "x", "note" => nil}, 400},
              {%{
                 "name" => "x",
                 "note" => "n",
                 "address" => %{"street" => "s", "city" => "c", "zip" => "z"}
               }, 422}
            ] do
          body = create_body(attributes)
          assert {^status, _} = request(:post, "/items", body)
          assert {:error, _} = JSV.validate(body, validator(context, "post", "/items"))
        end

        body = %{"data" => %{"reason" => "r", "bogus" => 1}}
        assert {400, _} = request(:post, "/items/#{Ash.UUID.generate()}/archive", body)
        assert {:error, _} = JSV.validate(body, validator(context, "post", "/items/{id}/archive"))
      end

      test "HTTP partial embedded updates and path/body arguments validate", context do
        item = seed(%{address: %{street: "1 Main", city: "Town"}, note: "old"})
        body = create_body(%{"address" => %{"city" => "City"}})
        assert {200, response} = request(:patch, "/items/#{item.id}", body)

        assert response["data"]["attributes"]["address"] == %{
                 "street" => "1 Main",
                 "city" => "City"
               }

        assert {:ok, _} = JSV.validate(body, validator(context, "patch", "/items/{id}"))

        body = create_body(%{"note" => "new"})
        assert {200, response} = request(:patch, "/items/by_note/old/relabel", body)
        assert response["data"]["attributes"]["note"] == "new"

        assert {:ok, _} =
                 JSV.validate(body, validator(context, "patch", "/items/by_note/{note}/relabel"))
      end

      test "HTTP member reads ignore collection filtering", %{spec: spec} do
        item = seed(%{name: "a"})
        assert {200, response} = request(:get, "/items/#{item.id}?filter[name]=zzz", nil)
        assert response["data"]["id"] == item.id
        refute "filter" in parameter_names(spec, "get", "/items/{id}")
      end

      test "replacement embeds and unkeyed arrays still require complete values", context do
        item =
          seed(%{replacement: %{street: "s", city: "c"}, addresses: [%{street: "s", city: "c"}]})

        for {field, value} <- [
              {"replacement", %{"city" => "new"}},
              {"addresses", [%{"city" => "new"}]}
            ] do
          body = create_body(%{field => value})
          assert {400, _} = request(:patch, "/items/#{item.id}", body)
          assert {:error, _} = JSV.validate(body, validator(context, "patch", "/items/{id}"))
        end
      end

      test "embedded custom actions and skipped keys are honored", context do
        attrs = %{
          "name" => "x",
          "note" => "n",
          "delivery" => %{"city" => "c"},
          "loose" => %{"street" => "s", "city" => "c", "extra" => 1}
        }

        body = create_body(attrs)
        assert {201, response} = request(:post, "/items", body)
        assert {:ok, _} = JSV.validate(body, validator(context, "post", "/items"))
        assert response["data"]["attributes"]["delivery"]["street"] == "Default street"

        body = create_body(%{"delivery" => %{"city" => "new"}})
        assert {200, _} = request(:patch, "/items/#{response["data"]["id"]}", body)
        assert {:ok, _} = JSV.validate(body, validator(context, "patch", "/items/{id}"))
        invalid = create_body(%{"delivery" => %{"city" => nil}})
        assert {400, _} = request(:patch, "/items/#{response["data"]["id"]}", invalid)
        assert {:error, _} = JSV.validate(invalid, validator(context, "patch", "/items/{id}"))
      end
    end
  end

  defp parameter_names(spec, method, path) do
    spec["paths"][path][method] |> Map.get("parameters", []) |> Enum.map(& &1["name"])
  end

  defp seed(attributes) do
    Item
    |> Ash.Changeset.for_create(:create, Map.merge(%{name: "seed", note: "n"}, attributes))
    |> Ash.create!()
  end

  defp request(method, path, body) do
    conn =
      method
      |> Plug.Test.conn(path, if(body, do: Jason.encode!(body), else: ""))
      |> Plug.Conn.put_req_header("content-type", @media_type)
      |> Plug.Conn.put_req_header("accept", @media_type)
      |> Router.call(Router.init([]))

    {conn.status, Jason.decode!(conn.resp_body)}
  end

  defp create_body(attributes), do: %{"data" => %{"type" => "item", "attributes" => attributes}}

  defp validator(context, method, path) do
    context.spec["paths"][path][method]["requestBody"]["content"][@media_type]["schema"]
    |> Map.put("components", context.spec["components"])
    |> json_schema(context.version)
    |> JSV.build!(Oaskit.default_jsv_opts())
  end
end
