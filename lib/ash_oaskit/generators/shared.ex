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
end
