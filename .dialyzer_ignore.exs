[
  # Dialyzer false positive: Elixir module compilation generates pattern match
  # that Dialyzer incorrectly flags. This is a known issue with Dialyzer and
  # Elixir's defmodule macro expansion.
  {"lib/ash_oaskit/schema_builder.ex", :pattern_match}
]
