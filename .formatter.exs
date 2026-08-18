# Used by "mix format"
[
  inputs: ["{mix,.formatter}.exs", "{config,lib,scripts,test}/**/*.{ex,exs}"],
  plugins: [Spark.Formatter, DoctestFormatter],
  import_deps: [:ash, :ash_json_api, :spark]
]
