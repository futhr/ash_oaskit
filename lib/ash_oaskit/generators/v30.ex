defmodule AshOaskit.Generators.V30 do
  @moduledoc """
  Generates OpenAPI 3.0.3 documents.

  Use this version for consumers that do not support OpenAPI 3.1. Nullable
  schemas use `nullable: true`, and references are wrapped where OpenAPI 3.0
  does not permit useful `$ref` siblings.

  ## When to Use 3.0

  Choose 3.0 only when a consumer requires it; new integrations should prefer 3.1.
  If all consumers support 3.1, prefer `AshOaskit.Generators.V31` instead.

  ## Relationship to Other Modules

  This module is a thin entry point that delegates to `AshOaskit.Generators.Shared`,
  which in turn coordinates `AshOaskit.Generators.Generator`,
  `AshOaskit.Generators.InfoBuilder`, and `AshOaskit.Generators.PathBuilder`.
  The only responsibility of this module is to pin the `:version` option to `"3.0"`
  before handing off to the shared pipeline.

  ## Usage

      spec = AshOaskit.Generators.V30.generate([MyApp.Blog], title: "Blog API")
      spec[:openapi]
      #=> "3.0.3"

  In practice you rarely call this module directly. Use the high-level API instead:

      AshOaskit.spec(domains: [MyApp.Blog], version: "3.0")

  Or let the `AshOaskit.Router` macro handle version routing automatically.
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
