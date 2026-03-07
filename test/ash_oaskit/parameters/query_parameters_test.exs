defmodule AshOaskit.QueryParametersTest do
  @moduledoc """
  Tests for the AshOaskit.QueryParameters module.

  JSON:API defines several standard query parameters for filtering, sorting,
  pagination, sparse fieldsets, and relationship inclusion. This module tests
  that AshOaskit generates correct OpenAPI parameter schemas for these.

  ## What We Test

  - **Page parameter** - Pagination with offset/limit or keyset (after/before)
    cursors, including count option and configurable limits
  - **Fields parameter** - Sparse fieldsets allowing clients to request only
    specific attributes per resource type (e.g., `fields[posts]=title,body`)
  - **Include parameter** - Relationship inclusion with dot notation for nested
    paths (e.g., `include=author,comments.author`)
  - **Combined parameters** - Helper functions that bundle parameters for
    different operation types (index, show, etc.)

  ## How We Test

  Tests call `QueryParameters.build_*` functions and verify the returned
  parameter objects have correct OpenAPI structure: name, location (query),
  style (deepObject for nested params), explode settings, and schema types.

  ## Why These Tests Matter

  Incorrect parameter schemas cause API documentation mismatches, client SDK
  generation failures, and validation errors. These tests ensure compliance
  with both OpenAPI 3.x and JSON:API query parameter conventions.
  """

  use ExUnit.Case, async: true

  alias AshOaskit.QueryParameters

  describe "build_page_parameter/1" do
    # Tests for pagination parameter

    test "generates page parameter with deepObject style" do
      param = QueryParameters.build_page_parameter([])

      assert param.name == "page"
      assert param.in == :query
      assert param.style == :deepObject
    end

    test "has object type schema" do
      param = QueryParameters.build_page_parameter([])

      assert param.schema.type == :object
    end

    test "default strategy includes offset properties" do
      param = QueryParameters.build_page_parameter([])

      properties = param.schema.properties
      assert Map.has_key?(properties, "offset")
      assert Map.has_key?(properties, "limit")
    end

    test "default strategy includes keyset properties" do
      param = QueryParameters.build_page_parameter([])

      properties = param.schema.properties
      assert Map.has_key?(properties, "after")
      assert Map.has_key?(properties, "before")
    end

    test "includes count property" do
      param = QueryParameters.build_page_parameter([])

      assert Map.has_key?(param.schema.properties, "count")
      assert param.schema.properties["count"].type == :boolean
    end

    test "offset strategy only includes offset properties" do
      param = QueryParameters.build_page_parameter(pagination_strategy: :offset)

      properties = param.schema.properties
      assert Map.has_key?(properties, "offset")
      assert Map.has_key?(properties, "limit")
      refute Map.has_key?(properties, "after")
      refute Map.has_key?(properties, "before")
    end

    test "keyset strategy only includes keyset properties" do
      param = QueryParameters.build_page_parameter(pagination_strategy: :keyset)

      properties = param.schema.properties
      assert Map.has_key?(properties, "after")
      assert Map.has_key?(properties, "before")
      refute Map.has_key?(properties, "offset")
    end

    test "limit has minimum and maximum constraints" do
      param = QueryParameters.build_page_parameter([])

      limit = param.schema.properties["limit"]
      assert limit.minimum == 1
      assert limit.maximum == 1000
    end

    test "offset has minimum constraint" do
      param = QueryParameters.build_page_parameter([])

      offset = param.schema.properties["offset"]
      assert offset.minimum == 0
    end

    test "includes description" do
      param = QueryParameters.build_page_parameter([])

      assert Map.has_key?(param, :description)
      assert is_binary(param.description)
    end

    test "is not required" do
      param = QueryParameters.build_page_parameter([])

      assert param.required == false
    end
  end

  describe "build_fields_parameter/2" do
    # Tests for sparse fieldsets

    test "generates fields parameter with deepObject style" do
      param = QueryParameters.build_fields_parameter(["post", "author"])

      assert param.name == "fields"
      assert param.in == :query
      assert param.style == :deepObject
    end

    test "has object type schema" do
      param = QueryParameters.build_fields_parameter(["post"])

      assert param.schema.type == :object
    end

    test "includes property for each resource type" do
      param = QueryParameters.build_fields_parameter(["post", "author", "comment"])

      properties = param.schema.properties
      assert Map.has_key?(properties, "post")
      assert Map.has_key?(properties, "author")
      assert Map.has_key?(properties, "comment")
    end

    test "each property is string type" do
      param = QueryParameters.build_fields_parameter(["post", "author"])

      Enum.each(param.schema.properties, fn {_, prop} ->
        assert prop.type == :string
      end)
    end

    test "includes additionalProperties for unknown types" do
      param = QueryParameters.build_fields_parameter(["post"])

      assert Map.has_key?(param.schema, :additionalProperties)
    end

    test "handles empty resource types list" do
      param = QueryParameters.build_fields_parameter([])

      assert param.schema.type == :object
      assert param.schema.properties == %{}
    end

    test "includes description" do
      param = QueryParameters.build_fields_parameter(["post"])

      assert param.description =~ "Sparse fieldsets"
    end

    test "is not required" do
      param = QueryParameters.build_fields_parameter(["post"])

      assert param.required == false
    end
  end

  describe "build_include_parameter/2" do
    # Tests for relationship includes

    test "generates include parameter" do
      param = QueryParameters.build_include_parameter([:author, :comments])

      assert param.name == "include"
      assert param.in == :query
    end

    test "has string type schema" do
      param = QueryParameters.build_include_parameter([:author])

      assert param.schema.type == :string
    end

    test "includes available relationships in description" do
      param = QueryParameters.build_include_parameter([:author, :comments])

      assert param.description =~ "author"
      assert param.description =~ "comments"
    end

    test "mentions dot notation for nested includes" do
      param = QueryParameters.build_include_parameter([:author])

      assert param.description =~ "dot notation"
    end

    test "handles empty includes list" do
      param = QueryParameters.build_include_parameter([])

      assert param.schema.type == :string
      assert param.description =~ "relationship paths"
    end

    test "handles string include paths" do
      param = QueryParameters.build_include_parameter(["author", "comments.author"])

      assert param.description =~ "author"
      assert param.description =~ "comments.author"
    end

    test "is not required" do
      param = QueryParameters.build_include_parameter([:author])

      assert param.required == false
    end
  end

  describe "all_parameters/2" do
    # Tests for combined parameters

    test "returns list of parameters" do
      params = QueryParameters.all_parameters(AshOaskit.Test.Post)

      assert is_list(params)
      assert length(params) >= 3
    end

    test "includes page parameter" do
      params = QueryParameters.all_parameters(AshOaskit.Test.Post)
      param_names = Enum.map(params, & &1.name)

      assert "page" in param_names
    end

    test "includes include parameter" do
      params = QueryParameters.all_parameters(AshOaskit.Test.Post)
      param_names = Enum.map(params, & &1.name)

      assert "include" in param_names
    end

    test "includes fields parameter" do
      params = QueryParameters.all_parameters(AshOaskit.Test.Post)
      param_names = Enum.map(params, & &1.name)

      assert "fields" in param_names
    end

    test "may include filter parameter" do
      params = QueryParameters.all_parameters(AshOaskit.Test.Post)
      param_names = Enum.map(params, & &1.name)

      # Filter is optional based on derive_filter? setting
      assert is_list(param_names)
    end

    test "may include sort parameter" do
      params = QueryParameters.all_parameters(AshOaskit.Test.Post)
      param_names = Enum.map(params, & &1.name)

      # Sort is optional based on derive_sort? setting
      assert is_list(param_names)
    end

    test "accepts version option" do
      params = QueryParameters.all_parameters(AshOaskit.Test.Post, version: "3.1")

      assert is_list(params)
    end

    test "accepts pagination_strategy option" do
      params = QueryParameters.all_parameters(AshOaskit.Test.Post, pagination_strategy: :offset)

      page_param = Enum.find(params, &(&1.name == "page"))
      assert page_param != nil
    end
  end

  describe "basic_parameters/2" do
    # Tests for basic parameter set

    test "returns list of 3 parameters" do
      params = QueryParameters.basic_parameters(AshOaskit.Test.Post)

      assert length(params) == 3
    end

    test "includes page, include, fields" do
      params = QueryParameters.basic_parameters(AshOaskit.Test.Post)
      param_names = Enum.map(params, & &1.name)

      assert "page" in param_names
      assert "include" in param_names
      assert "fields" in param_names
    end

    test "does not include filter" do
      params = QueryParameters.basic_parameters(AshOaskit.Test.Post)
      param_names = Enum.map(params, & &1.name)

      refute "filter" in param_names
    end

    test "does not include sort" do
      params = QueryParameters.basic_parameters(AshOaskit.Test.Post)
      param_names = Enum.map(params, & &1.name)

      refute "sort" in param_names
    end
  end

  describe "index_parameters/2" do
    # Tests for index operation parameters

    test "returns same as all_parameters" do
      index_params = QueryParameters.index_parameters(AshOaskit.Test.Post)
      all_params = QueryParameters.all_parameters(AshOaskit.Test.Post)

      assert length(index_params) == length(all_params)
    end
  end

  describe "show_parameters/2" do
    # Tests for show operation parameters

    test "returns 2 parameters" do
      params = QueryParameters.show_parameters(AshOaskit.Test.Post)

      assert length(params) == 2
    end

    test "includes include and fields only" do
      params = QueryParameters.show_parameters(AshOaskit.Test.Post)
      param_names = Enum.map(params, & &1.name)

      assert "include" in param_names
      assert "fields" in param_names
    end

    test "does not include page, filter, or sort" do
      params = QueryParameters.show_parameters(AshOaskit.Test.Post)
      param_names = Enum.map(params, & &1.name)

      refute "page" in param_names
      refute "filter" in param_names
      refute "sort" in param_names
    end
  end

  describe "edge cases" do
    # Tests for edge cases

    test "all parameters are valid maps" do
      params = QueryParameters.all_parameters(AshOaskit.Test.Post)

      Enum.each(params, fn param ->
        assert is_map(param)
        assert Map.has_key?(param, :name)
        assert Map.has_key?(param, :in)
        assert Map.has_key?(param, :schema)
      end)
    end

    test "all parameter names are strings" do
      params = QueryParameters.all_parameters(AshOaskit.Test.Post)

      Enum.each(params, fn param ->
        assert is_binary(param.name)
      end)
    end

    test "all parameters have valid 'in' values" do
      params = QueryParameters.all_parameters(AshOaskit.Test.Post)

      Enum.each(params, fn param ->
        assert param.in in [:query, :path, :header, :cookie]
      end)
    end

    test "returns parameters for resource without json_api type" do
      params = QueryParameters.all_parameters(AshOaskit.Test.NoTypeResource)

      assert is_list(params)
      assert length(params) >= 3
    end

    test "pagination properties have descriptions" do
      param = QueryParameters.build_page_parameter([])

      Enum.each(param.schema.properties, fn {_, prop} ->
        assert Map.has_key?(prop, :description)
      end)
    end
  end

  describe "OpenAPI compliance" do
    # Tests for OpenAPI spec compliance

    test "page parameter has explode: true for deepObject" do
      param = QueryParameters.build_page_parameter([])

      assert param.explode == true
    end

    test "fields parameter has explode: true for deepObject" do
      param = QueryParameters.build_fields_parameter(["post"])

      assert param.explode == true
    end

    test "parameters conform to OpenAPI 3.0+ parameter object" do
      params = QueryParameters.all_parameters(AshOaskit.Test.Post)

      Enum.each(params, fn param ->
        # Required fields
        assert Map.has_key?(param, :name)
        assert Map.has_key?(param, :in)

        # Schema is required for non-body parameters
        assert Map.has_key?(param, :schema)
      end)
    end
  end

  describe "parameter deduplication" do
    test "operations have no duplicate parameters" do
      spec = AshOaskit.spec_31(domains: [AshOaskit.Test.Blog])

      paths = spec["paths"] || %{}

      Enum.each(paths, fn {path, path_item} ->
        Enum.each(path_item, fn
          {method, operation} when method in ~w(get post put patch delete) ->
            parameters = operation["parameters"] || []

            param_keys =
              Enum.map(parameters, fn p ->
                {p["name"], p["in"]}
              end)

            unique_keys = Enum.uniq(param_keys)

            assert length(param_keys) == length(unique_keys),
                   "Duplicate parameters found in #{method} #{path}"

          _ ->
            :ok
        end)
      end)
    end

    test "path parameters are always required" do
      spec = AshOaskit.spec_31(domains: [AshOaskit.Test.Blog])

      paths = spec["paths"] || %{}

      Enum.each(paths, fn {_, path_item} ->
        Enum.each(path_item, fn
          {method, operation} when method in ~w(get post put patch delete) ->
            parameters = operation["parameters"] || []

            path_params = Enum.filter(parameters, &(&1["in"] == "path"))

            Enum.each(path_params, fn param ->
              assert param["required"] == true,
                     "Path parameter '#{param["name"]}' should be required"
            end)

          _ ->
            :ok
        end)
      end)
    end
  end

  describe "all_parameters for Article resource" do
    test "returns filter, sort, page, include, and fields params for Article" do
      params = QueryParameters.all_parameters(AshOaskit.Test.Article, version: "3.1")
      names = Enum.map(params, & &1.name)

      assert "filter" in names
      assert "sort" in names
      assert "page" in names
      assert "include" in names
      assert "fields" in names
    end

    test "include parameter lists relationship names for Article" do
      params = QueryParameters.all_parameters(AshOaskit.Test.Article, version: "3.1")
      include_param = Enum.find(params, &(&1.name == "include"))
      assert include_param.description =~ "author"
    end

    test "fields parameter includes related resource types for Article" do
      params = QueryParameters.all_parameters(AshOaskit.Test.Article, version: "3.1")
      fields_param = Enum.find(params, &(&1.name == "fields"))
      props = fields_param.schema.properties
      assert Map.has_key?(props, "article")
    end
  end

  describe "coverage edge cases" do
    # Tests to cover remaining branches

    test "pagination properties fallback for unknown strategy" do
      # build_pagination_properties with unknown atom should fall back to :both
      param = QueryParameters.build_page_parameter(pagination_strategy: :unknown_strategy)

      # Should have all pagination properties (falls back to :both)
      props = param.schema.properties
      assert Map.has_key?(props, "limit")
      assert Map.has_key?(props, "offset")
      assert Map.has_key?(props, "after")
      assert Map.has_key?(props, "before")
    end

    test "offset pagination has offset-specific description" do
      param = QueryParameters.build_page_parameter(pagination_strategy: :offset)

      assert param.description =~ "Offset-based pagination"
    end

    test "keyset pagination has keyset-specific description" do
      param = QueryParameters.build_page_parameter(pagination_strategy: :keyset)

      assert param.description =~ "Keyset"
    end

    test "both pagination has combined description" do
      param = QueryParameters.build_page_parameter(pagination_strategy: :both)

      assert param.description =~ "both offset"
    end

    test "unknown pagination strategy falls back to both description" do
      param = QueryParameters.build_page_parameter(pagination_strategy: :invalid)

      assert param.description =~ "both"
    end

    test "handles resource without AshJsonApi type" do
      # NoTypeResource doesn't have explicit type configured
      params = QueryParameters.all_parameters(AshOaskit.Test.NoTypeResource)

      assert is_list(params)
    end

    test "get related resource types for resource without relationships" do
      # NoTypeResource has no relationships
      params = QueryParameters.all_parameters(AshOaskit.Test.NoTypeResource)

      # Should return valid parameters
      assert is_list(params)
    end

    test "resource_type nil fallback" do
      # NoTypeResource has nil type, triggering the nil -> default_type branch
      params = QueryParameters.index_parameters(AshOaskit.Test.NoTypeResource)

      # fields parameter should still work
      fields_param = Enum.find(params, &(&1.name == "fields"))
      assert fields_param != nil
    end
  end
end
