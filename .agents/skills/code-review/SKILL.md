---
name: code-review
description: Review a proposed diff or completed implementation for reachable correctness, security, test-integrity, public-contract, optional-integration, and Hex consumer regressions. Apply at the review stage, including final review before delivery; scale checks to the changed mechanism rather than inspecting unrelated subsystems.
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

Output: actionable findings ordered by impact, each with `path:line`, the
trigger, consequence, evidence, and smallest useful fix. Separate confirmed
defects from questions requiring unavailable evidence. If there are no
findings, state the reviewed scope and verification limits; do not imply that
unexecuted checks passed or add approval gates.
