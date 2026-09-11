# Used by "mix format"
[
  inputs: [
    "{mix,.formatter}.exs",
    "{bench,config,lib,scripts,test}/**/*.{ex,exs}",
    "notebooks/**/*.livemd"
  ],
  plugins: [Spark.Formatter, DoctestFormatter],
  import_deps: [:ash, :ash_json_api, :spark]
]
