defmodule AshOaskit.Generators.V30 do
  @moduledoc """
  Generates OpenAPI 3.0.3 documents. Prefer `AshOaskit.spec(domains: domains, version: "3.0")` for normalized output.
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
