defmodule AshOaskit.SpecModifierTest do
  @moduledoc false

  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias AshOaskit.SpecModifier

  test "every mutating helper independently normalizes atom-key specs in both versions" do
    modifiers = [
      {"extension", &SpecModifier.add_extension(&1, ["info"], "x-tested", true)},
      {"request header", &SpecModifier.add_header_to_operations(&1, "X-Trace", %{})},
      {"response header", &SpecModifier.add_header_to_responses(&1, "X-Limit", %{})},
      {"server", &SpecModifier.add_server(&1, "https://example.com")},
      {"servers", &SpecModifier.set_servers(&1, [])},
      {"tag", &SpecModifier.add_tag(&1, "Posts")},
      {"external docs", &SpecModifier.add_external_docs(&1, "https://example.com/docs")},
      {"schema", &SpecModifier.add_schema(&1, "New", %{"type" => "string"})},
      {"response", &SpecModifier.add_response(&1, "Error", %{"description" => "Error"})},
      {"parameter",
       &SpecModifier.add_parameter(&1, "Page", %{"in" => "query", "name" => "page"})},
      {"webhook", &SpecModifier.add_webhook(&1, "New", %{})},
      {"info", &SpecModifier.update_info(&1, %{"title" => "Updated"})},
      {"schema examples", &SpecModifier.add_schema_examples(&1, "Post", [%{}])},
      {"operation examples",
       &SpecModifier.add_operation_example(&1, "listPosts", "application/json", %{"value" => %{}})},
      {"rate limit", SpecModifier.rate_limiting_modifier()},
      {"deprecation", SpecModifier.deprecation_modifier(operations: ["listPosts"])}
    ]

    for version <- ["3.0.3", "3.1.0"] do
      spec = %{
        openapi: version,
        info: %{title: "API", version: "1.0"},
        paths: %{
          "/posts" => %{
            get: %{operationId: "listPosts", responses: %{"200" => %{description: "Success"}}}
          }
        },
        components: %{schemas: %{"Post" => %{type: "object"}}}
      }

      normalized = Oaskit.normalize_spec!(spec)

      for {name, modify} <- modifiers do
        assert modify.(spec) == modify.(normalized), "#{name} must normalize OpenAPI #{version}"
      end
    end
  end

  test "helpers modify generated specs without atom/string key collisions" do
    for version <- ["3.0", "3.1"] do
      spec =
        AshOaskit.spec(
          domains: [AshOaskit.Test.Blog],
          version: version,
          modify_open_api: [
            &SpecModifier.add_header_to_operations(&1, "X-Trace", %{"type" => "string"}),
            &SpecModifier.update_info(&1, %{"title" => "Customized"}),
            &SpecModifier.add_schema(&1, "Custom", %{"type" => "string"}),
            &SpecModifier.add_extension(&1, ["info"], "x-tested", true)
          ]
        )

      assert spec["info"]["title"] == "Customized"
      assert spec["info"]["x-tested"]
      assert spec["components"]["schemas"]["Custom"] == %{"type" => "string"}
      assert spec["components"]["schemas"]["PostResource"]
      assert Enum.any?(spec["paths"]["/posts"]["get"]["parameters"], &(&1["name"] == "X-Trace"))
      refute Map.has_key?(spec, :paths)
    end
  end

  describe "apply_modifier/2" do
    test "applies function modifier" do
      spec = %{"info" => %{"title" => "API"}}
      modifier = fn s -> put_in(s, ["info", "version"], "2.0") end

      result = SpecModifier.apply_modifier(spec, modifier)

      assert result["info"]["version"] == "2.0"
      assert result["info"]["title"] == "API"
    end

    test "applies MFA tuple modifier" do
      spec = %{"info" => %{"title" => "API"}}
      modifier = {Map, :put, ["version", "1.0.0"]}

      result = SpecModifier.apply_modifier(spec, modifier)

      assert result["version"] == "1.0.0"
    end

    test "applies list of modifiers in sequence" do
      spec = %{"info" => %{}}

      modifiers = [
        fn s -> put_in(s, ["info", "title"], "API") end,
        fn s -> put_in(s, ["info", "version"], "1.0") end
      ]

      result = SpecModifier.apply_modifier(spec, modifiers)

      assert result["info"]["title"] == "API"
      assert result["info"]["version"] == "1.0"
    end

    test "returns spec unchanged for nil modifier" do
      spec = %{"info" => %{"title" => "API"}}

      result = SpecModifier.apply_modifier(spec, nil)

      assert result == spec
    end

    test "returns spec unchanged for invalid modifier" do
      spec = %{"info" => %{"title" => "API"}}

      log =
        capture_log(fn ->
          result = SpecModifier.apply_modifier(spec, "invalid")
          assert result == spec
        end)

      assert log =~ "ignoring invalid spec modifier"
    end

    test "handles empty list of modifiers" do
      spec = %{"info" => %{"title" => "API"}}

      result = SpecModifier.apply_modifier(spec, [])

      assert result == spec
    end

    test "chains function and MFA modifiers" do
      spec = %{"info" => %{}}

      modifiers = [
        fn s -> put_in(s, ["info", "title"], "API") end,
        {Map, :put, ["version", "1.0.0"]}
      ]

      result = SpecModifier.apply_modifier(spec, modifiers)

      assert result["info"]["title"] == "API"
      assert result["version"] == "1.0.0"
    end
  end

  describe "add_extension/4" do
    test "adds extension at root level" do
      spec = %{"info" => %{"title" => "API"}}

      result = SpecModifier.add_extension(spec, [], "x-custom", "value")

      assert result["x-custom"] == "value"
    end

    test "adds extension at nested path" do
      spec = %{"info" => %{"title" => "API"}}

      result = SpecModifier.add_extension(spec, ["info"], "x-logo", %{"url" => "logo.png"})

      assert result["info"]["x-logo"] == %{"url" => "logo.png"}
    end

    test "preserves existing fields" do
      spec = %{"info" => %{"title" => "API", "version" => "1.0"}}

      result = SpecModifier.add_extension(spec, ["info"], "x-custom", "value")

      assert result["info"]["title"] == "API"
      assert result["info"]["version"] == "1.0"
      assert result["info"]["x-custom"] == "value"
    end

    test "creates nested paths if they don't exist" do
      spec = %{}

      result = SpecModifier.add_extension(spec, ["info"], "x-custom", "value")

      assert result["info"]["x-custom"] == "value"
    end
  end

  describe "add_header_to_operations/4" do
    test "an empty operation selection leaves the entire spec unchanged" do
      spec = %{"paths" => %{"/posts" => %{"get" => %{"operationId" => "listPosts"}}}}

      assert SpecModifier.add_header_to_operations(spec, "X-Trace", %{}, operations: []) == spec
    end

    test "selected IDs do not match operations without an ID" do
      spec = %{
        "paths" => %{
          "/posts" => %{
            "get" => %{},
            "post" => %{"operationId" => "createPost"},
            "delete" => %{"operationId" => "deletePost"}
          }
        }
      }

      result =
        SpecModifier.add_header_to_operations(spec, "X-Trace", %{}, operations: ["createPost"])

      assert result["paths"]["/posts"]["get"] == %{}
      assert result["paths"]["/posts"]["delete"] == spec["paths"]["/posts"]["delete"]
      assert [%{"name" => "X-Trace"}] = result["paths"]["/posts"]["post"]["parameters"]
    end

    test "updates all HTTP methods but preserves path metadata and non-map operations" do
      methods = ~w(get put post delete options head patch trace)

      metadata = %{
        "$ref" => "#/components/pathItems/Posts",
        "summary" => "Posts",
        "description" => "Post operations",
        "parameters" => [%{"name" => "id", "in" => "path"}],
        "servers" => [%{"url" => "https://example.com"}],
        "x-metadata" => %{"operationId" => "notAnOperation"}
      }

      path_item = Map.merge(metadata, Map.new(methods, &{&1, %{}}))
      invalid_operations = %{"get" => nil, "post" => "invalid"}
      spec = %{"paths" => %{"/posts" => path_item, "/invalid" => invalid_operations}}

      result = SpecModifier.add_header_to_operations(spec, "X-Trace", %{})

      assert Map.drop(result["paths"]["/posts"], methods) == metadata
      assert result["paths"]["/invalid"] == invalid_operations

      for method <- methods do
        assert [%{"name" => "X-Trace"}] = result["paths"]["/posts"][method]["parameters"]
      end
    end

    test "creates an empty paths map when none exists" do
      assert SpecModifier.add_header_to_operations(%{"info" => %{}}, "X-Trace", %{}) == %{
               "info" => %{},
               "paths" => %{}
             }
    end

    test "replaces headers case-insensitively while preserving other parameters" do
      query = %{"in" => "query", "name" => "X-Request-ID"}
      reference = %{"$ref" => "#/components/parameters/Page"}

      spec = %{
        "paths" => %{
          "/posts" => %{
            "get" => %{
              "parameters" => [
                %{"in" => "header", "name" => "x-request-id"},
                query,
                reference
              ]
            }
          }
        }
      }

      result = SpecModifier.add_header_to_operations(spec, "X-Request-ID", %{"type" => "string"})

      assert [^query, ^reference, header] = result["paths"]["/posts"]["get"]["parameters"]

      assert header == %{
               "in" => "header",
               "name" => "X-Request-ID",
               "required" => false,
               "schema" => %{"type" => "string"}
             }
    end

    test "adds header to all operations" do
      spec = %{
        "paths" => %{
          "/posts" => %{
            "get" => %{"operationId" => "listPosts"},
            "post" => %{"operationId" => "createPost"}
          }
        }
      }

      result = SpecModifier.add_header_to_operations(spec, "X-Request-ID", %{"type" => "string"})

      get_params = result["paths"]["/posts"]["get"]["parameters"]
      post_params = result["paths"]["/posts"]["post"]["parameters"]

      assert length(get_params) == 1
      assert length(post_params) == 1
      assert hd(get_params)["name"] == "X-Request-ID"
    end

    test "adds header only to specified operations" do
      spec = %{
        "paths" => %{
          "/posts" => %{
            "get" => %{"operationId" => "listPosts"},
            "post" => %{"operationId" => "createPost"}
          }
        }
      }

      result =
        SpecModifier.add_header_to_operations(
          spec,
          "X-Request-ID",
          %{"type" => "string"},
          operations: ["listPosts"]
        )

      get_params = result["paths"]["/posts"]["get"]["parameters"]
      post_params = result["paths"]["/posts"]["post"]["parameters"]

      assert length(get_params) == 1
      assert post_params == nil or post_params == []
    end

    test "sets required flag" do
      spec = %{
        "paths" => %{
          "/posts" => %{"get" => %{"operationId" => "listPosts"}}
        }
      }

      result =
        SpecModifier.add_header_to_operations(
          spec,
          "Authorization",
          %{"type" => "string"},
          required: true
        )

      header = hd(result["paths"]["/posts"]["get"]["parameters"])
      assert header["required"] == true
    end

    test "appends to existing parameters" do
      spec = %{
        "paths" => %{
          "/posts" => %{
            "get" => %{
              "operationId" => "listPosts",
              "parameters" => [%{"name" => "page", "in" => "query"}]
            }
          }
        }
      }

      result = SpecModifier.add_header_to_operations(spec, "X-Request-ID", %{"type" => "string"})

      params = result["paths"]["/posts"]["get"]["parameters"]
      assert length(params) == 2
    end
  end

  describe "add_server/3" do
    test "adds server to empty servers list" do
      spec = %{}

      result = SpecModifier.add_server(spec, "https://api.example.com")

      assert length(result["servers"]) == 1
      assert hd(result["servers"])["url"] == "https://api.example.com"
    end

    test "appends to existing servers" do
      spec = %{"servers" => [%{"url" => "https://api.example.com"}]}

      result = SpecModifier.add_server(spec, "https://staging.example.com")

      assert result["servers"] == [
               %{"url" => "https://api.example.com"},
               %{"url" => "https://staging.example.com"}
             ]
    end

    test "includes description when provided" do
      spec = %{}

      result = SpecModifier.add_server(spec, "https://api.example.com", description: "Production")

      assert hd(result["servers"])["description"] == "Production"
    end

    test "includes variables when provided" do
      spec = %{}

      variables = %{
        "port" => %{"default" => "443", "enum" => ["443", "8443"]}
      }

      result =
        SpecModifier.add_server(spec, "https://api.example.com:{port}", variables: variables)

      assert hd(result["servers"])["variables"] == variables
    end
  end

  describe "set_servers/2" do
    test "replaces servers list" do
      spec = %{"servers" => [%{"url" => "/"}]}
      new_servers = [%{"url" => "https://api.example.com"}]

      result = SpecModifier.set_servers(spec, new_servers)

      assert result["servers"] == new_servers
    end

    test "works with empty list" do
      spec = %{"servers" => [%{"url" => "/"}]}

      result = SpecModifier.set_servers(spec, [])

      assert result["servers"] == []
    end
  end

  describe "add_tag/3" do
    test "adds tag to empty tags list" do
      spec = %{}

      result = SpecModifier.add_tag(spec, "Posts")

      assert length(result["tags"]) == 1
      assert hd(result["tags"])["name"] == "Posts"
    end

    test "appends to existing tags" do
      spec = %{"tags" => [%{"name" => "Posts"}]}

      result = SpecModifier.add_tag(spec, "Comments")

      assert result["tags"] == [%{"name" => "Posts"}, %{"name" => "Comments"}]
    end

    test "includes description when provided" do
      spec = %{}

      result = SpecModifier.add_tag(spec, "Posts", description: "Blog post operations")

      assert hd(result["tags"])["description"] == "Blog post operations"
    end

    test "includes external docs when provided" do
      spec = %{}
      external_docs = %{"url" => "https://docs.example.com/posts"}

      result = SpecModifier.add_tag(spec, "Posts", external_docs: external_docs)

      assert hd(result["tags"])["externalDocs"] == external_docs
    end
  end

  describe "add_external_docs/3" do
    test "adds external docs to spec" do
      spec = %{"info" => %{"title" => "API"}}

      result = SpecModifier.add_external_docs(spec, "https://docs.example.com")

      assert result["externalDocs"]["url"] == "https://docs.example.com"
    end

    test "includes description when provided" do
      spec = %{}

      result =
        SpecModifier.add_external_docs(
          spec,
          "https://docs.example.com",
          description: "Full documentation"
        )

      assert result["externalDocs"]["description"] == "Full documentation"
    end
  end

  describe "add_schema/3" do
    test "adds schema to components" do
      spec = %{"components" => %{"schemas" => %{}}}
      schema = %{"type" => "object", "properties" => %{"id" => %{"type" => "string"}}}

      result = SpecModifier.add_schema(spec, "CustomResource", schema)

      assert result["components"]["schemas"]["CustomResource"] == schema
    end

    test "creates components if not present" do
      spec = %{}
      schema = %{"type" => "object"}

      result = SpecModifier.add_schema(spec, "Resource", schema)

      assert result["components"]["schemas"]["Resource"] == schema
    end

    test "preserves existing schemas" do
      spec = %{
        "components" => %{
          "schemas" => %{
            "Existing" => %{"type" => "string"}
          }
        }
      }

      result = SpecModifier.add_schema(spec, "New", %{"type" => "object"})

      assert Map.has_key?(result["components"]["schemas"], "Existing")
      assert Map.has_key?(result["components"]["schemas"], "New")
    end
  end

  describe "add_response/3" do
    test "adds response to components" do
      spec = %{"components" => %{}}
      response = %{"description" => "Rate limit exceeded"}

      result = SpecModifier.add_response(spec, "RateLimitError", response)

      assert result["components"]["responses"]["RateLimitError"] == response
    end

    test "creates responses section if not present" do
      spec = %{}

      result = SpecModifier.add_response(spec, "Error", %{"description" => "Error"})

      assert Map.has_key?(result["components"]["responses"], "Error")
    end
  end

  describe "add_parameter/3" do
    test "adds parameter to components" do
      spec = %{"components" => %{}}
      param = %{"name" => "page", "in" => "query", "schema" => %{"type" => "integer"}}

      result = SpecModifier.add_parameter(spec, "PageParam", param)

      assert result["components"]["parameters"]["PageParam"] == param
    end

    test "creates parameters section if not present" do
      spec = %{}
      param = %{"name" => "limit", "in" => "query", "schema" => %{"type" => "integer"}}

      result = SpecModifier.add_parameter(spec, "LimitParam", param)

      assert Map.has_key?(result["components"]["parameters"], "LimitParam")
    end
  end

  describe "add_webhook/3" do
    test "adds webhook to spec" do
      spec = %{}

      webhook = %{
        "post" => %{
          "summary" => "New post created",
          "requestBody" => %{"content" => %{}}
        }
      }

      result = SpecModifier.add_webhook(spec, "newPost", webhook)

      assert result["webhooks"]["newPost"] == webhook
    end

    test "appends to existing webhooks" do
      spec = %{"webhooks" => %{"existing" => %{}}}

      result = SpecModifier.add_webhook(spec, "new", %{})

      assert Map.has_key?(result["webhooks"], "existing")
      assert Map.has_key?(result["webhooks"], "new")
    end
  end

  describe "update_info/2" do
    test "updates info section" do
      spec = %{"info" => %{"title" => "API", "version" => "1.0"}}

      result =
        SpecModifier.update_info(spec, %{
          "contact" => %{"email" => "support@example.com"}
        })

      assert result["info"]["contact"]["email"] == "support@example.com"
      assert result["info"]["title"] == "API"
    end

    test "creates info section if not present" do
      spec = %{}

      result = SpecModifier.update_info(spec, %{"title" => "New API"})

      assert result["info"]["title"] == "New API"
    end

    test "overwrites existing fields" do
      spec = %{"info" => %{"title" => "Old Title"}}

      result = SpecModifier.update_info(spec, %{"title" => "New Title"})

      assert result["info"]["title"] == "New Title"
    end
  end

  describe "add_schema_examples/3" do
    test "adds examples to existing schema" do
      spec = %{
        "components" => %{
          "schemas" => %{
            "Post" => %{"type" => "object", "properties" => %{}}
          }
        }
      }

      examples = [%{"id" => "1", "title" => "Hello"}]

      result = SpecModifier.add_schema_examples(spec, "Post", examples)

      assert result["components"]["schemas"]["Post"]["examples"] == examples
    end

    test "returns spec unchanged for non-existent schema" do
      spec = %{"components" => %{"schemas" => %{}}}

      result = SpecModifier.add_schema_examples(spec, "NonExistent", [%{}])

      assert result == spec
    end

    test "returns spec unchanged when intermediate path key is missing" do
      spec = %{"info" => %{"title" => "API"}}

      result = SpecModifier.add_schema_examples(spec, "Post", [%{"id" => "1"}])

      assert result == spec
    end

    test "returns spec unchanged when schemas key is missing" do
      spec = %{"components" => %{}}

      result = SpecModifier.add_schema_examples(spec, "Post", [%{"id" => "1"}])

      assert result == spec
    end
  end

  describe "add_operation_example/4" do
    test "creates missing content and media entries for every selected response" do
      responses = %{
        "200" => %{"description" => "Success"},
        "400" => %{"description" => "Bad request", "content" => %{}}
      }

      operation = %{"operationId" => "listPosts", "responses" => responses}

      spec = %{
        "paths" => %{
          "/posts" => %{
            "get" => operation,
            "post" => %{"operationId" => "createPost", "responses" => responses}
          }
        }
      }

      example = %{"value" => %{}}
      result = SpecModifier.add_operation_example(spec, "listPosts", "application/json", example)

      assert result["paths"]["/posts"]["post"] == spec["paths"]["/posts"]["post"]

      for {code, response} <- responses do
        assert result["paths"]["/posts"]["get"]["responses"][code] ==
                 Map.put(response, "content", %{
                   "application/json" => %{"examples" => %{"example_1" => example}}
                 })
      end
    end

    test "replaces a named example without duplicating it or losing other examples" do
      spec = %{
        "paths" => %{
          "/posts" => %{
            "get" => %{
              "operationId" => "listPosts",
              "responses" => %{"200" => %{"description" => "Success"}}
            }
          }
        }
      }

      first = %{"summary" => "First", "value" => 1}
      second = %{"summary" => "Second", "value" => 2}
      replacement = %{"summary" => "First", "value" => 3}

      result =
        spec
        |> SpecModifier.add_operation_example("listPosts", "application/json", first)
        |> SpecModifier.add_operation_example("listPosts", "application/json", second)
        |> SpecModifier.add_operation_example("listPosts", "application/json", replacement)

      assert get_in(result, [
               "paths",
               "/posts",
               "get",
               "responses",
               "200",
               "content",
               "application/json",
               "examples"
             ]) == %{"First" => replacement, "Second" => second}
    end

    test "preserves response content and numbers unnamed examples" do
      existing = %{"value" => %{"id" => "1"}}
      schema = %{"type" => "object"}
      text_media = %{"schema" => %{"type" => "string"}}

      response = %{
        "description" => "Success",
        "content" => %{
          "application/json" => %{"schema" => schema, "examples" => %{"first" => existing}},
          "text/plain" => text_media
        }
      }

      spec = %{
        "paths" => %{
          "/posts" => %{
            "get" => %{"operationId" => "listPosts", "responses" => %{"200" => response}}
          }
        }
      }

      example = %{"value" => %{"id" => "2"}}
      result = SpecModifier.add_operation_example(spec, "listPosts", "application/json", example)
      updated = result["paths"]["/posts"]["get"]["responses"]["200"]

      assert updated["description"] == "Success"
      assert updated["content"]["text/plain"] == text_media

      assert updated["content"]["application/json"] == %{
               "schema" => schema,
               "examples" => %{"first" => existing, "example_2" => example}
             }
    end

    test "adds example to operation response" do
      spec = %{
        "paths" => %{
          "/posts" => %{
            "get" => %{
              "operationId" => "listPosts",
              "responses" => %{
                "200" => %{
                  "description" => "Success",
                  "content" => %{
                    "application/json" => %{}
                  }
                }
              }
            }
          }
        }
      }

      example = %{"summary" => "List posts", "value" => %{"data" => []}}

      result = SpecModifier.add_operation_example(spec, "listPosts", "application/json", example)

      examples =
        result["paths"]["/posts"]["get"]["responses"]["200"]["content"]["application/json"][
          "examples"
        ]

      assert Map.has_key?(examples, "List posts")
    end
  end

  describe "rate_limiting_modifier/1" do
    test "creates modifier that adds rate limit extension" do
      modifier = SpecModifier.rate_limiting_modifier(limit: 100, window: "1 minute")
      spec = %{"info" => %{}, "paths" => %{"/posts" => %{"get" => %{}}}}

      result = SpecModifier.apply_modifier(spec, modifier)

      assert result["info"]["x-rateLimit"]["limit"] == 100
      assert result["info"]["x-rateLimit"]["window"] == "1 minute"
    end

    test "adds rate limit response headers without request parameters or reference siblings" do
      modifier = SpecModifier.rate_limiting_modifier()

      spec = %{
        "info" => %{},
        "paths" => %{
          "/posts" => %{
            "get" => %{
              "responses" => %{
                "200" => %{"description" => "OK"},
                "400" => %{"$ref" => "#/components/responses/Error"}
              }
            },
            "x-metadata" => %{"keep" => true}
          }
        }
      }

      result = SpecModifier.apply_modifier(spec, modifier)

      operation = result["paths"]["/posts"]["get"]
      refute Map.has_key?(operation, "parameters")
      assert operation["responses"]["400"] == %{"$ref" => "#/components/responses/Error"}
      assert result["paths"]["/posts"]["x-metadata"] == %{"keep" => true}
      header_names = Map.keys(operation["responses"]["200"]["headers"])

      assert "X-RateLimit-Limit" in header_names
      assert "X-RateLimit-Remaining" in header_names
      assert "X-RateLimit-Reset" in header_names
    end

    test "uses default values" do
      modifier = SpecModifier.rate_limiting_modifier()
      spec = %{"info" => %{}, "paths" => %{}}

      result = SpecModifier.apply_modifier(spec, modifier)

      assert result["info"]["x-rateLimit"]["limit"] == 100
      assert result["info"]["x-rateLimit"]["window"] == "1 minute"
    end
  end

  describe "deprecation_modifier/1" do
    test "preserves an existing sunset when none is supplied and appends the description" do
      operation = %{
        "operationId" => "oldEndpoint",
        "description" => "Existing description",
        "x-sunset" => "2030-01-01"
      }

      spec = %{"paths" => %{"/old" => %{"get" => operation}}}

      modifier =
        SpecModifier.deprecation_modifier(operations: ["oldEndpoint"], message: "Use new")

      result = SpecModifier.apply_modifier(spec, modifier)

      assert result["paths"]["/old"]["get"] == %{
               "operationId" => "oldEndpoint",
               "description" => "Existing description\n\n**Deprecated:** Use new",
               "deprecated" => true,
               "x-sunset" => "2030-01-01"
             }
    end

    test "marks specified operations as deprecated" do
      modifier =
        SpecModifier.deprecation_modifier(
          operations: ["oldEndpoint"],
          message: "Use newEndpoint instead"
        )

      spec = %{
        "paths" => %{
          "/old" => %{"get" => %{"operationId" => "oldEndpoint", "description" => "Old endpoint"}},
          "/new" => %{"get" => %{"operationId" => "newEndpoint"}}
        }
      }

      result = SpecModifier.apply_modifier(spec, modifier)

      assert result["paths"]["/old"]["get"]["deprecated"] == true
      assert String.contains?(result["paths"]["/old"]["get"]["description"], "Deprecated")
      refute Map.get(result["paths"]["/new"]["get"], "deprecated")
    end

    test "adds sunset date when provided" do
      modifier =
        SpecModifier.deprecation_modifier(
          operations: ["oldEndpoint"],
          sunset: "2024-12-31"
        )

      spec = %{
        "paths" => %{
          "/old" => %{"get" => %{"operationId" => "oldEndpoint"}}
        }
      }

      result = SpecModifier.apply_modifier(spec, modifier)

      assert result["paths"]["/old"]["get"]["x-sunset"] == "2024-12-31"
    end
  end

  describe "component map updates" do
    test "each component helper creates missing parent maps" do
      helpers = [
        {"schemas", &SpecModifier.add_schema/3},
        {"responses", &SpecModifier.add_response/3},
        {"parameters", &SpecModifier.add_parameter/3}
      ]

      for {section, add} <- helpers, spec <- [%{}, %{"components" => %{}}] do
        assert add.(spec, "New", %{}) == %{"components" => %{section => %{"New" => %{}}}}
      end
    end

    test "each component helper replaces only the named entry and preserves siblings" do
      helpers = [
        {"schemas", &SpecModifier.add_schema/3},
        {"responses", &SpecModifier.add_response/3},
        {"parameters", &SpecModifier.add_parameter/3}
      ]

      for {section, add} <- helpers do
        spec = %{
          "info" => %{"title" => "Keep"},
          "components" => %{
            "securitySchemes" => %{"Bearer" => %{"type" => "http", "scheme" => "bearer"}},
            section => %{"Target" => %{"description" => "Old"}, "Sibling" => %{}}
          }
        }

        replacement = %{"description" => "New"}

        assert add.(spec, "Target", replacement) ==
                 put_in(spec, ["components", section, "Target"], replacement)
      end
    end
  end

  describe "add_header_to_responses/4" do
    test "updates every inline response but preserves references, other headers and request parameters" do
      reference = %{"$ref" => "#/components/responses/Error"}
      request_parameters = [%{"in" => "header", "name" => "X-Request"}]
      other_header = %{"schema" => %{"type" => "string"}}

      responses = %{
        "200" => %{
          "description" => "Success",
          "headers" => %{"X-Other" => other_header, "X-Limit" => other_header}
        },
        "201" => %{"description" => "Created"},
        "400" => reference,
        "default" => nil
      }

      spec = %{
        "paths" => %{
          "/posts" => %{
            "get" => %{"responses" => responses, "parameters" => request_parameters}
          }
        }
      }

      schema = %{"type" => "integer"}
      result = SpecModifier.add_header_to_responses(spec, "X-Limit", schema)
      operation = result["paths"]["/posts"]["get"]

      assert operation["parameters"] == request_parameters

      assert operation["responses"] == %{
               "200" => %{
                 "description" => "Success",
                 "headers" => %{"X-Other" => other_header, "X-Limit" => %{"schema" => schema}}
               },
               "201" => %{
                 "description" => "Created",
                 "headers" => %{"X-Limit" => %{"schema" => schema}}
               },
               "400" => reference,
               "default" => nil
             }
    end

    test "honors operation selection" do
      responses = %{"200" => %{"description" => "Success"}}

      spec = %{
        "paths" => %{
          "/posts" => %{
            "get" => %{"operationId" => "listPosts", "responses" => responses},
            "post" => %{"operationId" => "createPost", "responses" => responses}
          }
        }
      }

      result =
        SpecModifier.add_header_to_responses(spec, "X-Limit", %{}, operations: ["listPosts"])

      assert result["paths"]["/posts"]["post"] == spec["paths"]["/posts"]["post"]

      assert result["paths"]["/posts"]["get"]["responses"]["200"]["headers"] == %{
               "X-Limit" => %{"schema" => %{}}
             }

      assert SpecModifier.add_header_to_responses(spec, "X-Limit", %{}, operations: []) == spec
    end

    test "response modifiers handle absent and empty responses without inventing status codes" do
      modifiers = [
        &SpecModifier.add_header_to_responses(&1, "X-Limit", %{}),
        &SpecModifier.add_operation_example(&1, "listPosts", "application/json", %{"value" => %{}})
      ]

      for modify <- modifiers, responses <- [%{}, %{"responses" => %{}}] do
        operation = Map.put(responses, "operationId", "listPosts")
        spec = %{"paths" => %{"/posts" => %{"get" => operation}}}

        assert modify.(spec) == put_in(spec, ["paths", "/posts", "get", "responses"], %{})
      end
    end
  end

  describe "schema structure validation" do
    test "all modifier results can be serialized to JSON" do
      spec = %{
        "info" => %{"title" => "API"},
        "paths" => %{"/posts" => %{"get" => %{"operationId" => "listPosts"}}},
        "components" => %{"schemas" => %{}}
      }

      results = [
        SpecModifier.add_extension(spec, [], "x-test", "value"),
        SpecModifier.add_server(spec, "https://api.example.com"),
        SpecModifier.add_tag(spec, "Test"),
        SpecModifier.add_schema(spec, "Test", %{"type" => "object"}),
        SpecModifier.add_webhook(spec, "test", %{})
      ]

      for result <- results do
        assert {:ok, _} = Jason.encode(result)
      end
    end
  end

  describe "integration scenarios" do
    test "building a complete spec modification pipeline" do
      spec = %{
        "openapi" => "3.1.0",
        "info" => %{"title" => "My API", "version" => "1.0.0"},
        "paths" => %{
          "/posts" => %{
            "get" => %{"operationId" => "listPosts", "responses" => %{}},
            "post" => %{"operationId" => "createPost", "responses" => %{}}
          }
        },
        "components" => %{"schemas" => %{}}
      }

      modifiers = [
        # Add custom branding
        fn s -> SpecModifier.add_extension(s, ["info"], "x-logo", %{"url" => "logo.png"}) end,

        # Add production server
        fn s ->
          SpecModifier.add_server(s, "https://api.example.com", description: "Production")
        end,

        # Add contact info
        fn s ->
          SpecModifier.update_info(s, %{
            "contact" => %{"name" => "API Support", "email" => "api@example.com"}
          })
        end,

        # Add common header
        fn s ->
          SpecModifier.add_header_to_operations(s, "X-Request-ID", %{
            "type" => "string",
            "format" => "uuid"
          })
        end
      ]

      result = SpecModifier.apply_modifier(spec, modifiers)

      assert result["info"]["x-logo"]["url"] == "logo.png"
      assert length(result["servers"]) == 1
      assert result["info"]["contact"]["email"] == "api@example.com"
      assert length(result["paths"]["/posts"]["get"]["parameters"]) == 1
    end

    test "using MFA modifiers for environment-specific configuration" do
      defmodule TestModifier do
        @spec add_env_server(map(), atom()) :: map()
        def add_env_server(spec, env) do
          url =
            case env do
              :prod -> "https://api.example.com"
              :staging -> "https://staging.example.com"
              :dev -> "http://localhost:4000"
            end

          AshOaskit.SpecModifier.set_servers(spec, [%{"url" => url}])
        end
      end

      spec = %{"servers" => [%{"url" => "/"}]}

      prod_result = SpecModifier.apply_modifier(spec, {TestModifier, :add_env_server, [:prod]})

      staging_result =
        SpecModifier.apply_modifier(spec, {TestModifier, :add_env_server, [:staging]})

      assert hd(prod_result["servers"])["url"] == "https://api.example.com"
      assert hd(staging_result["servers"])["url"] == "https://staging.example.com"
    end
  end

  describe "apply_modifier/2 with invalid input" do
    test "returns spec unchanged for invalid modifier types" do
      spec = %{"info" => %{"title" => "API"}}

      log =
        capture_log(fn ->
          assert SpecModifier.apply_modifier(spec, :invalid_atom) == spec
          assert SpecModifier.apply_modifier(spec, 42) == spec
          assert SpecModifier.apply_modifier(spec, "string") == spec
        end)

      assert log =~ "ignoring invalid spec modifier: :invalid_atom"
      assert log =~ "ignoring invalid spec modifier: 42"
      assert log =~ ~s(ignoring invalid spec modifier: "string")
    end
  end

  describe "deprecation_modifier with defaults" do
    test "deprecation_modifier with no options does not modify operations" do
      modifier = SpecModifier.deprecation_modifier()
      spec = %{"paths" => %{"/a" => %{"get" => %{"operationId" => "any"}}}}
      result = SpecModifier.apply_modifier(spec, modifier)
      assert result == spec
    end
  end
end
