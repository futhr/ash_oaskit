defmodule AshOaskit.SecurityTest do
  @moduledoc """
  Tests for AshOaskit.Security module.

  This test module verifies the generation of OpenAPI security schemes
  and requirements, including:

  - Bearer token authentication
  - API key authentication
  - Basic HTTP authentication
  - OAuth2 authentication
  - OpenID Connect authentication
  - Security requirements (OR and AND relationships)
  - Operation-level security
  - Public vs authenticated routes
  """

  use ExUnit.Case, async: true

  alias AshOaskit.Security

  describe "bearer_auth_scheme/1" do
    test "generates bearer auth scheme with defaults" do
      scheme = Security.bearer_auth_scheme()

      assert Map.has_key?(scheme, "bearerAuth")
      assert scheme["bearerAuth"]["type"] == "http"
      assert scheme["bearerAuth"]["scheme"] == "bearer"
      assert scheme["bearerAuth"]["bearerFormat"] == "JWT"
    end

    test "respects custom name" do
      scheme = Security.bearer_auth_scheme(name: "jwtAuth")

      assert Map.has_key?(scheme, "jwtAuth")
      refute Map.has_key?(scheme, "bearerAuth")
    end

    test "respects custom bearer format" do
      scheme = Security.bearer_auth_scheme(bearer_format: "opaque")

      assert scheme["bearerAuth"]["bearerFormat"] == "opaque"
    end

    test "respects custom description" do
      scheme = Security.bearer_auth_scheme(description: "Custom JWT auth")

      assert scheme["bearerAuth"]["description"] == "Custom JWT auth"
    end

    test "has default description" do
      scheme = Security.bearer_auth_scheme()

      assert scheme["bearerAuth"]["description"] == "Bearer token authentication"
    end
  end

  describe "api_key_scheme/1" do
    test "generates API key scheme with defaults" do
      scheme = Security.api_key_scheme()

      assert Map.has_key?(scheme, "apiKeyAuth")
      assert scheme["apiKeyAuth"]["type"] == "apiKey"
      assert scheme["apiKeyAuth"]["in"] == "header"
      assert scheme["apiKeyAuth"]["name"] == "X-API-Key"
    end

    test "respects custom name" do
      scheme = Security.api_key_scheme(name: "customApiKey")

      assert Map.has_key?(scheme, "customApiKey")
    end

    test "respects custom key name" do
      scheme = Security.api_key_scheme(key_name: "Authorization")

      assert scheme["apiKeyAuth"]["name"] == "Authorization"
    end

    test "respects query location" do
      scheme = Security.api_key_scheme(location: "query")

      assert scheme["apiKeyAuth"]["in"] == "query"
    end

    test "respects cookie location" do
      scheme = Security.api_key_scheme(location: "cookie")

      assert scheme["apiKeyAuth"]["in"] == "cookie"
    end

    test "respects custom description" do
      scheme = Security.api_key_scheme(description: "API key in header")

      assert scheme["apiKeyAuth"]["description"] == "API key in header"
    end
  end

  describe "basic_auth_scheme/1" do
    test "generates basic auth scheme with defaults" do
      scheme = Security.basic_auth_scheme()

      assert Map.has_key?(scheme, "basicAuth")
      assert scheme["basicAuth"]["type"] == "http"
      assert scheme["basicAuth"]["scheme"] == "basic"
    end

    test "respects custom name" do
      scheme = Security.basic_auth_scheme(name: "httpBasic")

      assert Map.has_key?(scheme, "httpBasic")
    end

    test "respects custom description" do
      scheme = Security.basic_auth_scheme(description: "Basic auth for testing")

      assert scheme["basicAuth"]["description"] == "Basic auth for testing"
    end

    test "has default description" do
      scheme = Security.basic_auth_scheme()

      assert scheme["basicAuth"]["description"] == "Basic HTTP authentication"
    end
  end

  describe "oauth2_scheme/1" do
    test "generates OAuth2 scheme with defaults" do
      scheme = Security.oauth2_scheme()

      assert Map.has_key?(scheme, "oauth2")
      assert scheme["oauth2"]["type"] == "oauth2"
      assert scheme["oauth2"]["flows"] == %{}
    end

    test "respects custom flows" do
      flows = %{
        "authorizationCode" => %{
          "authorizationUrl" => "https://auth.example.com/authorize",
          "tokenUrl" => "https://auth.example.com/token",
          "scopes" => %{"read" => "Read access"}
        }
      }

      scheme = Security.oauth2_scheme(flows: flows)

      assert scheme["oauth2"]["flows"] == flows
    end

    test "respects custom name" do
      scheme = Security.oauth2_scheme(name: "myOAuth")

      assert Map.has_key?(scheme, "myOAuth")
    end

    test "respects custom description" do
      scheme = Security.oauth2_scheme(description: "OAuth 2.0 with PKCE")

      assert scheme["oauth2"]["description"] == "OAuth 2.0 with PKCE"
    end
  end

  describe "openid_connect_scheme/1" do
    test "generates OpenID Connect scheme" do
      scheme =
        Security.openid_connect_scheme(
          openid_connect_url: "https://auth.example.com/.well-known/openid-configuration"
        )

      assert Map.has_key?(scheme, "openIdConnect")
      assert scheme["openIdConnect"]["type"] == "openIdConnect"

      assert scheme["openIdConnect"]["openIdConnectUrl"] ==
               "https://auth.example.com/.well-known/openid-configuration"
    end

    test "respects custom name" do
      scheme = Security.openid_connect_scheme(name: "oidc")

      assert Map.has_key?(scheme, "oidc")
    end

    test "respects custom description" do
      scheme = Security.openid_connect_scheme(description: "OIDC auth")

      assert scheme["openIdConnect"]["description"] == "OIDC auth"
    end

    test "defaults to empty URL" do
      scheme = Security.openid_connect_scheme()

      assert scheme["openIdConnect"]["openIdConnectUrl"] == ""
    end
  end

  describe "security_requirement/2" do
    test "generates security requirement with empty scopes by default" do
      req = Security.security_requirement("bearerAuth")

      assert req == %{"bearerAuth" => []}
    end

    test "includes scopes when provided" do
      req = Security.security_requirement("oauth2", scopes: ["read", "write"])

      assert req == %{"oauth2" => ["read", "write"]}
    end

    test "handles empty scopes list" do
      req = Security.security_requirement("apiKeyAuth", scopes: [])

      assert req == %{"apiKeyAuth" => []}
    end
  end

  describe "security_requirements/1" do
    test "generates multiple requirements from strings" do
      reqs = Security.security_requirements(["bearerAuth", "apiKeyAuth"])

      assert reqs == [%{"bearerAuth" => []}, %{"apiKeyAuth" => []}]
    end

    test "handles tuples with scopes" do
      reqs =
        Security.security_requirements([
          "bearerAuth",
          {"oauth2", ["read", "write"]}
        ])

      assert reqs == [%{"bearerAuth" => []}, %{"oauth2" => ["read", "write"]}]
    end

    test "returns empty list for empty input" do
      reqs = Security.security_requirements([])

      assert reqs == []
    end
  end

  describe "combined_security_requirement/1" do
    test "combines multiple schemes into single requirement" do
      req = Security.combined_security_requirement(["bearerAuth", "apiKeyAuth"])

      assert req == %{"bearerAuth" => [], "apiKeyAuth" => []}
    end

    test "handles tuples with scopes" do
      req =
        Security.combined_security_requirement([
          "bearerAuth",
          {"oauth2", ["read"]}
        ])

      assert req == %{"bearerAuth" => [], "oauth2" => ["read"]}
    end

    test "returns empty map for empty input" do
      req = Security.combined_security_requirement([])

      assert req == %{}
    end
  end

  describe "build_security_schemes/1" do
    test "builds bearer scheme from atom" do
      schemes = Security.build_security_schemes([:bearer])

      assert Map.has_key?(schemes, "bearerAuth")
      assert schemes["bearerAuth"]["type"] == "http"
    end

    test "builds api_key scheme from atom" do
      schemes = Security.build_security_schemes([:api_key])

      assert Map.has_key?(schemes, "apiKeyAuth")
      assert schemes["apiKeyAuth"]["type"] == "apiKey"
    end

    test "builds basic scheme from atom" do
      schemes = Security.build_security_schemes([:basic])

      assert Map.has_key?(schemes, "basicAuth")
      assert schemes["basicAuth"]["scheme"] == "basic"
    end

    test "builds multiple schemes" do
      schemes = Security.build_security_schemes([:bearer, :api_key, :basic])

      assert Map.has_key?(schemes, "bearerAuth")
      assert Map.has_key?(schemes, "apiKeyAuth")
      assert Map.has_key?(schemes, "basicAuth")
    end

    test "handles tuple with options" do
      schemes =
        Security.build_security_schemes([
          {:bearer, name: "jwtAuth"},
          {:api_key, key_name: "X-Custom-Key"}
        ])

      assert Map.has_key?(schemes, "jwtAuth")
      assert schemes["apiKeyAuth"]["name"] == "X-Custom-Key"
    end

    test "ignores unknown scheme types" do
      schemes = Security.build_security_schemes([:bearer, :unknown, :invalid])

      assert Map.has_key?(schemes, "bearerAuth")
      assert map_size(schemes) == 1
    end

    test "builds oauth2 scheme" do
      schemes = Security.build_security_schemes([:oauth2])

      assert Map.has_key?(schemes, "oauth2")
      assert schemes["oauth2"]["type"] == "oauth2"
    end

    test "builds openid_connect scheme" do
      schemes = Security.build_security_schemes([:openid_connect])

      assert Map.has_key?(schemes, "openIdConnect")
      assert schemes["openIdConnect"]["type"] == "openIdConnect"
    end
  end

  describe "default_security_requirement/0" do
    test "returns bearer auth requirement" do
      req = Security.default_security_requirement()

      assert req == [%{"bearerAuth" => []}]
    end

    test "returns a list with one item" do
      req = Security.default_security_requirement()

      assert length(req) == 1
    end
  end

  describe "build_security_schemes_component/1" do
    test "wraps schemes in securitySchemes key" do
      component = Security.build_security_schemes_component()

      assert Map.has_key?(component, "securitySchemes")
      assert Map.has_key?(component["securitySchemes"], "bearerAuth")
    end

    test "respects schemes option" do
      component = Security.build_security_schemes_component(schemes: [:bearer, :api_key])

      assert Map.has_key?(component["securitySchemes"], "bearerAuth")
      assert Map.has_key?(component["securitySchemes"], "apiKeyAuth")
    end

    test "merges custom schemes" do
      custom = %{
        "customAuth" => %{"type" => "http", "scheme" => "custom"}
      }

      component = Security.build_security_schemes_component(custom_schemes: custom)

      assert Map.has_key?(component["securitySchemes"], "bearerAuth")
      assert Map.has_key?(component["securitySchemes"], "customAuth")
    end

    test "custom schemes override built schemes" do
      custom = %{
        "bearerAuth" => %{"type" => "http", "scheme" => "bearer", "description" => "Custom"}
      }

      component = Security.build_security_schemes_component(custom_schemes: custom)

      assert component["securitySchemes"]["bearerAuth"]["description"] == "Custom"
    end
  end

  describe "requires_authentication?/1" do
    test "returns true for non-public routes" do
      assert Security.requires_authentication?(%{action: :read}) == true
    end

    test "returns false for public routes" do
      assert Security.requires_authentication?(%{public?: true}) == false
    end

    test "returns true when public? is false" do
      assert Security.requires_authentication?(%{public?: false}) == true
    end

    test "returns true when public? is missing" do
      assert Security.requires_authentication?(%{}) == true
    end
  end

  describe "build_operation_security/2" do
    test "returns nil for public routes" do
      security = Security.build_operation_security(%{public?: true})

      assert security == nil
    end

    test "returns default security for non-public routes" do
      security = Security.build_operation_security(%{public?: false})

      assert security == [%{"bearerAuth" => []}]
    end

    test "respects custom default_security" do
      custom_security = [%{"apiKeyAuth" => []}]
      security = Security.build_operation_security(%{}, default_security: custom_security)

      assert security == custom_security
    end

    test "returns default security when no route info" do
      security = Security.build_operation_security(%{})

      assert security == [%{"bearerAuth" => []}]
    end
  end

  describe "add_security_to_operation/2" do
    test "adds default security to operation" do
      operation = %{"operationId" => "getPost", "responses" => %{}}

      result = Security.add_security_to_operation(operation)

      assert result["security"] == [%{"bearerAuth" => []}]
      assert result["operationId"] == "getPost"
    end

    test "respects custom security option" do
      operation = %{"operationId" => "getPost"}
      custom_security = [%{"apiKeyAuth" => []}]

      result = Security.add_security_to_operation(operation, security: custom_security)

      assert result["security"] == custom_security
    end

    test "does not add security for public routes" do
      operation = %{"operationId" => "getPublicPost"}

      result = Security.add_security_to_operation(operation, route: %{public?: true})

      refute Map.has_key?(result, "security")
    end

    test "preserves existing operation properties" do
      operation = %{
        "operationId" => "getPost",
        "summary" => "Get a post",
        "tags" => ["Posts"]
      }

      result = Security.add_security_to_operation(operation)

      assert result["operationId"] == "getPost"
      assert result["summary"] == "Get a post"
      assert result["tags"] == ["Posts"]
    end
  end

  describe "optional_security/2" do
    test "includes both authenticated and unauthenticated options" do
      security = Security.optional_security("bearerAuth")

      assert length(security) == 2
      assert %{"bearerAuth" => []} in security
      assert %{} in security
    end

    test "respects scopes" do
      security = Security.optional_security("oauth2", scopes: ["read"])

      assert %{"oauth2" => ["read"]} in security
      assert %{} in security
    end
  end

  describe "build_complete_security_config/1" do
    test "returns schemes and default_security" do
      config = Security.build_complete_security_config()

      assert Map.has_key?(config, :schemes)
      assert Map.has_key?(config, :default_security)
    end

    test "schemes includes bearer by default" do
      config = Security.build_complete_security_config()

      assert Map.has_key?(config.schemes, "bearerAuth")
    end

    test "default_security uses bearerAuth by default" do
      config = Security.build_complete_security_config()

      assert config.default_security == [%{"bearerAuth" => []}]
    end

    test "respects custom schemes" do
      config = Security.build_complete_security_config(schemes: [:bearer, :api_key])

      assert Map.has_key?(config.schemes, "bearerAuth")
      assert Map.has_key?(config.schemes, "apiKeyAuth")
    end

    test "respects custom default_scheme" do
      config =
        Security.build_complete_security_config(
          schemes: [:api_key],
          default_scheme: "apiKeyAuth"
        )

      assert config.default_security == [%{"apiKeyAuth" => []}]
    end
  end

  describe "schema structure validation" do
    test "all schemes can be serialized to JSON" do
      schemes = [
        Security.bearer_auth_scheme(),
        Security.api_key_scheme(),
        Security.basic_auth_scheme(),
        Security.oauth2_scheme(),
        Security.openid_connect_scheme()
      ]

      for scheme <- schemes do
        assert {:ok, _json} = Jason.encode(scheme)
      end
    end

    test "security requirements can be serialized to JSON" do
      requirements = [
        Security.security_requirement("bearerAuth"),
        Security.security_requirements(["bearer", "api_key"]),
        Security.combined_security_requirement(["bearer", "api_key"]),
        Security.default_security_requirement()
      ]

      for req <- requirements do
        assert {:ok, _json} = Jason.encode(req)
      end
    end

    test "complete config can be serialized to JSON" do
      config = Security.build_complete_security_config(schemes: [:bearer, :api_key])

      assert {:ok, _json} = Jason.encode(config)
    end
  end

  describe "integration scenarios" do
    test "building a full security setup for an API" do
      # Build schemes for components
      schemes = Security.build_security_schemes([:bearer, :api_key])

      # Build default security
      default_security = Security.default_security_requirement()

      # Build operation with security
      operation = %{"operationId" => "createPost", "responses" => %{}}
      secured_operation = Security.add_security_to_operation(operation)

      assert Map.has_key?(schemes, "bearerAuth")
      assert Map.has_key?(schemes, "apiKeyAuth")
      assert default_security == [%{"bearerAuth" => []}]
      assert secured_operation["security"] == [%{"bearerAuth" => []}]
    end

    test "building OAuth2 with authorization code flow" do
      flows = %{
        "authorizationCode" => %{
          "authorizationUrl" => "https://auth.example.com/authorize",
          "tokenUrl" => "https://auth.example.com/token",
          "refreshUrl" => "https://auth.example.com/refresh",
          "scopes" => %{
            "read:posts" => "Read posts",
            "write:posts" => "Create and update posts",
            "delete:posts" => "Delete posts"
          }
        }
      }

      scheme = Security.oauth2_scheme(flows: flows)
      requirement = Security.security_requirement("oauth2", scopes: ["read:posts", "write:posts"])

      assert scheme["oauth2"]["flows"]["authorizationCode"]["authorizationUrl"] ==
               "https://auth.example.com/authorize"

      assert requirement == %{"oauth2" => ["read:posts", "write:posts"]}
    end

    test "building combined authentication (AND relationship)" do
      # Some APIs require both bearer token AND API key
      combined = Security.combined_security_requirement(["bearerAuth", "apiKeyAuth"])

      # This means BOTH are required
      assert combined == %{"bearerAuth" => [], "apiKeyAuth" => []}
    end
  end

  describe "build_security_schemes tuple patterns" do
    # Tests for tuple patterns with options to cover lines 369-371

    test "api_key with options tuple" do
      schemes = Security.build_security_schemes([{:api_key, key_name: "X-Custom-Key"}])

      assert Map.has_key?(schemes, "apiKeyAuth")
      assert schemes["apiKeyAuth"]["name"] == "X-Custom-Key"
    end

    test "basic with options tuple" do
      schemes = Security.build_security_schemes([{:basic, description: "Custom basic auth"}])

      assert Map.has_key?(schemes, "basicAuth")
      assert schemes["basicAuth"]["description"] == "Custom basic auth"
    end

    test "oauth2 with options tuple" do
      flows = %{
        "clientCredentials" => %{
          "tokenUrl" => "https://auth.example.com/token",
          "scopes" => %{"api" => "API access"}
        }
      }

      schemes = Security.build_security_schemes([{:oauth2, flows: flows}])

      assert Map.has_key?(schemes, "oauth2")

      assert schemes["oauth2"]["flows"]["clientCredentials"]["tokenUrl"] ==
               "https://auth.example.com/token"
    end

    test "openid_connect with options tuple" do
      schemes =
        Security.build_security_schemes([
          {:openid_connect, openid_connect_url: "https://auth.example.com/.well-known/openid"}
        ])

      assert Map.has_key?(schemes, "openIdConnect")
    end

    test "unknown scheme type is ignored" do
      schemes = Security.build_security_schemes([:bearer, :unknown_scheme])

      # Should only have bearer, unknown is ignored
      assert Map.has_key?(schemes, "bearerAuth")
      refute Map.has_key?(schemes, "unknownAuth")
    end
  end
end
