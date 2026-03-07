defmodule AshOaskit.Generators.InfoBuilder do
  @moduledoc """
  OpenAPI Info object and server configuration builder.

  This module handles the generation of the `info` and `servers` sections
  of OpenAPI specifications, as well as resource tags for organization.

  ## Info Object

  The Info object contains metadata about the API:

  - **title** - Required. The name of the API
  - **version** - Required. The version of the API document
  - **description** - Optional. Description of the API
  - **termsOfService** - Optional. URL to terms of service
  - **contact** - Optional. Contact information object
  - **license** - Optional. License information object

  ## Servers

  The servers array specifies base URLs for the API:

      # Simple URL string
      servers: ["https://api.example.com"]

      # Full server object
      servers: [%{
        "url" => "https://api.example.com",
        "description" => "Production server"
      }]

  ## Tags

  Tags are generated from domain resources and used to group
  operations in documentation tools like Swagger UI.

  ## Usage

      info = InfoBuilder.build_info(title: "My API", api_version: "2.0")
      servers = InfoBuilder.build_servers(servers: ["https://api.example.com"])
      tags = InfoBuilder.build_tags([MyApp.Domain])
  """

  @type opts :: keyword()

  @doc """
  Builds the Info object for the OpenAPI spec.

  ## Options

  - `:title` - API title (defaults to application config or "API")
  - `:api_version` - API version string (defaults to "1.0.0")
  - `:description` - Optional description
  - `:terms_of_service` - Optional terms of service URL
  - `:contact` - Optional contact information map
  - `:license` - Optional license information map

  ## Returns

  A map conforming to the OpenAPI Info Object specification.

  ## Examples

      iex> InfoBuilder.build_info(title: "Pet Store", api_version: "1.0.0")
      %{"title" => "Pet Store", "version" => "1.0.0"}

      iex> InfoBuilder.build_info(title: "API", description: "My API")
      %{"title" => "API", "version" => "1.0.0", "description" => "My API"}
  """
  @spec build_info(opts()) :: map()
  def build_info(opts) do
    reject_nil_values(%{
      title: Keyword.get(opts, :title, default_title()),
      version: Keyword.get(opts, :api_version, default_api_version()),
      description: Keyword.get(opts, :description),
      termsOfService: Keyword.get(opts, :terms_of_service),
      contact: Keyword.get(opts, :contact),
      license: Keyword.get(opts, :license)
    })
  end

  @doc """
  Builds servers array from options.

  Accepts either simple URL strings or full server objects with
  url, description, and variables.

  ## Options

  - `:servers` - List of server URLs or server objects

  ## Returns

  A list of server objects. Defaults to `[%{"url" => "/"}]` if not specified.

  ## Examples

      iex> InfoBuilder.build_servers([])
      [%{"url" => "/"}]

      iex> InfoBuilder.build_servers(servers: ["https://api.example.com"])
      [%{"url" => "https://api.example.com"}]
  """
  @spec build_servers(opts()) :: list(map())
  def build_servers(opts) do
    case Keyword.get(opts, :servers) do
      nil -> [%{url: "/"}]
      servers when is_list(servers) -> Enum.map(servers, &normalize_server/1)
    end
  end

  @doc """
  Builds tags from domain resources.

  Each resource in the domains generates a tag, which is used to
  group related operations in documentation.

  ## Parameters

  - `domains` - List of Ash domain modules

  ## Returns

  A list of tag objects with name field.

  ## Examples

      iex> InfoBuilder.build_tags([MyApp.Blog])
      [%{"name" => "Post"}, %{"name" => "Comment"}]
  """
  @spec build_tags(list(module())) :: list(map())
  def build_tags(domains) do
    domains
    |> Enum.flat_map(&get_domain_resources/1)
    |> Enum.map(fn resource ->
      name =
        resource
        |> Module.split()
        |> List.last()

      %{name: name}
    end)
    |> Enum.uniq_by(& &1[:name])
  end

  # Removes nil values from a map
  defp reject_nil_values(map) do
    map
    |> Enum.reject(fn {_, v} -> is_nil(v) end)
    |> Map.new()
  end

  # Normalizes a server specification to a server object
  defp normalize_server(url) when is_binary(url), do: %{url: url}
  defp normalize_server(server) when is_map(server), do: server

  # Gets resources from a domain
  defp get_domain_resources(domain) do
    Ash.Domain.Info.resources(domain)
  end

  defp default_title do
    Application.get_env(:ash_oaskit, :title, "API")
  end

  defp default_api_version do
    Application.get_env(:ash_oaskit, :api_version, "1.0.0")
  end
end
