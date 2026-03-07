defmodule AshOaskit.TagBuilder do
  @moduledoc """
  Builds OpenAPI tags for organizing operations in the specification.

  This module provides functions to generate tags and assign operations to tags
  based on different grouping strategies. Tags help organize operations in
  documentation tools like Swagger UI and Redoc.

  ## Grouping Strategies

  ### By Resource (Default)
  Groups operations by the Ash resource they operate on:
  ```
  Posts:
    - GET /posts
    - POST /posts
    - GET /posts/{id}
  Comments:
    - GET /comments
    - POST /comments
  ```

  ### By Domain
  Groups operations by the Ash domain they belong to:
  ```
  Blog:
    - GET /posts
    - POST /posts
    - GET /comments
  Shop:
    - GET /products
    - POST /orders
  ```

  ### By Custom Tag
  Uses custom tags defined in the resource or domain configuration.

  ## Configuration

  Tag configuration can come from:
  - `AshJsonApi.Domain.Info.tag/1` - Domain-level tag override
  - `AshJsonApi.Domain.Info.group_by/1` - Grouping strategy
  - Resource name (default fallback)

  ## Usage

      # Build tags grouped by resource
      AshOaskit.TagBuilder.build_tags(domains, group_by: :resource)

      # Build tags grouped by domain
      AshOaskit.TagBuilder.build_tags(domains, group_by: :domain)

      # Get tag for an operation
      AshOaskit.TagBuilder.operation_tag(route, group_by: :resource)
  """

  alias AshOaskit.Config

  @doc """
  Builds tags for the OpenAPI specification.

  ## Options

  - `:group_by` - Grouping strategy: `:resource`, `:domain`, or `:custom`.
    Defaults to checking domain configuration, then `:resource`.
  - `:include_descriptions` - Whether to include tag descriptions. Defaults to true.

  ## Examples

      iex> AshOaskit.TagBuilder.build_tags([MyApp.Blog], group_by: :resource)
      [
        %{name: "Post", description: "Operations on Post resources"},
        %{name: "Comment", description: "Operations on Comment resources"}
      ]

      iex> AshOaskit.TagBuilder.build_tags([MyApp.Blog, MyApp.Shop], group_by: :domain)
      [
        %{name: "Blog", description: "Blog domain operations"},
        %{name: "Shop", description: "Shop domain operations"}
      ]
  """
  @spec build_tags(list(module()), keyword()) :: list(map())
  def build_tags(domains, opts \\ []) do
    group_by = Keyword.get(opts, :group_by) || get_default_grouping(domains)
    include_descriptions = Keyword.get(opts, :include_descriptions, true)

    case group_by do
      :domain -> build_domain_tags(domains, include_descriptions)
      :custom -> build_custom_tags(domains, include_descriptions)
      _ -> build_resource_tags(domains, include_descriptions)
    end
  end

  @doc """
  Builds tags based on resources (default grouping).

  Each resource becomes a tag.

  ## Examples

      iex> AshOaskit.TagBuilder.build_resource_tags([MyApp.Blog])
      [%{name: "Post"}, %{name: "Comment"}]
  """
  @spec build_resource_tags(list(module()), boolean()) :: list(map())
  def build_resource_tags(domains, include_descriptions \\ true) do
    domains
    |> Enum.flat_map(&get_domain_resources/1)
    |> Enum.map(fn resource ->
      name = resource_tag_name(resource)
      build_tag(name, resource_description(resource, include_descriptions))
    end)
    |> Enum.uniq_by(& &1[:name])
    |> Enum.sort_by(& &1[:name])
  end

  @doc """
  Builds tags based on domains.

  Each domain becomes a tag, and all resources in that domain share the tag.

  ## Examples

      iex> AshOaskit.TagBuilder.build_domain_tags([MyApp.Blog, MyApp.Shop])
      [
        %{name: "Blog", description: "Blog domain operations"},
        %{name: "Shop", description: "Shop domain operations"}
      ]
  """
  @spec build_domain_tags(list(module()), boolean()) :: list(map())
  def build_domain_tags(domains, include_descriptions \\ true) do
    domains
    |> Enum.map(fn domain ->
      name = domain_tag_name(domain)
      description = domain_description(domain, include_descriptions)
      build_tag(name, description)
    end)
    |> Enum.uniq_by(& &1[:name])
    |> Enum.sort_by(& &1[:name])
  end

  @doc """
  Builds tags based on custom configuration.

  Uses `tag` configuration from AshJsonApi domain info if available,
  falls back to domain name.

  ## Examples

      iex> AshOaskit.TagBuilder.build_custom_tags([MyApp.Blog])
      [%{name: "Custom Tag Name"}]
  """
  @spec build_custom_tags(list(module()), boolean()) :: list(map())
  def build_custom_tags(domains, include_descriptions \\ true) do
    domains
    |> Enum.map(fn domain ->
      name = Config.domain_tag(domain) || domain_tag_name(domain)
      description = domain_description(domain, include_descriptions)
      build_tag(name, description)
    end)
    |> Enum.uniq_by(& &1[:name])
    |> Enum.sort_by(& &1[:name])
  end

  @doc """
  Gets the tag name for an operation based on the route.

  ## Options

  - `:group_by` - Grouping strategy: `:resource` or `:domain`. Defaults to `:resource`.

  ## Examples

      iex> route = %{resource: MyApp.Blog.Post}
      ...> AshOaskit.TagBuilder.operation_tag(route, group_by: :resource)
      "Post"

      iex> route = %{resource: MyApp.Blog.Post}
      ...> AshOaskit.TagBuilder.operation_tag(route, group_by: :domain)
      "Blog"
  """
  @spec operation_tag(map(), keyword()) :: String.t()
  def operation_tag(route, opts \\ []) do
    group_by = Keyword.get(opts, :group_by, :resource)
    resource = Map.get(route, :resource)

    case group_by do
      :domain -> get_resource_domain_tag(resource)
      :custom -> Config.domain_tag(resource) || resource_tag_name(resource)
      _ -> resource_tag_name(resource)
    end
  end

  @doc """
  Gets tags for an operation (returns as a list for OpenAPI operation tags).

  ## Examples

      iex> route = %{resource: MyApp.Blog.Post}
      ...> AshOaskit.TagBuilder.operation_tags(route)
      ["Post"]
  """
  @spec operation_tags(map(), keyword()) :: list(String.t())
  def operation_tags(route, opts \\ []) do
    [operation_tag(route, opts)]
  end

  @doc """
  Builds a tag object with optional description and external docs.

  ## Options

  - `:external_docs` - External documentation URL and description.

  ## Examples

      iex> AshOaskit.TagBuilder.build_tag("Posts", "Operations for blog posts")
      %{name: "Posts", description: "Operations for blog posts"}

      iex> AshOaskit.TagBuilder.build_tag("Posts", nil,
      ...>   external_docs: %{url: "https://docs.example.com"}
      ...> )
      %{name: "Posts", externalDocs: %{url: "https://docs.example.com"}}
  """
  @spec build_tag(String.t(), String.t() | nil, keyword()) :: map()
  def build_tag(name, description \\ nil, opts \\ []) do
    external_docs = Keyword.get(opts, :external_docs)

    tag = %{name: name}
    tag = if description, do: Map.put(tag, :description, description), else: tag
    tag = if external_docs, do: Map.put(tag, :externalDocs, external_docs), else: tag
    tag
  end

  @doc """
  Gets the default grouping strategy for the given domains.

  Checks the first domain's configuration for `group_by` setting.
  Defaults to `:resource`.

  ## Examples

      iex> AshOaskit.TagBuilder.get_default_grouping([MyApp.Blog])
      :resource
  """
  @spec get_default_grouping(list(module())) :: atom()
  def get_default_grouping([]), do: :resource

  def get_default_grouping([domain | _]) do
    Config.group_by(domain) || :resource
  end

  @doc """
  Extracts the tag name from a resource module.

  Returns the last segment of the module name in PascalCase for
  human-readable tag names.

  ## Examples

      iex> AshOaskit.TagBuilder.resource_tag_name(MyApp.Blog.Post)
      "Post"
  """
  @spec resource_tag_name(module() | nil) :: String.t() | nil
  def resource_tag_name(nil), do: nil

  def resource_tag_name(resource) when is_atom(resource) do
    resource
    |> Module.split()
    |> List.last()
  end

  @doc """
  Extracts the tag name from a domain module.

  ## Examples

      iex> AshOaskit.TagBuilder.domain_tag_name(MyApp.Blog)
      "Blog"
  """
  @spec domain_tag_name(module()) :: String.t()
  def domain_tag_name(domain) when is_atom(domain) do
    Config.domain_tag(domain) ||
      domain
      |> Module.split()
      |> List.last()
  end

  @doc """
  Merges custom tags with generated tags.

  Custom tags take precedence over generated tags with the same name.

  ## Examples

      iex> generated = [%{name: "Posts"}, %{name: "Comments"}]
      ...> custom = [%{name: "Posts", description: "Custom description"}]
      ...> AshOaskit.TagBuilder.merge_tags(generated, custom)
      [%{name: "Posts", description: "Custom description"}, %{name: "Comments"}]
  """
  @spec merge_tags(list(map()), list(map())) :: list(map())
  def merge_tags(generated_tags, custom_tags) do
    custom_by_name = Map.new(custom_tags, &{&1[:name], &1})

    generated_tags
    |> Enum.map(fn tag ->
      Map.get(custom_by_name, tag[:name], tag)
    end)
    |> Enum.concat(
      Enum.reject(custom_tags, fn custom ->
        Enum.any?(generated_tags, &(&1[:name] == custom[:name]))
      end)
    )
    |> Enum.sort_by(& &1[:name])
  end

  @doc """
  Builds tags with external documentation links.

  ## Options

  - `:base_url` - Base URL for external documentation.
  - `:group_by` - Grouping strategy.

  ## Examples

      iex> AshOaskit.TagBuilder.build_tags_with_docs([MyApp.Blog],
      ...>   base_url: "https://docs.example.com"
      ...> )
      [
        %{
          name: "Post",
          description: "Operations on Post resources",
          externalDocs: %{url: "https://docs.example.com/post"}
        }
      ]
  """
  @spec build_tags_with_docs(list(module()), keyword()) :: list(map())
  def build_tags_with_docs(domains, opts \\ []) do
    base_url = Keyword.get(opts, :base_url)
    group_by = Keyword.get(opts, :group_by) || get_default_grouping(domains)

    tags = build_tags(domains, Keyword.put(opts, :group_by, group_by))

    if base_url do
      Enum.map(tags, fn tag ->
        slug = tag[:name] |> String.downcase() |> String.replace(" ", "-")
        external_docs = %{url: "#{base_url}/#{slug}"}
        Map.put(tag, :externalDocs, external_docs)
      end)
    else
      tags
    end
  end

  # Private helper functions

  @spec get_domain_resources(module()) :: list(module())
  defp get_domain_resources(domain) do
    Ash.Domain.Info.resources(domain)
  end

  @spec resource_description(module(), boolean()) :: String.t() | nil
  defp resource_description(_, false), do: nil

  defp resource_description(resource, true) do
    name = resource_tag_name(resource)
    "Operations on #{name} resources"
  end

  @spec domain_description(module(), boolean()) :: String.t() | nil
  defp domain_description(_, false), do: nil

  defp domain_description(domain, true) do
    name = domain_tag_name(domain)
    "#{name} domain operations"
  end

  @spec get_resource_domain_tag(module()) :: String.t()
  defp get_resource_domain_tag(resource) do
    case Ash.Resource.Info.domain(resource) do
      nil -> resource_tag_name(resource)
      domain -> domain_tag_name(domain)
    end
  end
end
