import Config

# Ash 3.33 requires an explicit string-length policy. JSON Schema counts
# Unicode codepoints too; grapheme limits do not bound input size.
config :ash, default_string_length_count: :codepoints

# Dev/test configuration for AshOaskit itself. This file is NOT shipped
# to consumers — all library defaults live in code (see
# AshOaskit.OpenApi and AshOaskit.Generators.InfoBuilder). Consumers may
# override the same keys in their own config:
#
#     config :ash_oaskit,
#       version: "3.1",        # default OpenAPI version
#       title: "API",          # default info.title
#       api_version: "1.0.0",  # default info.version
#       cache_specs: false     # dev only: bypass spec module caching

config :ash_oaskit,
  version: "3.1",
  title: "API",
  api_version: "1.0.0"

# Configure logger for minimal output
config :logger,
  level: :warning,
  format: "[$level] $message\n"

# Import environment specific config
if File.exists?("config/#{config_env()}.exs") do
  import_config "#{config_env()}.exs"
end
