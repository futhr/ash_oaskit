# Contributing to AshOaskit

Thank you for your interest in contributing to AshOaskit! This guide will help you get started.

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
mix check           # Run full quality suite
mix docs            # Generate documentation
mix dialyzer        # Run dialyzer
mix credo --strict  # Run credo
```

## Code Quality Requirements

All contributions must:

- Pass `mix format --check-formatted`
- Pass `mix credo --strict`
- Pass `mix dialyzer`
- Have 100% test coverage for new code
- Include `@spec` for all public functions
- Include `@doc` with examples for public functions

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
│   ├── controller.ex          # Phoenix controller
│   ├── generators/
│   │   ├── v30.ex             # OpenAPI 3.0 generator
│   │   └── v31.ex             # OpenAPI 3.1 generator
│   ├── open_api.ex            # Core spec generation logic
│   └── type_mapper.ex         # Ash type to JSON Schema mapping
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

Example test structure:

```elixir
describe "feature_name/1" do
  test "handles normal input" do
    # Arrange
    input = ...

    # Act
    result = Module.feature_name(input)

    # Assert
    assert result == expected
  end

  test "raises on invalid input" do
    assert_raise ArgumentError, fn ->
      Module.feature_name(invalid_input)
    end
  end
end
```

## Documentation

- All public modules must have `@moduledoc`
- All public functions must have `@doc` and `@spec`
- Include usage examples in documentation
- Use markdown formatting in docs

## Release Process

Releases are managed by maintainers using git_ops:

1. Ensure all tests pass: `mix check`
2. Run `mix release` (alias for `mix git_ops.release`) — updates changelog, bumps version, commits, and tags
3. Push with tags: `git push --follow-tags`
4. CI will publish to Hex.pm on the `v*` tag

## Questions?

Feel free to open an issue for questions or join discussions in existing issues.
