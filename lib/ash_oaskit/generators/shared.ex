defmodule AshOaskit.Generators.Shared do
  @moduledoc """
  Compatibility entry point for the shared generator. See `AshOaskit.Generators.Generator.generate/2`.
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
