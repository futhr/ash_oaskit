---
name: oaskit-diagnosis-loop
description: "Apply automatically when AshOaskit has a failing test, invalid generated document, cross-version regression, schema mismatch, warning, or unexpected optional-integration behavior. Reproduce the smallest failing generation path and fix the owning cause."
---

# AshOaskit diagnosis loop

Start with the observable mismatch: inputs, selected OpenAPI version, optional modules loaded, and
the exact generated fragment or validation error.

1. Reproduce with the smallest Ash resource, route set, or schema fixture that still fails.
2. Compare 3.0 and 3.1 only when the behavior is shared; otherwise keep the unaffected version as a
   control.
3. Follow the value through version routing, `Shared`, the owning builder, `TypeMapper` or
   `Schemas.Nullable`, `SchemaBuilder`, and normalization. Rank falsifiable causes before editing.
4. Change the owning shared abstraction. Do not add output surgery, broad rescue clauses, warning
   suppression, or a one-fixture special case.
5. Retain a regression that asserts semantic document shape and validation outcome, not merely
   successful execution or a large snapshot with no focused assertion.

If the failure depends on a missing optional package or consumer application, record the exact
missing evidence and keep the conclusion bounded. Never convert an unavailable integration into a
pass.

Do not edit before one causal hypothesis explains the observed evidence. Run one discriminating
probe at a time and record its result. After three materially distinct failed fixes for the same
symptom, stop local patching and reopen the architecture, state-ownership, interface, or versioning
assumption. Close only with fresh output from the minimized reproduction and retained regression;
an unavailable lane remains unverified.
