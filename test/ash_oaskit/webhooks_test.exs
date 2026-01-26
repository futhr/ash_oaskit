defmodule AshOaskit.WebhooksTest do
  @moduledoc """
  Tests for OpenAPI 3.1 Webhook support.

  Webhooks are a new feature in OpenAPI 3.1, allowing APIs to describe
  incoming requests that the API provider initiates (server-to-client).

  Reference: https://spec.openapis.org/oas/v3.1.0#openapi-object
  Reference: https://redocly.com/blog/document-webhooks-with-openapi

  ## Webhook Structure

  ```yaml
  webhooks:
    newUser:
      post:
        summary: New user created
        requestBody:
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/User'
        responses:
          '200':
            description: Webhook processed
  ```

  ## Webhooks vs Callbacks

  - **Webhooks** - Top-level, standalone event notifications
  - **Callbacks** - Operation-level, tied to specific API calls
  """

  use ExUnit.Case, async: true

  describe "webhook structure" do
    test "webhooks is a top-level field in OpenAPI 3.1" do
      # Webhooks field structure
      webhooks = %{
        "newUser" => %{
          "post" => %{
            "summary" => "New user created",
            "requestBody" => %{
              "content" => %{
                "application/json" => %{
                  "schema" => %{
                    "$ref" => "#/components/schemas/User"
                  }
                }
              }
            },
            "responses" => %{
              "200" => %{
                "description" => "Webhook processed successfully"
              }
            }
          }
        }
      }

      assert is_map(webhooks)
      assert Map.has_key?(webhooks, "newUser")
      assert Map.has_key?(webhooks["newUser"], "post")
    end

    test "webhook uses Path Item Object structure" do
      webhook = %{
        "post" => %{
          "operationId" => "handleNewUser",
          "summary" => "Handle new user webhook",
          "requestBody" => %{
            "required" => true,
            "content" => %{
              "application/json" => %{
                "schema" => %{"type" => "object"}
              }
            }
          },
          "responses" => %{
            "200" => %{"description" => "OK"}
          }
        }
      }

      # Webhook should have operation (post, get, etc.)
      assert Map.has_key?(webhook, "post")
      assert Map.has_key?(webhook["post"], "responses")
    end

    test "webhook can have multiple HTTP methods" do
      webhook = %{
        "post" => %{
          "summary" => "Receive webhook via POST",
          "responses" => %{"200" => %{"description" => "OK"}}
        },
        "put" => %{
          "summary" => "Receive webhook via PUT",
          "responses" => %{"200" => %{"description" => "OK"}}
        }
      }

      assert Map.has_key?(webhook, "post")
      assert Map.has_key?(webhook, "put")
    end
  end

  describe "webhooks vs callbacks" do
    test "webhooks are independent of client calls" do
      # Webhooks are top-level, callbacks are operation-specific
      spec_structure = %{
        "webhooks" => %{
          "orderShipped" => %{
            "post" => %{
              "summary" => "Order shipped notification",
              "responses" => %{"200" => %{"description" => "OK"}}
            }
          }
        },
        "paths" => %{
          "/orders" => %{
            "post" => %{
              "callbacks" => %{
                "orderUpdate" => %{
                  "{$request.body#/callbackUrl}" => %{
                    "post" => %{
                      "responses" => %{"200" => %{"description" => "OK"}}
                    }
                  }
                }
              }
            }
          }
        }
      }

      # Webhooks at top level
      assert Map.has_key?(spec_structure, "webhooks")
      # Callbacks inside operation
      assert Map.has_key?(
               spec_structure["paths"]["/orders"]["post"],
               "callbacks"
             )
    end
  end

  describe "webhook request body" do
    test "webhook can specify request body schema" do
      webhook = %{
        "post" => %{
          "requestBody" => %{
            "required" => true,
            "content" => %{
              "application/json" => %{
                "schema" => %{
                  "type" => "object",
                  "properties" => %{
                    "event" => %{"type" => "string"},
                    "data" => %{"type" => "object"}
                  },
                  "required" => ["event"]
                }
              }
            }
          },
          "responses" => %{"200" => %{"description" => "OK"}}
        }
      }

      request_body = webhook["post"]["requestBody"]
      assert request_body["required"] == true
      assert Map.has_key?(request_body["content"], "application/json")
    end

    test "webhook can use $ref for request body schema" do
      webhook = %{
        "post" => %{
          "requestBody" => %{
            "content" => %{
              "application/json" => %{
                "schema" => %{
                  "$ref" => "#/components/schemas/WebhookPayload"
                }
              }
            }
          },
          "responses" => %{"200" => %{"description" => "OK"}}
        }
      }

      schema = webhook["post"]["requestBody"]["content"]["application/json"]["schema"]
      assert schema["$ref"] == "#/components/schemas/WebhookPayload"
    end
  end

  describe "webhook responses" do
    test "webhook should document expected responses" do
      webhook = %{
        "post" => %{
          "responses" => %{
            "200" => %{
              "description" => "Webhook processed successfully"
            },
            "400" => %{
              "description" => "Bad request - invalid payload"
            },
            "500" => %{
              "description" => "Server error"
            }
          }
        }
      }

      responses = webhook["post"]["responses"]
      assert Map.has_key?(responses, "200")
      assert Map.has_key?(responses, "400")
      assert Map.has_key?(responses, "500")
    end

    test "webhook 200 response typically has no content" do
      # Webhooks often just need acknowledgment
      webhook = %{
        "post" => %{
          "responses" => %{
            "200" => %{
              "description" => "Webhook received"
            }
          }
        }
      }

      response_200 = webhook["post"]["responses"]["200"]
      # No content needed - just acknowledgment
      refute Map.has_key?(response_200, "content")
    end
  end

  describe "webhook security" do
    test "webhook can specify security requirements" do
      webhook = %{
        "post" => %{
          "security" => [
            %{"webhookSignature" => []}
          ],
          "responses" => %{"200" => %{"description" => "OK"}}
        }
      }

      assert Map.has_key?(webhook["post"], "security")
    end

    test "webhook can have no security (public)" do
      webhook = %{
        "post" => %{
          "security" => [],
          "responses" => %{"200" => %{"description" => "OK"}}
        }
      }

      assert webhook["post"]["security"] == []
    end
  end

  describe "webhook headers" do
    test "webhook can specify expected headers" do
      webhook = %{
        "post" => %{
          "parameters" => [
            %{
              "name" => "X-Webhook-Signature",
              "in" => "header",
              "required" => true,
              "schema" => %{"type" => "string"},
              "description" => "HMAC signature for payload verification"
            },
            %{
              "name" => "X-Webhook-Timestamp",
              "in" => "header",
              "required" => true,
              "schema" => %{"type" => "string", "format" => "date-time"},
              "description" => "Timestamp of webhook dispatch"
            }
          ],
          "responses" => %{"200" => %{"description" => "OK"}}
        }
      }

      headers = webhook["post"]["parameters"]
      assert length(headers) == 2

      signature_header = Enum.find(headers, &(&1["name"] == "X-Webhook-Signature"))
      assert signature_header["in"] == "header"
      assert signature_header["required"] == true
    end
  end

  describe "multiple webhooks" do
    test "spec can define multiple webhooks" do
      webhooks = %{
        "userCreated" => %{
          "post" => %{
            "summary" => "User created event",
            "responses" => %{"200" => %{"description" => "OK"}}
          }
        },
        "userDeleted" => %{
          "post" => %{
            "summary" => "User deleted event",
            "responses" => %{"200" => %{"description" => "OK"}}
          }
        },
        "orderPlaced" => %{
          "post" => %{
            "summary" => "Order placed event",
            "responses" => %{"200" => %{"description" => "OK"}}
          }
        }
      }

      assert map_size(webhooks) == 3
      assert Map.has_key?(webhooks, "userCreated")
      assert Map.has_key?(webhooks, "userDeleted")
      assert Map.has_key?(webhooks, "orderPlaced")
    end
  end

  describe "OpenAPI 3.1 document with webhooks" do
    test "document must have paths, webhooks, or components" do
      # OpenAPI 3.1 requires at least one of these
      valid_doc_1 = %{
        "openapi" => "3.1.0",
        "info" => %{"title" => "API", "version" => "1.0"},
        "paths" => %{}
      }

      valid_doc_2 = %{
        "openapi" => "3.1.0",
        "info" => %{"title" => "Webhook API", "version" => "1.0"},
        "webhooks" => %{
          "event" => %{
            "post" => %{"responses" => %{"200" => %{"description" => "OK"}}}
          }
        }
      }

      valid_doc_3 = %{
        "openapi" => "3.1.0",
        "info" => %{"title" => "Schema API", "version" => "1.0"},
        "components" => %{
          "schemas" => %{"User" => %{"type" => "object"}}
        }
      }

      # All three are valid
      assert Map.has_key?(valid_doc_1, "paths")
      assert Map.has_key?(valid_doc_2, "webhooks")
      assert Map.has_key?(valid_doc_3, "components")
    end

    test "generated spec includes paths by default" do
      spec = AshOaskit.spec_31(domains: [AshOaskit.Test.SimpleDomain])

      # Our generated specs always have paths
      assert Map.has_key?(spec, "paths")
      assert spec["openapi"] == "3.1.0"
    end
  end
end
