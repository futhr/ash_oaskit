import Config

# Configuration for AshOaskit
# This is a library, so most configuration is done at runtime via options

config :ash_oaskit,
  # Default OpenAPI version ("3.0" or "3.1")
  version: "3.1",
  # Default API title
  title: "API",
  # Default API version
  api_version: "1.0.0"

# Configure logger for minimal output
config :logger,
  level: :warning,
  format: "[$level] $message\n"

# Git Ops - automated changelog and version management
config :git_ops,
  mix_project: Mix.Project.get!(),
  changelog_file: "CHANGELOG.md",
  repository_url: "https://github.com/futhr/ash_oaskit",
  version_tag_prefix: "v",
  manage_mix_version?: true,
  manage_readme_version: "README.md"

# Import environment specific config
if File.exists?("config/#{config_env()}.exs") do
  import_config "#{config_env()}.exs"
end
