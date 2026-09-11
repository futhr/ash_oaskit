# Contributing to AshOaskit

Bug fixes, documentation improvements, and focused feature proposals are welcome.

## How Can I Contribute?

### Reporting Bugs

Before submitting a bug report:

- Check existing [issues](https://github.com/futhr/ash_oaskit/issues) first
- Include your Elixir and OTP versions (`elixir --version`)
- Provide minimal reproduction steps
- Include the full error message and stacktrace

### Suggesting Enhancements

- Open an issue describing the enhancement
- Explain the use case and benefits
- Consider how it fits with existing functionality

### Pull Requests

1. Fork the repository
2. Create a feature branch (`git checkout -b feat/amazing-feature`)
3. Make your changes
4. Run quality checks (`mix check`)
5. Commit using conventional commits
6. Push and open a PR

## Development Setup

```bash
git clone https://github.com/futhr/ash_oaskit.git
cd ash_oaskit
mix deps.get
mix test
```

## Development Workflow

```bash
mix test            # Run tests
mix coveralls.html  # Run tests with coverage
mix check --no-retry # Run full quality suite
MIX_ENV=no_optional mix compile --no-optional-deps --warnings-as-errors
mix docs            # Generate documentation
mix dialyzer        # Run dialyzer
mix credo --strict  # Run credo
```

Run `mix bench` separately from tests and other heavy work. It uses development-only
Benchee dependencies and writes Markdown reports to `bench/output/`. Review and
commit the results when changing measured hot paths, then run
`mix docs --warnings-as-errors` to verify their ExDoc pages. See the
[benchmark methodology](bench/benchmarks.md) for input definitions and measurement limits.

## Code Quality Requirements

All contributions must:

- Pass `mix format --check-formatted`
- Pass `mix credo --strict`
- Pass `mix dialyzer`
- Have 100% test coverage for new code
- Include `@spec` for all public functions
- Document public functions where the name and types do not tell the whole story

### Elixir Style

Use `mix format` and the project's Credo configuration as the enforceable baseline,
with the [community Elixir Style Guide](https://github.com/christopheradams/elixir_style_guide)
as supplementary guidance.

- Limit nesting to two levels inside functions. Credo counts `if`, `unless`,
  `case`, `cond`, anonymous functions, `for`, and `with` toward this limit.
- Prefer pattern-matched function clauses and guards for dispatch on data shapes.
- Use pipelines for successive transformations of the same value.
- Use `Map.update`, `put_in`, and `update_in` instead of manually rebuilding each
  layer of a nested map. Preserve the intended behavior for missing keys.
- Extract helpers around meaningful operations, not merely to hide nesting.
- Keep explicit conditionals when they express the decision more clearly.

## Commit Messages

We use [Conventional Commits](https://www.conventionalcommits.org/):

- `feat:` New features
- `fix:` Bug fixes
- `docs:` Documentation changes
- `refactor:` Code refactoring (no functional changes)
- `test:` Test additions or changes
- `chore:` Maintenance tasks (deps, CI, etc.)

Examples:

```
feat: add support for custom type mappings
fix: handle nil values in constraint processing
docs: improve TypeMapper documentation
test: add coverage for edge cases in V31 generator
```

## Project Structure

```
lib/
├── ash_oaskit.ex              # Main module with public API
├── ash_oaskit/
│   ├── support/controller.ex  # Phoenix controller
│   ├── generators/
│   │   ├── v30.ex             # OpenAPI 3.0 generator
│   │   └── v31.ex             # OpenAPI 3.1 generator
│   ├── open_api.ex            # Core spec generation logic
│   └── core/type_mapper.ex    # Ash type to JSON Schema mapping
└── mix/
    └── tasks/
        ├── ash_oaskit.generate.ex  # Mix task for CLI generation
        └── ash_oaskit.install.ex   # Igniter installation task
```

## Testing Guidelines

- Write tests for all new functionality
- Use descriptive test names that explain the behavior
- Group related tests with `describe` blocks
- Use property-based assertions when exact output varies
- Test both success and error cases

Keep tests focused on observable behavior:

```elixir
describe "feature_name/1" do
  test "uses the configured JSON:API field name" do
    assert Config.json_field_name(Post, :published_at) == "publishedAt"
  end

  test "rejects an unsupported OpenAPI version" do
    assert_raise ArgumentError, fn ->
      AshOaskit.spec(domains: [Blog], version: "2.0")
    end
  end
end
```

## Documentation

- All public modules must have `@moduledoc`
- Write module documentation around the reader's task, not the source layout
- Add examples where they clarify behavior or configuration
- Keep implementation details out of public documentation unless callers rely on them

## Releasing

Publication is allowed only from an annotated `vVERSION` tag whose commit is on protected
`main`. The publish workflow reruns the complete gate, builds the package outside the repository,
publishes through the protected `hex-publish` environment, downloads the registry tarball, compares
it byte-for-byte with the validated build, and attests those registry bytes.

The canonical repository must keep these external controls enabled:

- protect `main`, require every current Continuous Integration job, require the branch to be up to
  date, and forbid force pushes and deletion;
- protect `v*` tags from creation except by maintainers and forbid updates and deletion;
- configure `hex-publish` with administrator bypass disabled, a required reviewer, and a `v*`
  deployment-tag policy;
- scope `HEX_API_KEY` to the environment and a Hex key that can publish only `ash_oaskit`.

Verify the controls before every release:

```bash
mix run --no-start scripts/verify_release_controls.exs
```

Run this with a maintainer's authenticated `gh` CLI. It checks effective rulesets,
current CI job names, immutable release tags, environment approval, deployment tag
policy, and the presence of the environment secret. GitHub cannot reveal an existing
secret for migration: set a package-scoped key in `hex-publish` manually, then remove
the repository-scoped copy. Confirm the key's package permissions in Hex itself.
The environment reviewer is the repository owner; self-review remains allowed so
a sole maintainer can explicitly approve a release. Administrator bypass is disabled.

Then update the version and changelog, merge the release commit to `main`, wait for required CI,
and create an annotated tag with `git tag -a vVERSION -m vVERSION`. Never move or reuse a tag.

## Release Process

Releases are managed by maintainers using git_ops:

1. Run `mix check` and the release-controls verifier above.
2. Preview changes with `mix git_ops.release --dry-run --output /path/to/release-preview`.
3. Apply the proposed version/changelog changes on a branch and merge them through a reviewed PR.
4. After required CI passes on `main`, create and push only the annotated release tag.

Do not use the local `mix release` alias to push a release commit directly to protected `main`.
It commits and tags locally and does not replace the reviewed release process.

## Questions?

Feel free to open an issue for questions or join discussions in existing issues.
