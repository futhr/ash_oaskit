# Agent Guidelines for AshOaskit

## Repository contract

- This file is the canonical repository contract for coding agents. Preserve
  unrelated changes and existing local client settings and skills.
- Never push branches, tags, commits, or other Git refs. Keep commits local;
  the user performs every push manually.
- Never change repository visibility. Visibility changes are user-only actions;
  report a dependency on one and continue work that does not require it.
- Do not add dependencies without discussion.
- Use Conventional Commits: `type(optional scope): description`. Do not add
  `Co-Authored-By` or AI attribution. Release controls belong to
  [CONTRIBUTING.md](CONTRIBUTING.md).

## Skill selection and discovery

Repository skills live in tracked `.agents/skills/<name>/SKILL.md`. The AI
selects and reads matching skills from their descriptions as the task, changed
mechanism, or delivery stage requires. Do not ask the user to invoke a skill or
choose a slash command. Keep implicit invocation enabled. Clients without
native discovery must read this file, inspect skill descriptions, and read the
matching `SKILL.md` files themselves. Load supporting material only when relevant.

Codex discovers `.agents/skills` natively. Claude Code uses individual ignored
`.claude/skills/<name>` directory symlinks to `../../.agents/skills/<name>`.
Keep discovery link names equal to canonical skill names, preserve local
entries, and repair dangling links that target repository skills. `.claude/`
is entirely ignored; do not track client settings, hooks, or setup helpers.

## Project boundaries and owners

AshOaskit is a Hex library that generates OpenAPI 3.0 and 3.1 documents from
Ash domains and resources, with routes from AshJsonApi or Phoenix introspection.
Keep generation APIs free of unexpected network, database, process, or clock
side effects. Preserve optional AshJsonApi, Phoenix, and Igniter integrations;
Plug is a required dependency.

- `lib/ash_oaskit.ex` is the public facade. `open_api.ex` selects V30/V31 and
  normalizes through Oaskit. `spec.ex` implements cached spec modules created
  with `use AshOaskit`; retain cache configuration and customization behavior.
- `generators/shared.ex` delegates to `generators/generator.ex`, which prepares
  resource/route context and coordinates info, paths, and components. Preserve
  `resource_scope: :all` and `:routed`, including transitive schema dependencies.
- `core/config.ex` reads AshJsonApi DSL configuration; `core/route_gathering.ex`
  collects domain and resource routes. Keep missing optional integrations safe.
- Schema builders live under `schemas/`; path/operation builders under
  `generators/` and `routes/`; parameter, resource, response, and support modules
  own their respective document sections.
- Phoenix controller changes belong in `support/controller.ex`; router changes
  in `router.ex` and `router/plug.ex`; controller introspection in
  `phoenix_introspection.ex` and `open_api_controller.ex`. Keep these adapters thin.
- Custom generation belongs in `spec_builder.ex` implementations. Customize
  documents through `SpecModifier` or a spec module's `modify_spec/1` callback;
  do not edit generated files to repair generation defects.
- Mix tasks live in `lib/mix/tasks/`. Consumer-facing guidance belongs in
  [usage-rules.md](usage-rules.md), README, and the relevant guides or notebooks.

## Generation invariants

- All Ash type conversions go through `AshOaskit.TypeMapper`
  (`core/type_mapper.ex`); do not add parallel maps in `PropertyBuilders`.
  For new simple types, update `@simple_type_schemas`; compound types use
  `complex_type_schema/2`; Ash.Type module aliases use `@ash_type_to_atom`.
  Add mapper tests and update the README and usage-rules type tables.
- Use `AshOaskit.Schemas.Nullable` for nullability with the appropriate atom
  or string key mode. Simple 3.0 schemas use `nullable: true`; 3.1 schemas use
  type arrays including null. Preserve enum and composition constraints.
  Membership in `required` controls omission separately from nullability.
- Build component references with `AshOaskit.Core.SchemaRef.schema_ref/1`.
  Its `"$ref"` string key is required for Oaskit normalization.
- Preserve `SchemaBuilder` cycle detection (`mark_seen/2`, `seen?/2`, and the
  separate input tracking), first-definition deduplication, and ownership
  checks that reject resource and embedded component-name collisions.
- Use `Core.PathUtils` for path conversion and parameter extraction and
  `Core.PathRegistry` for conflict detection and operation ID disambiguation.
- Preserve `Core.JsonKeys` checks before normalization and local schema-pointer
  validation through `Schemas.References`. Literal examples, defaults, enum
  values, and extension data must not be interpreted as schema references.
- Keep attribute, calculation, aggregate, and relationship visibility and
  routed action inputs intact. Private fields must not enter public contracts.
- Use `Logger.warning` for ignored unknown inputs in catch-all clauses, including
  invalid spec modifiers. Preserve errors where invalid input must fail; do not
  hide defects with broad rescues or warning suppression.

## Verification and communication

- Mirror source paths in `test/ash_oaskit/` and `test/mix/tasks/`; keep
  cross-cutting integration tests at the existing test roots. Fixtures live in
  `test/support/`; use `AshOaskit.Test.Blog` for general generation,
  `SimpleDomain` and `EdgeCaseDomain` for edge cases, and relationship fixtures
  for linkage. Capture expected warnings with `ExUnit.CaptureLog`.
- For behavior changes, assert observable schema shape, validation results,
  and failure cases. Shared OpenAPI changes need both 3.0 and 3.1 coverage;
  recursion changes need embedded and relationship schema coverage.
  Do not weaken tests, coverage checks, or Credo settings to make a gate pass.
- Follow `.credo.exs` and the Elixir style guidance in CONTRIBUTING.md,
  including the two-level nesting limit. Keep public docs and `@spec` useful.
- For application code, run focused tests and `mix check --no-retry` using the
  configured tools in `.check.exs`. The optional-dependency compile is
  `MIX_ENV=no_optional mix compile --no-optional-deps --warnings-as-errors`.
  Run `mix deps.unlock --check-unused` separately for dependency changes;
  it is not in `.check.exs`.
  For guidance-only changes, validate metadata, file references, Git tracking
  and ignore boundaries, and discovery links with existing tools.
- Run notebook, benchmark, or packaged-consumer checks only when the change
  needs their evidence. Inspect their existing scripts and CONTRIBUTING.md
  first; do not install dependencies or add tooling without authorization.
- State what was actually reviewed and run, its result, and material limits.
  Planned checks and static inspection are not runtime or consumer evidence.
  Write concrete prose, preserve exact identifiers and measured results, and
  remove filler and comments that merely restate code.
