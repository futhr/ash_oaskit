defmodule Mix.Tasks.AshOaskit.GenerateTest do
  @moduledoc """
  Tests for the `mix ash_oaskit.generate` task.

  This mix task is the primary CLI interface for generating OpenAPI specifications
  from Ash domains. It supports multiple output formats, OpenAPI versions, and
  various customization options.

  ## What We Test

  - **Version selection** - Generates OpenAPI 3.0 or 3.1 specs via `--version`
  - **Output formats** - JSON (default) and YAML via `--format`
  - **File output** - Custom paths via `--output`, default naming based on version
  - **API metadata** - Custom title and version via `--title` and `--api-version`
  - **Domain parsing** - Single domain, comma-separated list, multiple `--domains`
  - **Formatting** - Pretty-printed (default) or compact via `--no-pretty`
  - **CLI aliases** - Short flags (`-d`, `-v`, `-o`) for common options

  ## How We Test

  Tests run the mix task with various argument combinations, capturing IO output.
  We use `@moduletag :tmp_dir` for isolated file system operations. Generated
  specs are parsed and validated for correct structure and option handling.

  ## Why These Tests Matter

  The generate task is how users integrate AshOaskit into their build process.
  Incorrect argument parsing, file output, or format handling breaks CI pipelines
  and developer workflows. These tests ensure reliable spec generation across
  all supported options and edge cases.
  """

  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias Mix.Tasks.AshOaskit.Generate

  @moduletag :tmp_dir

  describe "run/1" do
    test "generates OpenAPI 3.1 spec by default", %{tmp_dir: tmp_dir} do
      output_file = Path.join(tmp_dir, "openapi.json")

      capture_io(fn ->
        Generate.run([
          "--domains",
          "AshOaskit.Test.SimpleDomain",
          "--output",
          output_file
        ])
      end)

      assert File.exists?(output_file)
      content = File.read!(output_file)
      spec = Jason.decode!(content)
      assert spec["openapi"] == "3.1.0"
    end

    test "generates OpenAPI 3.0 spec with --version 3.0", %{tmp_dir: tmp_dir} do
      output_file = Path.join(tmp_dir, "openapi-3.0.json")

      capture_io(fn ->
        Generate.run([
          "--domains",
          "AshOaskit.Test.SimpleDomain",
          "--version",
          "3.0",
          "--output",
          output_file
        ])
      end)

      assert File.exists?(output_file)
      content = File.read!(output_file)
      spec = Jason.decode!(content)
      assert spec["openapi"] == "3.0.3"
    end

    test "writes to specified output file", %{tmp_dir: tmp_dir} do
      output_file = Path.join(tmp_dir, "custom-spec.json")

      capture_io(fn ->
        Generate.run([
          "--domains",
          "AshOaskit.Test.SimpleDomain",
          "--output",
          output_file
        ])
      end)

      assert File.exists?(output_file)
    end

    test "uses default filename based on version", %{tmp_dir: tmp_dir} do
      # Change to tmp_dir for default file output
      File.cd!(tmp_dir, fn ->
        capture_io(fn ->
          Generate.run([
            "--domains",
            "AshOaskit.Test.SimpleDomain"
          ])
        end)

        # Default is 3.1, so filename should be openapi-3.1.json
        assert File.exists?("openapi-3.1.json")
      end)
    end

    test "raises when no domains specified" do
      assert_raise Mix.Error, ~r/No domains specified/, fn ->
        capture_io(fn ->
          Generate.run([])
        end)
      end
    end

    test "parses comma-separated domain list", %{tmp_dir: tmp_dir} do
      output_file = Path.join(tmp_dir, "openapi.json")

      capture_io(fn ->
        Generate.run([
          "--domains",
          "AshOaskit.Test.SimpleDomain,AshOaskit.Test.Blog",
          "--output",
          output_file
        ])
      end)

      assert File.exists?(output_file)
      content = File.read!(output_file)
      spec = Jason.decode!(content)

      # Should have schemas from both domains
      assert is_map(spec["components"]["schemas"])
    end

    test "supports --title option", %{tmp_dir: tmp_dir} do
      output_file = Path.join(tmp_dir, "openapi.json")

      capture_io(fn ->
        Generate.run([
          "--domains",
          "AshOaskit.Test.SimpleDomain",
          "--title",
          "My Custom API",
          "--output",
          output_file
        ])
      end)

      content = File.read!(output_file)
      spec = Jason.decode!(content)
      assert spec["info"]["title"] == "My Custom API"
    end

    test "supports --api-version option", %{tmp_dir: tmp_dir} do
      output_file = Path.join(tmp_dir, "openapi.json")

      capture_io(fn ->
        Generate.run([
          "--domains",
          "AshOaskit.Test.SimpleDomain",
          "--api-version",
          "2.0.0",
          "--output",
          output_file
        ])
      end)

      content = File.read!(output_file)
      spec = Jason.decode!(content)
      assert spec["info"]["version"] == "2.0.0"
    end

    test "supports --no-pretty for compact output", %{tmp_dir: tmp_dir} do
      output_file = Path.join(tmp_dir, "openapi.json")

      capture_io(fn ->
        Generate.run([
          "--domains",
          "AshOaskit.Test.SimpleDomain",
          "--no-pretty",
          "--output",
          output_file
        ])
      end)

      content = File.read!(output_file)
      # Compact JSON has no newlines (except possibly at the end)
      lines = String.split(content, "\n", trim: true)
      assert length(lines) == 1
    end

    test "pretty-prints by default", %{tmp_dir: tmp_dir} do
      output_file = Path.join(tmp_dir, "openapi.json")

      capture_io(fn ->
        Generate.run([
          "--domains",
          "AshOaskit.Test.SimpleDomain",
          "--output",
          output_file
        ])
      end)

      content = File.read!(output_file)
      # Pretty-printed JSON has multiple lines
      lines = String.split(content, "\n", trim: true)
      assert length(lines) > 1
    end

    test "prints info messages", %{tmp_dir: tmp_dir} do
      output_file = Path.join(tmp_dir, "openapi.json")

      output =
        capture_io(fn ->
          Generate.run([
            "--domains",
            "AshOaskit.Test.SimpleDomain",
            "--output",
            output_file
          ])
        end)

      assert output =~ "Generating OpenAPI"
      assert output =~ "Generated"
    end
  end

  describe "JSON format" do
    test "generates valid JSON", %{tmp_dir: tmp_dir} do
      output_file = Path.join(tmp_dir, "openapi.json")

      capture_io(fn ->
        Generate.run([
          "--domains",
          "AshOaskit.Test.SimpleDomain",
          "--format",
          "json",
          "--output",
          output_file
        ])
      end)

      content = File.read!(output_file)
      assert {:ok, _} = Jason.decode(content)
    end
  end

  describe "YAML format" do
    test "generates YAML when --format yaml", %{tmp_dir: tmp_dir} do
      output_file = Path.join(tmp_dir, "openapi.yaml")

      capture_io(fn ->
        Generate.run([
          "--domains",
          "AshOaskit.Test.SimpleDomain",
          "--format",
          "yaml",
          "--output",
          output_file
        ])
      end)

      assert File.exists?(output_file)
      content = File.read!(output_file)

      # YAML should start with --- or have YAML-like structure
      assert String.contains?(content, "openapi:")
    end

    test "YAML output contains valid spec structure", %{tmp_dir: tmp_dir} do
      output_file = Path.join(tmp_dir, "openapi-yaml-structure.yaml")

      output =
        capture_io(fn ->
          Generate.run([
            "-d",
            "AshOaskit.Test.SimpleDomain",
            "-f",
            "yaml",
            "-o",
            output_file
          ])
        end)

      assert output =~ "Generating OpenAPI"
      assert output =~ "Generated"
      assert File.exists?(output_file)

      content = File.read!(output_file)
      assert content =~ "openapi:"
      assert content =~ "info:"
      assert content =~ "paths:"
    end

    test "YAML output with version 3.0", %{tmp_dir: tmp_dir} do
      output_file = Path.join(tmp_dir, "openapi-3.0.yaml")

      capture_io(fn ->
        Generate.run([
          "--domains",
          "AshOaskit.Test.SimpleDomain",
          "--format",
          "yaml",
          "--version",
          "3.0",
          "--output",
          output_file
        ])
      end)

      assert File.exists?(output_file)
      content = File.read!(output_file)
      assert content =~ "openapi:"
    end
  end

  describe "unsupported format" do
    test "raises for unsupported format", %{tmp_dir: tmp_dir} do
      output_file = Path.join(tmp_dir, "openapi.xml")

      assert_raise Mix.Error, ~r/Unknown format/, fn ->
        capture_io(fn ->
          Generate.run([
            "--domains",
            "AshOaskit.Test.SimpleDomain",
            "--format",
            "xml",
            "--output",
            output_file
          ])
        end)
      end
    end
  end

  describe "alias support" do
    test "supports -d alias for --domains", %{tmp_dir: tmp_dir} do
      output_file = Path.join(tmp_dir, "openapi.json")

      capture_io(fn ->
        Generate.run([
          "-d",
          "AshOaskit.Test.SimpleDomain",
          "--output",
          output_file
        ])
      end)

      assert File.exists?(output_file)
    end

    test "supports -v alias for --version", %{tmp_dir: tmp_dir} do
      output_file = Path.join(tmp_dir, "openapi.json")

      capture_io(fn ->
        Generate.run([
          "-d",
          "AshOaskit.Test.SimpleDomain",
          "-v",
          "3.0",
          "--output",
          output_file
        ])
      end)

      content = File.read!(output_file)
      spec = Jason.decode!(content)
      assert spec["openapi"] == "3.0.3"
    end

    test "supports -o alias for --output", %{tmp_dir: tmp_dir} do
      output_file = Path.join(tmp_dir, "spec.json")

      capture_io(fn ->
        Generate.run([
          "-d",
          "AshOaskit.Test.SimpleDomain",
          "-o",
          output_file
        ])
      end)

      assert File.exists?(output_file)
    end
  end
end
