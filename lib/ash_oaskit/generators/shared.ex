defmodule AshOaskit.Generators.Shared do
  @moduledoc """
  Shared functionality between OpenAPI 3.0 and 3.1 generators.

  This module serves as the main entry point for spec generation, delegating
  to specialized builder modules for focused functionality.

  ## Module Organization

  The generation logic is split across focused modules:

  - `AshOaskit.Generators.Generator` - Main orchestration and components
  - `AshOaskit.Generators.InfoBuilder` - Info object, servers, and tags
  - `AshOaskit.Generators.PathBuilder` - Paths and operations

  ## Usage

      # Generate a complete OpenAPI spec
      spec = Shared.generate([MyApp.Domain], version: "3.1", title: "My API")

  ## Options

  See `AshOaskit.Generators.Generator.generate/2` for full options list.
  """

  alias AshOaskit.Generators.Generator
  alias AshOaskit.Generators.InfoBuilder
  alias AshOaskit.Generators.PathBuilder

  @type version :: String.t()
  @type opts :: keyword()

  @doc """
  Generate an OpenAPI specification from the given domains.

  Delegates to `AshOaskit.Generators.Generator.generate/2`.

  ## Options

    * `:version` - OpenAPI version ("3.0" or "3.1")
    * `:title` - API title
    * `:api_version` - API version string
    * `:description` - API description
    * `:terms_of_service` - Terms of service URL
    * `:contact` - Contact information map
    * `:license` - License information map
    * `:servers` - List of server URLs or server objects
    * `:security` - Security requirements

  """
  @spec generate(list(module()), opts()) :: map()
  defdelegate generate(domains, opts), to: Generator

  @doc """
  Builds the Info object for the OpenAPI spec.

  Delegates to `AshOaskit.Generators.InfoBuilder.build_info/1`.
  """
  @spec build_info(opts()) :: map()
  defdelegate build_info(opts), to: InfoBuilder

  @doc """
  Builds servers array from options.

  Delegates to `AshOaskit.Generators.InfoBuilder.build_servers/1`.
  """
  @spec build_servers(opts()) :: list(map())
  defdelegate build_servers(opts), to: InfoBuilder

  @doc """
  Builds paths from domains.

  Delegates to `AshOaskit.Generators.PathBuilder.build_paths/2`.
  """
  @spec build_paths(list(module()), opts()) :: map()
  defdelegate build_paths(domains, opts), to: PathBuilder

  @doc """
  Builds components (schemas) from domains.

  Delegates to `AshOaskit.Generators.Generator.build_components/2`.
  """
  @spec build_components(list(module()), opts()) :: map()
  defdelegate build_components(domains, opts), to: Generator

  @doc """
  Builds tags from domain resources.

  Delegates to `AshOaskit.Generators.InfoBuilder.build_tags/1`.
  """
  @spec build_tags(list(module())) :: list(map())
  defdelegate build_tags(domains), to: InfoBuilder

  @doc """
  Adds a key-value pair to a map if the value is not nil or empty list.

  Delegates to `AshOaskit.Generators.InfoBuilder.maybe_add/3`.
  """
  @spec maybe_add(map(), String.t(), any()) :: map()
  defdelegate maybe_add(map, key, value), to: InfoBuilder

  @doc """
  Humanizes an underscore-separated string.

  Delegates to `AshOaskit.Generators.PathBuilder.humanize/1`.
  """
  @spec humanize(String.t()) :: String.t()
  defdelegate humanize(string), to: PathBuilder
end
