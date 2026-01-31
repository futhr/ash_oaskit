defmodule AshOaskit.Generators.V31 do
  @moduledoc """
  OpenAPI 3.1 spec generator.

  Generates OpenAPI 3.1.0 specifications from Ash domains and resources.
  This is the recommended version for new projects, as it aligns with
  JSON Schema 2020-12 and supports features not available in 3.0:

  - **Nullable types via type arrays** — `"type": ["string", "null"]` instead of `"nullable": true`
  - **`$schema` keyword** — explicit JSON Schema dialect declaration
  - **`const` keyword** — for single-value enumerations
  - **Webhooks** — top-level `webhooks` object (not yet generated, but structurally valid)

  ## Relationship to Other Modules

  This module is a thin entry point that delegates to `AshOaskit.Generators.Shared`,
  which in turn coordinates `AshOaskit.Generators.Generator`,
  `AshOaskit.Generators.InfoBuilder`, and `AshOaskit.Generators.PathBuilder`.
  The only responsibility of this module is to pin the `:version` option to `"3.1"`
  before handing off to the shared pipeline.

  ## Usage

      spec = AshOaskit.Generators.V31.generate([MyApp.Blog], title: "Blog API")
      spec["openapi"]
      #=> "3.1.0"

  In practice you rarely call this module directly. Use the high-level API instead:

      AshOaskit.spec(domains: [MyApp.Blog], version: "3.1")

  Or let the `AshOaskit.Router` macro handle version routing automatically.
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
