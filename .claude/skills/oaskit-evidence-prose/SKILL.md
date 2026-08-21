---
name: oaskit-evidence-prose
description: "Apply automatically whenever writing or revising AshOaskit README text, HexDocs, moduledocs, usage rules, examples, release notes, audits, skill files, comments, or user-facing summaries. Keep claims concrete, versioned, executable, and scoped to available evidence."
---

# AshOaskit evidence prose

Write for library consumers deciding whether a generated contract is safe to depend on.

- Name the exact API, OpenAPI version, optional dependency, and observable behavior instead of
  generic quality, speed, completeness, or compatibility claims.
- Distinguish implemented code, focused test evidence, generated-document validation, packaged
  artifact evidence, and downstream-consumer evidence. One does not imply the next.
- Keep examples executable against the current public API. Verify module/function names, option
  shapes, output keys, and version-specific results from source or a real command.
- Explain graceful optional-integration behavior; never imply Phoenix, AshJsonApi, or Igniter is
  required when the library contract says otherwise.
- Remove filler, repeated conclusions, generated-sounding section dividers, historical narration,
  and comments that restate syntax. Preserve domain vocabulary such as `$ref`, JSON Schema,
  OpenAPI 3.0/3.1, Ash resource, and route introspection.

Before finishing, ask silently: which sentence could be pasted into an unrelated library, which
claim is stronger than its evidence, and which example has not been exercised?
