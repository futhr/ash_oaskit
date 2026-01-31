defmodule AshOaskit.SpecBuilder.Default do
  @moduledoc """
  Default `AshOaskit.SpecBuilder` implementation.

  This module is the out-of-the-box spec builder used by `AshOaskit.Router`
  when no custom `:spec_builder` option is provided. It delegates directly
  to `AshOaskit.spec/1` and applies no post-processing, making it the
  zero-configuration path for serving OpenAPI specifications.

  ## Behaviour Contract

  Implements the single callback defined by `AshOaskit.SpecBuilder`:

      @callback spec(openapi_version :: String.t(), opts :: map()) :: map()

  The `opts` map is forwarded from the Router macro and may contain:

  | Key              | Type            | Default   | Description                        |
  |------------------|-----------------|-----------|------------------------------------|
  | `:domains`       | `[module()]`    | `[]`      | Ash domains to introspect          |
  | `:title`         | `String.t()`   | `"API"`   | Value for `info.title`             |
  | `:version`       | `String.t()`   | `"1.0.0"` | Value for `info.version`           |
  | `:description`   | `String.t()`   | `nil`     | Value for `info.description`       |
  | `:servers`       | `[map()]`      | `[]`      | Server objects for `servers` array |

  ## When to Replace

  Switch to a custom `SpecBuilder` when you need to:

  - Inject security schemes (`bearerAuth`, OAuth2, API keys)
  - Add vendor extensions (`x-*` fields)
  - Filter or rewrite paths based on environment or feature flags
  - Merge specs from multiple sources

  See `AshOaskit.SpecBuilder` for the behaviour documentation and examples.
  """

  @behaviour AshOaskit.SpecBuilder

  @impl true
  def spec(openapi_version, opts) do
    AshOaskit.spec(
      domains: opts[:domains] || [],
      version: openapi_version,
      title: opts[:title] || "API",
      api_version: opts[:version] || "1.0.0",
      description: opts[:description],
      servers: opts[:servers] || []
    )
  end
end
