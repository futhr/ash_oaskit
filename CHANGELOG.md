# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2026-03-31

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

[Unreleased]: https://github.com/futhr/ash_oaskit/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/futhr/ash_oaskit/releases/tag/v0.1.0

<!-- changelog -->

## [v0.2.1](https://github.com/futhr/ash_oaskit/compare/v0.2.0...v0.2.1) (2026-06-10)




### Bug Fixes:

* document typed structs with their declared field types by HaimKortovich

## [v0.2.0](https://github.com/futhr/ash_oaskit/compare/v0.1.1...v0.2.0) (2026-06-10)
### Breaking Changes:

* only include public fields in generated specs by futhr

  The visibility filter checked a `:private?` field that does not exist on
  Ash 3.x structs, so specs exposed every attribute, calculation, aggregate,
  and relationship — including non-public ones. Specs now include only
  `public? true` fields, matching what AshJsonApi serializes. Mark fields
  `public? true` if your spec relied on the old behavior.

* derive request body schemas from the routed action by futhr

  POST/PATCH bodies now reference `{Resource}{Action}Input` schemas derived
  from the routed action's `accept` list and public arguments (previously
  they pointed at the response `Attributes` schema). PATCH bodies require
  `data.id`. Blanket `CreateInput`/`UpdateInput` schemas are no longer
  emitted for resources without body-bearing routes.

* include resource-level routes and domain prefix in paths by futhr

  Routes declared on the resource (`json_api do routes do ... end end`) now
  appear in specs, and the domain-wide `json_api` `prefix` is prepended to
  generated paths.



### Features:

* generate a spec module from the igniter installer by futhr

* serve spec modules and Redoc UI from AshOaskit.Router by futhr

* add spec modules via use AshOaskit by futhr

* enrich operation summaries and descriptions by futhr

* document JSON:API query parameters on related routes by futhr

* complete Ash built-in type mappings by futhr

### Bug Fixes:

* derive HTTP methods and operations from the route struct by futhr

* emit valid nullable $ref schemas for OpenAPI 3.0 by futhr

## [v0.1.1](https://github.com/futhr/ash_oaskit/compare/v0.1.0...v0.1.1) (2026-04-02)




### Bug Fixes:

* remove HTML div wrapper for hex.pm rendering by Tobias Bohwalli