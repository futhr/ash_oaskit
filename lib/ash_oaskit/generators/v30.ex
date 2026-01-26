defmodule AshOaskit.Generators.V30 do
  @moduledoc """
  OpenAPI 3.0 spec generator.

  Generates OpenAPI 3.0.0 specifications from Ash domains and resources,
  providing backwards compatibility for tools that don't support 3.1.
  """

  alias AshOaskit.Generators.Shared

  @doc """
  Generate an OpenAPI 3.0 specification from the given domains.
  """
  @spec generate(list(module()), keyword()) :: map()
  def generate(domains, opts) do
    opts = Keyword.put(opts, :version, "3.0")
    Shared.generate(domains, opts)
  end
end
