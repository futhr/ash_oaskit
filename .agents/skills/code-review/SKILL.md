---
name: code-review
description: Review a diff, completed implementation or requested security audit for reachable correctness, field/input visibility, serving, cache, optional-integration and Hex consumer defects. Apply at review or audit stages; scope checks to the affected library boundary.
user-invocable: false
---

# Code review

Input: the diff or commit range, intended behavior, and available verification
results. Read changed files with their callers and relevant tests. Review the
final implementation, including any working-tree changes outside the commit range.

Select checks by the mechanism changed:

- Generated contracts: compare actual 3.0/3.1 output for the affected shape;
  check request/response semantics, component ownership, recursion, reference
  resolution, route collisions, and serialized consumer behavior. A static
  schema assertion and a real payload validation establish different evidence.
  Challenge the changed invariant with a plausible broken result: lost enum/
  composition constraint after nullable conversion, private fields exposed,
  literal example `$ref` traversed as a schema, unresolved recursion or cached
  output contaminated by a different version. Expected values must not simply
  call the same builder under review.
- Optional integrations and serving: check compile-time module availability,
  generated macros/routes, content type, format handling, request inputs, and
  cache/customization boundaries reached by the change.
- Security and errors: follow external input to atom creation, filesystem or
  process operations, and error handling. Report a concrete reachable path,
  rather than treating a suspicious token as proof of a vulnerability.
- Tests: confirm assertions cover changed behavior and would catch the defect.
  Check exclusions, mocks, or coverage pragmas that could hide failures. Use
  [integration tests](../../../test/ash_oaskit/integration_test.exs) and
  [Oaskit consumer tests](../../../test/ash_oaskit/oaskit_integration_test.exs)
  when the public generation or serving boundary changes.
- Guidance and skills: assess descriptions against realistic matching and
  nonmatching tasks, instruction ownership, supported commands, file references,
  and discovery/tracking boundaries. Metadata checks establish structural
  validity, not proof that a client selected or followed a workflow.
- Package or release changes: inspect `mix.exs`, affected workflow jobs, and
  [release controls](../../../CONTRIBUTING.md#releasing). Distinguish local
  checks from remote CI and external controls that were actually observed.
  Read the archive-consumer script before use: `minimal`, `minimum`,
  `integrations` and `locked` inputs establish different proof. Keep extracted archive, actual host and
  published registry results separate. An unavailable package lane does not
  prevent substantive source review and cannot become a compatibility pass.

Output: actionable findings ordered by impact, each with `path:line`, the
trigger, consequence, evidence, and smallest useful fix. Separate confirmed
defects from questions requiring unavailable evidence. If there are no
findings, state the reviewed scope and verification limits; do not imply that
unexecuted checks passed or add approval gates.

## Requested security audits

Record the revision, working-tree scope, selected dependency sources and actual
public generation or serving boundary. Distinguish trusted resource/route DSL
from request-controlled input. Trace response visibility, writable action inputs,
route scope and serialized output against the runtime contract; sensitive
write-only inputs and private response fields have different roles. For cached
specs, follow version, customization and caller configuration into the cache key.

Challenge each candidate against the strongest current control. A confirmed
finding needs a reachable caller-to-output trace and evidence for its consequence;
keep decisive unobserved facts as `needs_validation`, without a severity, and
reject disproved claims. Use bounded synthetic resources and ordinary Plug tests
for authorized regressions. Hostile native or availability execution needs
verified isolation and task authority; missing execution proof does not prevent
source review. Do not infer host authorization or deployment safety from a
generated security scheme. State the single-reviewer limit when independent
delegation is unavailable or unauthorized, and keep audit reports out of Git
unless explicitly requested there.

Method background: [Cloudflare's source-first audit workflow](https://github.com/cloudflare/security-audit-skill/tree/c1c8a8c1471069fb0e188eeaff69b8e8db6564a8/skills/security-audit).
