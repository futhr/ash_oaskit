---
name: contract-impact
description: Trace compatibility impact before changing generated OpenAPI documents, Ash type mapping, resource or route scope, cached spec modules, Phoenix/Plug serving, Mix tasks, or the public Hex API. Select affected consumers and verification boundaries; skip prose-only changes without behavior claims.
user-invocable: false
---

# Contract impact

Input: the requested behavior change or proposed diff, its public entry point,
and the expected generated or served result. Derive missing technical context
from callers and tests; clarify only unresolved product behavior.

1. Trace the entry point through the owning builder and normalization. For
   cached spec modules, include `Spec.build/2` and `modify_spec/1`; for route
   changes, include route gathering and resource scope. Compare current and
   intended behavior with a concrete resource, route, or schema example.
2. Identify whether the contract changes in 3.0, 3.1, or both. Assess affected
   request inputs, response shapes, component identities, operation IDs, and
   serialized JSON/YAML, rather than relying on the edited module's filename.
3. Trace only the optional integration seams the mechanism reaches: AshJsonApi,
   Phoenix, Igniter, custom SpecBuilder, or serving adapters. Separate base
   library compilation from integration behavior and cached consumer behavior.
4. Select focused owner tests and an end-to-end assertion at the public
   boundary. Exercise both versions for shared behavior. Identify docs and
   package content affected by the change before updating them.

Read [the public facade](../../../lib/ash_oaskit.ex) and
[version routing](../../../lib/ash_oaskit/open_api.ex) for generation changes,
[spec modules](../../../lib/ash_oaskit/spec.ex) for caching/customization,
and [the generator](../../../lib/ash_oaskit/generators/generator.ex) for
resource scope and shared builder context. Read `mix.exs` and
[consumer checks](../../../scripts/verify_consumer.exs) only when package or
optional-dependency compatibility is at stake; inspect their prerequisites
before running them.

Output: the affected contract and consumers, the implementation owner, the
selected verification boundaries, and unresolved compatibility questions.
At completion, report observed before/after behavior and checks actually run;
leave unavailable integration or packaged-consumer evidence explicitly unverified.
