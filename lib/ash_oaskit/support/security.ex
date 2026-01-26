defmodule AshOaskit.Security do
  @moduledoc """
  Generates OpenAPI security schemes and requirements for API specifications.

  This module provides functions to build security scheme definitions and
  security requirements that can be applied to operations. It supports
  common authentication patterns used in JSON:API applications.

  ## Supported Security Schemes

  ### Bearer Token Authentication
  HTTP Bearer authentication using JWT or opaque tokens:
  ```json
  {
    "bearerAuth": {
      "type": "http",
      "scheme": "bearer",
      "bearerFormat": "JWT"
    }
  }
  ```

  ### API Key Authentication
  API key passed in header, query, or cookie:
  ```json
  {
    "apiKeyAuth": {
      "type": "apiKey",
      "in": "header",
      "name": "X-API-Key"
    }
  }
  ```

  ### OAuth2 Authentication
  OAuth 2.0 with various flows (authorization code, client credentials, etc.)

  ### OpenID Connect
  OpenID Connect Discovery for authentication

  ## Usage

      # Build bearer auth security scheme
      AshOaskit.Security.bearer_auth_scheme()

      # Build security requirement
      AshOaskit.Security.security_requirement("bearerAuth")

      # Build complete security components
      AshOaskit.Security.build_security_schemes([:bearer, :api_key])

  ## Applying Security to Operations

  Security can be applied at the spec level (all operations) or per-operation:

  ```elixir
  # Spec-level security (in generate options)
  AshOaskit.spec_31(domains: [MyApp.Blog], security: [%{"bearerAuth" => []}])

  # The security schemes are added to components/securitySchemes
  ```
  """

  @doc """
  Builds a Bearer token authentication security scheme.

  ## Options

  - `:name` - Name for the security scheme. Defaults to "bearerAuth".
  - `:description` - Description of the scheme. Defaults to standard description.
  - `:bearer_format` - Format of the bearer token (e.g., "JWT"). Defaults to "JWT".

  ## Examples

      iex> AshOaskit.Security.bearer_auth_scheme()
      %{
        "bearerAuth" => %{
          "type" => "http",
          "scheme" => "bearer",
          "bearerFormat" => "JWT",
          "description" => "Bearer token authentication"
        }
      }

      iex> AshOaskit.Security.bearer_auth_scheme(name: "jwtAuth", bearer_format: "JWT")
      %{
        "jwtAuth" => %{
          "type" => "http",
          "scheme" => "bearer",
          "bearerFormat" => "JWT",
          "description" => "Bearer token authentication"
        }
      }
  """
  @spec bearer_auth_scheme(keyword()) :: map()
  def bearer_auth_scheme(opts \\ []) do
    name = Keyword.get(opts, :name, "bearerAuth")
    description = Keyword.get(opts, :description, "Bearer token authentication")
    bearer_format = Keyword.get(opts, :bearer_format, "JWT")

    %{
      name => %{
        "type" => "http",
        "scheme" => "bearer",
        "bearerFormat" => bearer_format,
        "description" => description
      }
    }
  end

  @doc """
  Builds an API Key authentication security scheme.

  ## Options

  - `:name` - Name for the security scheme. Defaults to "apiKeyAuth".
  - `:key_name` - Name of the API key parameter. Defaults to "X-API-Key".
  - `:location` - Where the key is passed: "header", "query", or "cookie". Defaults to "header".
  - `:description` - Description of the scheme.

  ## Examples

      iex> AshOaskit.Security.api_key_scheme()
      %{
        "apiKeyAuth" => %{
          "type" => "apiKey",
          "in" => "header",
          "name" => "X-API-Key",
          "description" => "API key authentication"
        }
      }

      iex> AshOaskit.Security.api_key_scheme(key_name: "api_key", location: "query")
      %{
        "apiKeyAuth" => %{
          "type" => "apiKey",
          "in" => "query",
          "name" => "api_key",
          "description" => "API key authentication"
        }
      }
  """
  @spec api_key_scheme(keyword()) :: map()
  def api_key_scheme(opts \\ []) do
    name = Keyword.get(opts, :name, "apiKeyAuth")
    key_name = Keyword.get(opts, :key_name, "X-API-Key")
    location = Keyword.get(opts, :location, "header")
    description = Keyword.get(opts, :description, "API key authentication")

    %{
      name => %{
        "type" => "apiKey",
        "in" => location,
        "name" => key_name,
        "description" => description
      }
    }
  end

  @doc """
  Builds a Basic authentication security scheme.

  ## Options

  - `:name` - Name for the security scheme. Defaults to "basicAuth".
  - `:description` - Description of the scheme.

  ## Examples

      iex> AshOaskit.Security.basic_auth_scheme()
      %{
        "basicAuth" => %{
          "type" => "http",
          "scheme" => "basic",
          "description" => "Basic HTTP authentication"
        }
      }
  """
  @spec basic_auth_scheme(keyword()) :: map()
  def basic_auth_scheme(opts \\ []) do
    name = Keyword.get(opts, :name, "basicAuth")
    description = Keyword.get(opts, :description, "Basic HTTP authentication")

    %{
      name => %{
        "type" => "http",
        "scheme" => "basic",
        "description" => description
      }
    }
  end

  @doc """
  Builds an OAuth2 authentication security scheme.

  ## Options

  - `:name` - Name for the security scheme. Defaults to "oauth2".
  - `:description` - Description of the scheme.
  - `:flows` - OAuth2 flows configuration. Required.

  ## Flow Types

  - `:authorization_code` - Authorization code flow with PKCE
  - `:client_credentials` - Client credentials flow for machine-to-machine
  - `:implicit` - Implicit flow (deprecated, not recommended)
  - `:password` - Resource owner password flow (not recommended)

  ## Examples

      iex> AshOaskit.Security.oauth2_scheme(
      ...>   flows: %{
      ...>     "authorizationCode" => %{
      ...>       "authorizationUrl" => "https://auth.example.com/authorize",
      ...>       "tokenUrl" => "https://auth.example.com/token",
      ...>       "scopes" => %{
      ...>         "read" => "Read access",
      ...>         "write" => "Write access"
      ...>       }
      ...>     }
      ...>   }
      ...> )
  """
  @spec oauth2_scheme(keyword()) :: map()
  def oauth2_scheme(opts \\ []) do
    name = Keyword.get(opts, :name, "oauth2")
    description = Keyword.get(opts, :description, "OAuth 2.0 authentication")
    flows = Keyword.get(opts, :flows, %{})

    %{
      name => %{
        "type" => "oauth2",
        "description" => description,
        "flows" => flows
      }
    }
  end

  @doc """
  Builds an OpenID Connect authentication security scheme.

  ## Options

  - `:name` - Name for the security scheme. Defaults to "openIdConnect".
  - `:description` - Description of the scheme.
  - `:openid_connect_url` - URL to the OpenID Connect discovery document. Required.

  ## Examples

      iex> AshOaskit.Security.openid_connect_scheme(
      ...>   openid_connect_url: "https://auth.example.com/.well-known/openid-configuration"
      ...> )
      %{
        "openIdConnect" => %{
          "type" => "openIdConnect",
          "openIdConnectUrl" => "https://auth.example.com/.well-known/openid-configuration",
          "description" => "OpenID Connect authentication"
        }
      }
  """
  @spec openid_connect_scheme(keyword()) :: map()
  def openid_connect_scheme(opts \\ []) do
    name = Keyword.get(opts, :name, "openIdConnect")
    description = Keyword.get(opts, :description, "OpenID Connect authentication")
    url = Keyword.get(opts, :openid_connect_url, "")

    %{
      name => %{
        "type" => "openIdConnect",
        "openIdConnectUrl" => url,
        "description" => description
      }
    }
  end

  @doc """
  Builds a security requirement for an operation.

  Security requirements specify which security schemes apply and what
  scopes are required (for OAuth2).

  ## Options

  - `:scopes` - List of required scopes (for OAuth2). Defaults to [].

  ## Examples

      iex> AshOaskit.Security.security_requirement("bearerAuth")
      %{"bearerAuth" => []}

      iex> AshOaskit.Security.security_requirement("oauth2", scopes: ["read", "write"])
      %{"oauth2" => ["read", "write"]}
  """
  @spec security_requirement(String.t(), keyword()) :: map()
  def security_requirement(scheme_name, opts \\ []) do
    scopes = Keyword.get(opts, :scopes, [])
    %{scheme_name => scopes}
  end

  @doc """
  Builds multiple security requirements (OR relationship).

  When multiple requirements are in a list, the client can use ANY of them.

  ## Examples

      iex> AshOaskit.Security.security_requirements(["bearerAuth", "apiKeyAuth"])
      [%{"bearerAuth" => []}, %{"apiKeyAuth" => []}]
  """
  @spec security_requirements(list(String.t() | {String.t(), list(String.t())})) :: list(map())
  def security_requirements(schemes) do
    Enum.map(schemes, fn
      {name, scopes} when is_list(scopes) -> %{name => scopes}
      name when is_binary(name) -> %{name => []}
    end)
  end

  @doc """
  Builds combined security requirements (AND relationship).

  When multiple schemes are in a single requirement object, ALL must be satisfied.

  ## Examples

      iex> AshOaskit.Security.combined_security_requirement(["bearerAuth", "apiKeyAuth"])
      %{"bearerAuth" => [], "apiKeyAuth" => []}
  """
  @spec combined_security_requirement(list(String.t() | {String.t(), list(String.t())})) :: map()
  def combined_security_requirement(schemes) do
    Enum.reduce(schemes, %{}, fn
      {name, scopes}, acc when is_list(scopes) -> Map.put(acc, name, scopes)
      name, acc when is_binary(name) -> Map.put(acc, name, [])
    end)
  end

  @doc """
  Builds security schemes based on a list of scheme types.

  ## Supported Types

  - `:bearer` - Bearer token authentication
  - `:api_key` - API key authentication
  - `:basic` - Basic HTTP authentication
  - `:oauth2` - OAuth 2.0 (requires additional configuration)
  - `:openid_connect` - OpenID Connect (requires URL)

  ## Options

  Each scheme type can have its own options passed as a tuple.

  ## Examples

      iex> AshOaskit.Security.build_security_schemes([:bearer, :api_key])
      %{
        "bearerAuth" => %{...},
        "apiKeyAuth" => %{...}
      }

      iex> AshOaskit.Security.build_security_schemes([
      ...>   {:bearer, name: "jwtAuth"},
      ...>   {:api_key, key_name: "Authorization"}
      ...> ])
  """
  @spec build_security_schemes(list(atom() | {atom(), keyword()})) :: map()
  def build_security_schemes(scheme_types) do
    Enum.reduce(scheme_types, %{}, fn
      {:bearer, opts}, acc -> Map.merge(acc, bearer_auth_scheme(opts))
      {:api_key, opts}, acc -> Map.merge(acc, api_key_scheme(opts))
      {:basic, opts}, acc -> Map.merge(acc, basic_auth_scheme(opts))
      {:oauth2, opts}, acc -> Map.merge(acc, oauth2_scheme(opts))
      {:openid_connect, opts}, acc -> Map.merge(acc, openid_connect_scheme(opts))
      :bearer, acc -> Map.merge(acc, bearer_auth_scheme())
      :api_key, acc -> Map.merge(acc, api_key_scheme())
      :basic, acc -> Map.merge(acc, basic_auth_scheme())
      :oauth2, acc -> Map.merge(acc, oauth2_scheme())
      :openid_connect, acc -> Map.merge(acc, openid_connect_scheme())
      _, acc -> acc
    end)
  end

  @doc """
  Builds the default security requirement for bearer authentication.

  This is a convenience function that returns the standard security
  requirement for bearer token authentication.

  ## Examples

      iex> AshOaskit.Security.default_security_requirement()
      [%{"bearerAuth" => []}]
  """
  @spec default_security_requirement() :: list(map())
  def default_security_requirement do
    [security_requirement("bearerAuth")]
  end

  @doc """
  Builds the securitySchemes component for the OpenAPI spec.

  ## Options

  - `:schemes` - List of scheme types to include. Defaults to [:bearer].
  - `:custom_schemes` - Map of custom security schemes to merge.

  ## Examples

      iex> AshOaskit.Security.build_security_schemes_component(schemes: [:bearer, :api_key])
      %{
        "securitySchemes" => %{
          "bearerAuth" => %{...},
          "apiKeyAuth" => %{...}
        }
      }
  """
  @spec build_security_schemes_component(keyword()) :: map()
  def build_security_schemes_component(opts \\ []) do
    schemes = Keyword.get(opts, :schemes, [:bearer])
    custom_schemes = Keyword.get(opts, :custom_schemes, %{})

    built_schemes = build_security_schemes(schemes)
    merged_schemes = Map.merge(built_schemes, custom_schemes)

    %{"securitySchemes" => merged_schemes}
  end

  @doc """
  Checks if a route requires authentication based on its configuration.

  This function checks the route's action for authentication requirements.

  ## Examples

      iex> AshOaskit.Security.requires_authentication?(%{action: :read})
      true

      iex> AshOaskit.Security.requires_authentication?(%{public?: true})
      false
  """
  @spec requires_authentication?(map()) :: boolean()
  def requires_authentication?(route) do
    not Map.get(route, :public?, false)
  end

  @doc """
  Builds security for an operation based on route configuration.

  Returns nil for public routes, or the default security requirement
  for authenticated routes.

  ## Options

  - `:default_security` - Default security requirement to use. Defaults to bearer auth.

  ## Examples

      iex> AshOaskit.Security.build_operation_security(%{public?: true})
      nil

      iex> AshOaskit.Security.build_operation_security(%{public?: false})
      [%{"bearerAuth" => []}]
  """
  @spec build_operation_security(map(), keyword()) :: list(map()) | nil
  def build_operation_security(route, opts \\ []) do
    default_security = Keyword.get(opts, :default_security, default_security_requirement())

    if requires_authentication?(route) do
      default_security
    else
      nil
    end
  end

  @doc """
  Adds security to an existing operation schema.

  ## Options

  - `:security` - Security requirement to add. Uses default if not provided.
  - `:route` - Route configuration to check for public access.

  ## Examples

      iex> operation = %{"operationId" => "getPost", "responses" => %{}}
      ...> AshOaskit.Security.add_security_to_operation(operation)
      %{
        "operationId" => "getPost",
        "responses" => %{},
        "security" => [%{"bearerAuth" => []}]
      }
  """
  @spec add_security_to_operation(map(), keyword()) :: map()
  def add_security_to_operation(operation, opts \\ []) do
    security = Keyword.get(opts, :security)
    route = Keyword.get(opts, :route)

    security =
      cond do
        security != nil -> security
        route != nil -> build_operation_security(route)
        true -> default_security_requirement()
      end

    if security do
      Map.put(operation, "security", security)
    else
      operation
    end
  end

  @doc """
  Builds an optional security requirement (allows unauthenticated access).

  In OpenAPI, an empty object in the security array means the operation
  can be accessed without authentication.

  ## Examples

      iex> AshOaskit.Security.optional_security("bearerAuth")
      [%{"bearerAuth" => []}, %{}]
  """
  @spec optional_security(String.t(), keyword()) :: list(map())
  def optional_security(scheme_name, opts \\ []) do
    [security_requirement(scheme_name, opts), %{}]
  end

  @doc """
  Builds a complete security configuration for the spec.

  Returns both the security schemes (for components) and the default
  security requirement (for spec-level security).

  ## Options

  - `:schemes` - List of scheme types. Defaults to [:bearer].
  - `:default_scheme` - Name of the default security scheme. Defaults to "bearerAuth".

  ## Examples

      iex> AshOaskit.Security.build_complete_security_config(schemes: [:bearer, :api_key])
      %{
        schemes: %{"bearerAuth" => %{...}, "apiKeyAuth" => %{...}},
        default_security: [%{"bearerAuth" => []}]
      }
  """
  @spec build_complete_security_config(keyword()) :: map()
  def build_complete_security_config(opts \\ []) do
    schemes = Keyword.get(opts, :schemes, [:bearer])
    default_scheme = Keyword.get(opts, :default_scheme, "bearerAuth")

    %{
      schemes: build_security_schemes(schemes),
      default_security: [security_requirement(default_scheme)]
    }
  end
end
