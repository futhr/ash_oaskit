defmodule AshOaskit.Generators.V31 do
  @moduledoc """
  OpenAPI 3.1 spec generator.

  Generates OpenAPI 3.1.0 specifications from Ash domains and resources,
  using JSON Schema 2020-12 compliance.
  """

  alias AshOaskit.Generators.Shared

  @doc """
  Generate an OpenAPI 3.1 specification from the given domains.
  """
  @spec generate(list(module()), keyword()) :: map()
  def generate(domains, opts) do
    opts = Keyword.put(opts, :version, "3.1")
    Shared.generate(domains, opts)
  end
end
