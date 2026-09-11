# Compatibility and migration

Changes to generated contracts require regenerating snapshots and clients;
do not patch exported JSON by hand. Use `SpecModifier` for application-specific changes.

- Dependencies now require Ash 3.33+, Spark 2.6+, Plug 1.20.3+, and Oaskit 0.14.2+.
  Optional integrations require AshJsonApi 1.7.1+, Phoenix 1.8.13+, and Igniter 0.6.29+.
  Configure `config :ash, default_string_length_count: :codepoints` in the consuming app.
- Decimal output and defaults are exact strings. Decimal inputs may also be numbers.
  Decimal bounds are recorded in `x-ash-minimum`/`x-ash-maximum`; Ash enforces them.
- `{Name}Resource` describes a resource object, `{Name}Response` a member document,
  and `{Name}CollectionResponse` a document whose `data` is an array.
- Output attributes are not required: sparse fieldsets and authorization may omit them.
  Nullability and whether a member is required are independent.
- Input components reflect each route's action, accepted attributes, defaults, and
  argument placement. Routes with different body contracts get distinct component names.
- Filter operator names follow Ash, including `not_eq`, `string_starts_with`,
  `string_ends_with`, `has`, and `intersects`. Pagination follows the action's capabilities.
- Included-resource schemas follow configured public include paths. Unknown types warn
  and produce unconstrained schemas instead of incorrect string schemas. Define a custom
  type's `json_schema/1` callback when its wire representation is known. `Ash.Type.Range`
  needs an application-defined JSON representation; upstream does not serialize it to JSON.
- Duplicate generated operation IDs receive stable method/path suffixes. Explicit
  duplicate IDs and conflicting path/method declarations raise instead of overwriting routes.
- Automatic upload documentation uses AshJsonApi's `multipart/x.ash+form-data`: a JSON
  `data` part refers to arbitrarily named uploaded parts. Do not assume the legacy
  low-level `MultipartSupport.build_multipart_schema/2` helper describes this protocol;
  use the generated operation's request body.
- Security helpers emit an empty operation-level security list for public operations
  and document rate-limit headers on responses, not requests.

Generation normalizes the document and checks local schema references. Full OpenAPI
validation is explicit with `AshOaskit.validate/1` or `validate!/1`.

CI exercises current dependencies, minimum runtime dependencies, optional integrations,
and a built-package consumer without optional integrations. Local checks are:

```sh
mix check --no-retry
mix coveralls
mix docs --warnings-as-errors
mix run scripts/verify_notebooks.exs
mix run scripts/verify_consumer.exs minimal
mix run scripts/verify_consumer.exs minimum
mix run scripts/verify_consumer.exs integrations
mix run scripts/verify_consumer.exs locked
```

Consumer fixtures resolve without dependency overrides. The selected compatible
minimum set uses Jason 1.4.5: Jason 1.4.0–1.4.4 exclude Decimal 3 and cannot be
combined with this library's Decimal 3.1 security floor. The `locked` fixture copies
the checkout lockfile into an isolated consumer; the other fixtures resolve afresh.
They exercise spec generation and Plug serving; integration fixtures also exercise
Phoenix introspection and Igniter scaffolding. Notebook checks evaluate executable
cells and validate their generated specs, excluding setup and marked snippets.

For the optional installer, avoid Igniter 0.8.1–0.8.3. Those releases are affected by
terminal escape injection in package confirmation prompts; Igniter 0.8.4 fixes
[GHSA-cj7w-j579-gc42](https://github.com/ash-project/igniter/security/advisories/GHSA-cj7w-j579-gc42).
The checkout locks the patched release. Applications manage their own lockfiles.

Publishing additionally requires a package-scoped `HEX_API_KEY` in the protected
`hex-publish` environment. An existing repository secret cannot be read back for migration;
a maintainer must provision the environment secret and remove the repository-scoped copy.
