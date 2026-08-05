---
name: review-code
description: Review AshOaskit Elixir library changes for OpenAPI/Ash correctness, optional Phoenix integration safety, test integrity, AI-slop/provenance quality signals, docs, and quality-gate risk. Use for code review, audits, bug hunts, coverage review, or architecture review.
allowed-tools: Bash(rg *), Bash(mix *), Bash(git *)
---

# Review Code

Review AshOaskit as a Hex library. Report findings with `file:line`, why it
matters, and the smallest fix. Do not treat AI-origin signals as proof; treat
them as weak provenance evidence and report only concrete quality issues.

## Checklist

1. **OpenAPI correctness** — preserve 3.0 vs 3.1 differences, `$ref` string-key
   shape, nullable handling, schema deduplication, path parameter conversion,
   and Oaskit validation behavior.
2. **Ash/AshJsonApi integration** — keep Ash introspection paths explicit and
   version-safe; do not bypass existing mapper/builder modules for special
   cases that belong in shared helpers.
3. **Library posture** — no surprising OTP app callback, hidden global app-env
   dependency, network/DB/process/clock side effects in pure APIs, or avoidable
   runtime deps. Optional Phoenix/AshJsonApi/Igniter behavior must remain
   optional and behind explicit adapters, macros, or Mix tasks.
4. **Phoenix/Plug integration** — router/controller helpers stay thin; check
   response content type, format handling, route generation, path conversion,
   and no business logic or unsafe raw input handling in Plug/Phoenix seams.
5. **Elixir quality** — assertive pattern matching, tagged errors, no dynamic
   atom creation from external input, Credo nesting stays at max 2, no complex
   `with ... else` branches when tagged helper results would be clearer, and
   no broad `rescue _` hiding defects. Do not solve nesting by adding Credo
   excludes or disable comments.
6. **AI-slop / provenance noise** — no generated-by/co-author markers,
   vibe-code labels, AI attribution, pointless comments that restate code,
   section dividers, generic "helper" comments, or ownerless TODO/FIXME/HACK.
7. **Test integrity** — no broad skip/exclude blocks, coverage-ignore/no-cover
   pragmas, `assert true`, execution-only tests, or stubs that bypass the
   behavior under review just to raise coverage. Tests should assert generated
   schema shape, warnings/log capture, and validation outcomes.
8. **Docs and gates** — public APIs have useful docs/specs; doctests/examples
   match current API; `mix format --check-formatted`, `mix compile
   --warnings-as-errors`, `mix credo --strict`, `mix test`, coverage, Dialyzer,
   Doctor, Sobelow, and dependency audit risk is called out when relevant.

## Output

- `[ ] Must fix: path:line — issue, impact, smallest fix`
- `[~] Should improve: path:line — issue, tradeoff, suggested fix`
- `[x] Solid: checked areas with no findings`
