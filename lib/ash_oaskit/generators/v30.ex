defmodule AshOaskit.Generators.V30 do
  @moduledoc """
  OpenAPI 3.0 spec generator.

  Generates OpenAPI 3.0.3 specifications from Ash domains and resources,
  providing backwards compatibility for tools and code generators that do
  not yet support OpenAPI 3.1. Key differences from the 3.1 output:

  - **Nullable fields** — uses `"nullable": true` instead of type arrays
  - **No `$schema` keyword** — JSON Schema draft-07 subset, not 2020-12
  - **`exclusiveMinimum` / `exclusiveMaximum`** — boolean form, not numeric
    (not currently generated; Ash does not expose exclusive constraints)
  - **No `const` keyword** — single-value enums use `"enum": ["value"]`
    (not currently generated; Ash does not expose const constraints)

  ## When to Use 3.0

  Choose 3.0 when your consumers rely on tooling that has not adopted 3.1,
  such as older versions of Swagger UI, swagger-codegen, or openapi-generator.
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
