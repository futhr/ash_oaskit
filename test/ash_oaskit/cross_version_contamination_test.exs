defmodule AshOaskit.CrossVersionContaminationTest do
  @moduledoc """
  Tests that OpenAPI 3.0 output never contains 3.1-only features and vice versa.

  These tests walk the full generated spec recursively to ensure no version-specific
  features leak across version boundaries. This catches bugs where version-aware code
  paths produce output for the wrong version.

  ## What's Tested

  - **3.0 output**: No type arrays, no JSON Schema 2020-12 features
  - **3.1 output**: No `nullable` keyword anywhere
  - Both tested against SimpleDomain and Blog domains
  """

  use ExUnit.Case, async: true

  @domains_simple [AshOaskit.Test.SimpleDomain]
  @domains_blog [AshOaskit.Test.Blog]

  describe "3.0 output must not contain 3.1 features" do
    test "no type arrays in SimpleDomain spec" do
      spec = AshOaskit.spec_30(domains: @domains_simple)
      assert_no_type_arrays(spec)
    end

    test "no type arrays in Blog spec" do
      spec = AshOaskit.spec_30(domains: @domains_blog)
      assert_no_type_arrays(spec)
    end

    test "no type arrays in multi-domain spec" do
      spec = AshOaskit.spec_30(domains: @domains_simple ++ @domains_blog)
      assert_no_type_arrays(spec)
    end

    test "version string is 3.0.3" do
      spec = AshOaskit.spec_30(domains: @domains_simple)
      assert spec["openapi"] == "3.0.3"
    end
  end

  describe "3.1 output must not contain 3.0 features" do
    test "no nullable keyword in SimpleDomain spec" do
      spec = AshOaskit.spec_31(domains: @domains_simple)
      assert_no_nullable_keyword(spec)
    end

    test "no nullable keyword in Blog spec" do
      spec = AshOaskit.spec_31(domains: @domains_blog)
      assert_no_nullable_keyword(spec)
    end

    test "no nullable keyword in multi-domain spec" do
      spec = AshOaskit.spec_31(domains: @domains_simple ++ @domains_blog)
      assert_no_nullable_keyword(spec)
    end

    test "version string is 3.1.0" do
      spec = AshOaskit.spec_31(domains: @domains_simple)
      assert spec["openapi"] == "3.1.0"
    end
  end

  # Recursively walk the spec and assert no "type" value is a list
  defp assert_no_type_arrays(data, path \\ [])

  defp assert_no_type_arrays(data, path) when is_map(data) do
    if Map.has_key?(data, "type") do
      refute is_list(data["type"]),
             "3.0 spec contains type array at #{format_path(path)}: #{inspect(data["type"])}"
    end

    Enum.each(data, fn {key, value} ->
      assert_no_type_arrays(value, path ++ [key])
    end)
  end

  defp assert_no_type_arrays(data, path) when is_list(data) do
    data
    |> Enum.with_index()
    |> Enum.each(fn {item, idx} ->
      assert_no_type_arrays(item, path ++ ["[#{idx}]"])
    end)
  end

  defp assert_no_type_arrays(_, _), do: :ok

  # Recursively walk the spec and assert no "nullable" key exists
  defp assert_no_nullable_keyword(data, path \\ [])

  defp assert_no_nullable_keyword(data, path) when is_map(data) do
    refute Map.has_key?(data, "nullable"),
           "3.1 spec contains \"nullable\" key at #{format_path(path)}: #{inspect(data)}"

    Enum.each(data, fn {key, value} ->
      assert_no_nullable_keyword(value, path ++ [key])
    end)
  end

  defp assert_no_nullable_keyword(data, path) when is_list(data) do
    data
    |> Enum.with_index()
    |> Enum.each(fn {item, idx} ->
      assert_no_nullable_keyword(item, path ++ ["[#{idx}]"])
    end)
  end

  defp assert_no_nullable_keyword(_, _), do: :ok

  defp format_path([]), do: "root"
  defp format_path(path), do: Enum.join(path, ".")
end
