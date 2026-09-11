defmodule AshOaskit.Schemas.ReferencesTest do
  use ExUnit.Case, async: true
  alias AshOaskit.Schemas.References

  test "literal payloads are not interpreted as schemas" do
    literal = %{"$ref" => "#/components/schemas/NotASchema"}

    schema = %{
      "type" => "object",
      "default" => literal,
      "const" => literal,
      "enum" => [literal],
      "examples" => [literal],
      "example" => literal,
      "x-data" => literal
    }

    assert References.validate!(schema, %{}) == :ok

    for version <- ["3.0", "3.1"] do
      spec =
        AshOaskit.spec(
          domains: [AshOaskit.Test.SimpleDomain],
          version: version,
          modify_open_api: fn spec -> Map.put(spec, "x-data", literal) end
        )

      assert spec["x-data"] === literal
    end
  end

  test "schema property and component names do not become skipped keywords" do
    for name <- ["example", "default", "examples", "const", "enum", "value", "x-data"] do
      schema = %{type: :object, properties: %{name => %{"$ref": "#/components/schemas/Missing"}}}
      assert_raise ArgumentError, ~r/Missing/, fn -> References.validate!(schema, %{}) end
      document = %{openapi: "3.1.0", components: %{schemas: %{name => schema}}}
      assert_raise ArgumentError, ~r/Missing/, fn -> References.validate!(document, %{}) end
    end
  end

  test "generation rejects atom-keyed missing references" do
    assert_raise ArgumentError, ~r/Missing/, fn ->
      AshOaskit.spec(
        domains: [AshOaskit.Test.SimpleDomain],
        modify_open_api: fn s ->
          put_in(s, [:components, :schemas, "Bad"], %{"$ref": "#/components/schemas/Missing"})
        end
      )
    end
  end

  test "escaped pointers resolve indexed string, atom, integer, boolean and array targets" do
    schemas = %{
      "A/B~ C" => %{
        properties: %{200 => true, "01" => %{}, :"201" => %{}, atom: false},
        anyOf: [%{}]
      }
    }

    for path <- [
          "properties/atom",
          "properties/200",
          "properties/201",
          "properties/01",
          "anyOf/0"
        ] do
      assert References.validate!(
               %{"$ref" => "#/components/schemas/A~1B~0%20C/" <> path},
               schemas
             ) == :ok
    end

    for path <- ["properties/new_missing_atom_123", "properties/0200", "anyOf/01", "anyOf/1"] do
      assert_raise ArgumentError, ~r/missing local/, fn ->
        References.validate!(%{"$ref" => "#/components/schemas/A~1B~0%20C/" <> path}, schemas)
      end
    end
  end

  test "invalid pointer encodings fail even when a similarly named key exists" do
    for pointer <- ["Bad~2Name", "Bad~", "Bad%", "Bad%GG", "%FF"] do
      assert_raise ArgumentError, ~r/missing local/, fn ->
        References.validate!(%{"$ref" => "#/components/schemas/" <> pointer}, %{pointer => %{}})
      end
    end
  end

  test "OpenAPI example values are literal but request and response schemas are traversed" do
    literal = %{"$ref" => "#/components/schemas/Literal"}

    document = %{
      openapi: "3.1.0",
      paths: %{
        "/items" => %{
          get: %{
            responses: %{
              "200" => %{
                content: %{
                  "application/json" => %{
                    examples: %{"demo" => %{value: literal}},
                    schema: %{"$ref" => "#/components/schemas/Result"}
                  }
                }
              }
            }
          }
        }
      }
    }

    assert References.validate!(document, %{"Result" => false}) == :ok
    assert_raise ArgumentError, ~r/Result/, fn -> References.validate!(document, %{}) end
  end

  test "default responses retain structural reference checks in both versions" do
    for version <- ["3.0", "3.1"] do
      assert_raise ArgumentError, ~r/Missing/, fn ->
        AshOaskit.spec(
          domains: [AshOaskit.Test.SimpleDomain],
          version: version,
          modify_open_api: fn spec ->
            Map.put(spec, :paths, %{
              "/items" => %{
                get: %{
                  responses: %{
                    "default" => %{
                      description: "error",
                      content: %{
                        "application/json" => %{
                          schema: %{"$ref" => "#/components/schemas/Missing"}
                        }
                      }
                    }
                  }
                }
              }
            })
          end
        )
      end
    end
  end

  test "named OpenAPI objects do not inherit keyword or extension semantics" do
    schema = %{"$ref" => "#/components/schemas/Missing"}

    for name <- ["default", "value", "schema", "x-header"] do
      document = %{openapi: "3.1.0", components: %{headers: %{name => %{schema: schema}}}}
      assert_raise ArgumentError, ~r/Missing/, fn -> References.validate!(document, %{}) end
    end
  end

  test "OpenAPI links and patterned-map extensions preserve literal payloads" do
    literal = %{"$ref" => "#/components/schemas/Literal"}

    document = %{
      openapi: "3.1.0",
      paths: %{
        "x-paths" => literal,
        "/items" => %{
          get: %{
            parameters: [%{name: "id", in: "query", schema: %{type: "string"}}],
            responses: %{
              "x-responses" => literal,
              "default" => %{
                description: "error",
                links: %{next: %{parameters: %{id: literal}, requestBody: literal}},
                content: %{
                  "application/json" => %{examples: %{default: %{value: literal}}}
                }
              }
            }
          }
        }
      }
    }

    assert References.validate!(document, %{}) == :ok
  end
end
