# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- OpenAPI 3.0 and 3.1 specification generation from Ash domains
- Automatic schema extraction from Ash resource attributes
- AshJsonApi route integration for path generation
- Comprehensive type mapping:
  - String types: `string`, `ci_string`, `atom`
  - Numeric types: `integer`, `float`, `decimal`
  - Boolean type
  - Date/time types: `date`, `time`, `datetime`, `utc_datetime`, `utc_datetime_usec`, `naive_datetime`
  - Other types: `uuid`, `binary`, `map`, `term`
  - Array types with nested type support
- Constraint support: `min`, `max`, `min_length`, `max_length`, `match`, `one_of`
- Plug controller for serving specs from Phoenix applications
- Mix task for CLI spec generation (`mix ash_oaskit.generate`)
- Igniter installation task (`mix igniter.install ash_oaskit`)
- JSON and YAML output formats
- Configurable API metadata (title, version, description, servers, contact, license)

## [0.1.0] - 2026-01-25

### Added

- Initial release

[Unreleased]: https://github.com/futhr/ash_oaskit/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/futhr/ash_oaskit/releases/tag/v0.1.0
