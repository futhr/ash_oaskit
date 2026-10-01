---
name: library-docs
description: Write or revise consumer-facing API claims and executable examples in README, HexDocs, usage rules, guides, Livebooks, moduledocs, or release notes. Verify signatures, options, OpenAPI versions, optional dependencies, and generated behavior; skip routine status messages and purely stylistic edits without contract claims.
user-invocable: false
---

# Library documentation

Input: the target documentation, reader's task, and behavior or example being
described. Read only the implementation and existing examples needed to support
that claim.

1. Check module/function names, arity, options, key shapes, and OpenAPI version
   against current source. Explain resource visibility, routed action inputs,
   nullability versus omission, caching, or optional dependencies when they
   affect the reader's result.
2. Keep examples internally consistent and executable at the stated boundary.
   Distinguish code run in this checkout from package installation, generated
   document validation, and downstream application execution. Label schematic
   examples as such rather than presenting them as tested output.
3. Put the guidance in the reader's existing document. Keep README and
   `usage-rules.md` type tables aligned when mappings change; keep operational
   contribution and release procedures in CONTRIBUTING.md. Avoid duplicating
   repository policy in consumer documentation.
4. Validate changed executable examples with existing tools when available.
   For Livebook cells, inspect
   [the notebook verifier](../../../scripts/verify_notebooks.exs) and run
   `mix run scripts/verify_notebooks.exs` with checkout dependencies. For HexDocs,
   use `mix docs --warnings-as-errors` when documentation generation is relevant.

Read [usage rules](../../../usage-rules.md) for consumer conventions,
[the facade](../../../lib/ash_oaskit.ex) and
[spec module behavior](../../../lib/ash_oaskit/spec.ex) for API examples,
or [contribution guidance](../../../CONTRIBUTING.md) for development commands,
only when the target text depends on them.

Output: revised text and examples in their owning files, with a concise account
of claims checked, examples actually exercised, and remaining limitations.
Keep library terminology and exact commands intact; replace generic quality,
performance, or compatibility claims with the observable behavior and evidence.
