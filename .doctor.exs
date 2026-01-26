%Doctor.Config{
  ignore_modules: [
    # Test support modules only
    AshOaskit.Test.Post,
    AshOaskit.Test.Comment,
    AshOaskit.Test.Blog,
    AshOaskit.Test.SimpleDomain,
    AshOaskit.ConnCase
  ],
  ignore_paths: [
    ~r/test\/support/
  ],
  min_module_doc_coverage: 100,
  min_module_spec_coverage: 100,
  min_overall_doc_coverage: 100,
  min_overall_spec_coverage: 100,
  min_overall_moduledoc_coverage: 100,
  raise: true,
  reporter: Doctor.Reporters.Full,
  struct_type_spec_required: true,
  umbrella: false
}
