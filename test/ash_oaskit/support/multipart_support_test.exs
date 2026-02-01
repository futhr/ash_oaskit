defmodule AshOaskit.MultipartSupportTest do
  @moduledoc """
  Comprehensive tests for the AshOaskit.MultipartSupport module.

  This test module verifies that file upload and multipart/form-data
  request schemas are generated correctly, including:

  - File upload detection in action arguments
  - Multipart schema generation
  - Mixed file and non-file argument handling
  - Encoding specification generation
  - Array of files support

  ## Test Categories

  - **File Detection** - Tests for identifying file type arguments
  - **Schema Generation** - Tests for multipart schema structure
  - **Request Body** - Tests for complete request body with multipart
  - **Encoding** - Tests for encoding specifications
  - **Edge Cases** - Tests for unusual scenarios
  """

  use ExUnit.Case, async: true

  alias AshOaskit.MultipartSupport

  # Mock action helpers for testing
  defp mock_action_with_file do
    %{
      name: :upload_avatar,
      type: :create,
      arguments: [
        %{
          name: :avatar,
          type: Ash.Type.File,
          allow_nil?: false,
          description: "User avatar image"
        },
        %{
          name: :caption,
          type: :string,
          allow_nil?: true
        }
      ]
    }
  end

  defp mock_action_without_file do
    %{
      name: :create,
      type: :create,
      arguments: [
        %{
          name: :title,
          type: :string,
          allow_nil?: false
        },
        %{
          name: :body,
          type: :string,
          allow_nil?: true
        }
      ]
    }
  end

  defp mock_action_with_multiple_files do
    %{
      name: :upload_documents,
      type: :create,
      arguments: [
        %{
          name: :primary_document,
          type: Ash.Type.File,
          allow_nil?: false,
          description: "Primary document"
        },
        %{
          name: :supporting_documents,
          type: {:array, Ash.Type.File},
          allow_nil?: true,
          description: "Additional supporting documents"
        },
        %{
          name: :metadata,
          type: :map,
          allow_nil?: true
        }
      ]
    }
  end

  defp mock_action_no_arguments do
    %{
      name: :destroy,
      type: :destroy,
      arguments: []
    }
  end

  describe "has_file_upload?/1" do
    # Tests for file upload detection

    test "returns true for action with file argument" do
      assert MultipartSupport.has_file_upload?(mock_action_with_file())
    end

    test "returns false for action without file argument" do
      refute MultipartSupport.has_file_upload?(mock_action_without_file())
    end

    test "returns true for action with multiple file arguments" do
      assert MultipartSupport.has_file_upload?(mock_action_with_multiple_files())
    end

    test "returns false for action with no arguments" do
      refute MultipartSupport.has_file_upload?(mock_action_no_arguments())
    end

    test "detects :file atom type" do
      action = %{arguments: [%{name: :file, type: :file}]}
      assert MultipartSupport.has_file_upload?(action)
    end

    test "detects array of files" do
      action = %{arguments: [%{name: :files, type: {:array, Ash.Type.File}}]}
      assert MultipartSupport.has_file_upload?(action)
    end

    test "handles missing arguments key" do
      action = %{name: :test}
      refute MultipartSupport.has_file_upload?(action)
    end
  end

  describe "file_arguments/1" do
    # Tests for extracting file arguments

    test "returns file arguments only" do
      args = MultipartSupport.file_arguments(mock_action_with_file())

      assert length(args) == 1
      assert hd(args).name == :avatar
    end

    test "returns empty list for action without files" do
      args = MultipartSupport.file_arguments(mock_action_without_file())

      assert args == []
    end

    test "returns multiple file arguments" do
      args = MultipartSupport.file_arguments(mock_action_with_multiple_files())

      assert length(args) == 2
      names = Enum.map(args, & &1.name)
      assert :primary_document in names
      assert :supporting_documents in names
    end

    test "handles action with no arguments" do
      args = MultipartSupport.file_arguments(mock_action_no_arguments())

      assert args == []
    end
  end

  describe "build_multipart_schema/2" do
    # Tests for multipart schema generation

    test "generates object type schema" do
      schema = MultipartSupport.build_multipart_schema(mock_action_with_file(), [])

      assert schema[:type] == :object
    end

    test "includes file properties with binary format" do
      schema = MultipartSupport.build_multipart_schema(mock_action_with_file(), [])

      assert Map.has_key?(schema[:properties], :avatar)
      assert schema[:properties][:avatar][:type] == :string
      assert schema[:properties][:avatar][:format] == :binary
    end

    test "includes data property for JSON payload" do
      schema = MultipartSupport.build_multipart_schema(mock_action_with_file(), [])

      assert Map.has_key?(schema[:properties], :data)
    end

    test "includes required fields for non-nullable file arguments" do
      schema = MultipartSupport.build_multipart_schema(mock_action_with_file(), [])

      assert Map.has_key?(schema, :required)
      assert "avatar" in schema[:required]
    end

    test "omits required when all file arguments are nullable" do
      action = %{
        arguments: [
          %{name: :optional_file, type: Ash.Type.File, allow_nil?: true}
        ]
      }

      schema = MultipartSupport.build_multipart_schema(action, [])

      refute Map.has_key?(schema, :required)
    end

    test "includes description for file properties" do
      schema = MultipartSupport.build_multipart_schema(mock_action_with_file(), [])

      assert schema[:properties][:avatar][:description] == "User avatar image"
    end

    test "generates default description when not provided" do
      action = %{
        arguments: [
          %{name: :document, type: Ash.Type.File, allow_nil?: true}
        ]
      }

      schema = MultipartSupport.build_multipart_schema(action, [])

      assert schema[:properties][:document][:description] =~ "document"
    end
  end

  describe "build_multipart_schema/2 with array of files" do
    # Tests for array of files handling

    test "generates array type for array of files" do
      schema = MultipartSupport.build_multipart_schema(mock_action_with_multiple_files(), [])

      supporting = schema[:properties][:supporting_documents]
      assert supporting[:type] == :array
      assert supporting[:items][:type] == :string
      assert supporting[:items][:format] == :binary
    end

    test "single file remains as string type" do
      schema = MultipartSupport.build_multipart_schema(mock_action_with_multiple_files(), [])

      primary = schema[:properties][:primary_document]
      assert primary[:type] == :string
      assert primary[:format] == :binary
    end
  end

  describe "build_request_body/3" do
    # Tests for complete request body generation

    test "includes both JSON:API and multipart content types" do
      request_body =
        MultipartSupport.build_request_body(
          mock_action_with_file(),
          AshOaskit.Test.Post,
          []
        )

      assert Map.has_key?(request_body[:content], "application/vnd.api+json")
      assert Map.has_key?(request_body[:content], "multipart/form-data")
    end

    test "marks request body as required" do
      request_body =
        MultipartSupport.build_request_body(
          mock_action_with_file(),
          AshOaskit.Test.Post,
          []
        )

      assert request_body[:required] == true
    end

    test "JSON:API content references schema" do
      request_body =
        MultipartSupport.build_request_body(
          mock_action_with_file(),
          AshOaskit.Test.Post,
          []
        )

      json_content = request_body[:content]["application/vnd.api+json"]
      assert Map.has_key?(json_content, :schema)
    end

    test "multipart content has schema" do
      request_body =
        MultipartSupport.build_request_body(
          mock_action_with_file(),
          AshOaskit.Test.Post,
          []
        )

      multipart_content = request_body[:content]["multipart/form-data"]
      assert Map.has_key?(multipart_content, :schema)
    end

    test "omits multipart content type for non-file actions" do
      request_body =
        MultipartSupport.build_request_body(
          mock_action_without_file(),
          AshOaskit.Test.Post,
          []
        )

      assert Map.has_key?(request_body[:content], "application/vnd.api+json")
      refute Map.has_key?(request_body[:content], "multipart/form-data")
    end
  end

  describe "build_encoding/1" do
    # Tests for encoding specification generation

    test "generates encoding for file arguments" do
      encoding = MultipartSupport.build_encoding(mock_action_with_file())

      assert Map.has_key?(encoding, "avatar")
      assert encoding["avatar"][:contentType] == "application/octet-stream"
    end

    test "includes encoding for data field" do
      encoding = MultipartSupport.build_encoding(mock_action_with_file())

      assert Map.has_key?(encoding, "data")
      assert encoding["data"][:contentType] == "application/json"
    end

    test "generates encoding for multiple file arguments" do
      encoding = MultipartSupport.build_encoding(mock_action_with_multiple_files())

      assert Map.has_key?(encoding, "primary_document")
      assert Map.has_key?(encoding, "supporting_documents")
      assert Map.has_key?(encoding, "data")
    end

    test "handles action with no file arguments" do
      encoding = MultipartSupport.build_encoding(mock_action_without_file())

      assert Map.has_key?(encoding, "data")
    end
  end

  describe "build_multipart_content/2" do
    # Tests for complete multipart content specification

    test "includes both schema and encoding" do
      content = MultipartSupport.build_multipart_content(mock_action_with_file(), [])

      assert Map.has_key?(content, :schema)
      assert Map.has_key?(content, :encoding)
    end

    test "schema is valid object type" do
      content = MultipartSupport.build_multipart_content(mock_action_with_file(), [])

      assert content[:schema][:type] == :object
    end

    test "encoding matches schema properties" do
      content = MultipartSupport.build_multipart_content(mock_action_with_file(), [])

      schema_props = content[:schema][:properties] |> Map.keys() |> Enum.map(&to_string/1)
      encoding_keys = Map.keys(content[:encoding])

      # All encoded fields should be in schema
      Enum.each(encoding_keys, fn key ->
        assert key in schema_props or key == "data"
      end)
    end
  end

  describe "edge cases" do
    # Tests for edge cases and unusual scenarios

    test "handles action with only file arguments" do
      action = %{
        arguments: [
          %{name: :file1, type: Ash.Type.File, allow_nil?: false},
          %{name: :file2, type: Ash.Type.File, allow_nil?: false}
        ]
      }

      schema = MultipartSupport.build_multipart_schema(action, [])

      assert Map.has_key?(schema[:properties], :file1)
      assert Map.has_key?(schema[:properties], :file2)
      assert "file1" in schema[:required]
      assert "file2" in schema[:required]
    end

    test "handles empty arguments list" do
      action = %{arguments: []}

      schema = MultipartSupport.build_multipart_schema(action, [])

      assert schema[:type] == :object
      assert Map.has_key?(schema[:properties], :data)
    end

    test "handles nil arguments" do
      action = %{}

      assert MultipartSupport.has_file_upload?(action) == false
      assert MultipartSupport.file_arguments(action) == []
    end

    test "schema properties are valid atoms" do
      schema = MultipartSupport.build_multipart_schema(mock_action_with_file(), [])

      Enum.each(Map.keys(schema[:properties]), fn key ->
        assert is_atom(key), "Property key should be atom: #{inspect(key)}"
      end)
    end
  end
end
