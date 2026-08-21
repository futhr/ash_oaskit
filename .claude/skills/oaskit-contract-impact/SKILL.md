---
name: oaskit-contract-impact
description: "Apply automatically when an AshOaskit change can alter generated OpenAPI, schema identity, version-specific encoding, Phoenix or Plug routes, optional integrations, Mix tasks, or the public Hex API. Trace the contract through generators, consumers, fixtures, documentation, and package output before editing."
---

# AshOaskit contract impact

Protect the generated contract, not only the module being edited.

## Route the change

1. Identify the public entry point and every builder or normalizer it reaches. Use `rg`, callers,
   tests, and generated examples; do not infer reachability from filenames alone.
2. Classify the change by OpenAPI 3.0, OpenAPI 3.1, or shared behavior. Preserve `$ref` string keys,
   version-specific nullable encoding, schema identity, cycle detection, and first-definition wins.
3. Trace optional seams independently: AshJsonApi, Phoenix router introspection, Plug/Phoenix
   serving, Igniter, custom `SpecBuilder`, and `SpecModifier`. The base library must still compile
   and degrade cleanly when an optional integration is absent.
4. Find downstream public evidence: facade types/specs, generated JSON/YAML shape, CLI tasks,
   README/HexDocs examples, `usage-rules.md`, notebooks or fixtures, and package contents.
5. Select focused tests for the owning builder plus cross-version and end-to-end generation. Add a
   regression at the narrowest boundary that would have caught the defect.

Do not use this behavior for prose-only edits that make no product or package claim; use
`oaskit-evidence-prose` instead. Do not add a dependency, compatibility shim, or post-generation
mutation to avoid fixing the owning mapper or builder.

## Completion evidence

Report the affected entry point, derived artifacts, optional-dependency matrix, tests run, and any
consumer evidence that remains unavailable. Static inspection is not generated-contract proof.
