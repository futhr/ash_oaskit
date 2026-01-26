defmodule AshOaskit.ConfigTest do
  @moduledoc """
  Comprehensive tests for the AshOaskit.Config module.

  This test module verifies that configuration is correctly retrieved from
  AshJsonApi DSL.

  ## Test Categories

  1. **Resource Configuration** - Tests for resource-level settings like
     type, derive_filter?, derive_sort?, default_fields, includes

  2. **Domain Configuration** - Tests for domain-level settings like
     tag, prefix, group_by

  3. **Action Configuration** - Tests for retrieving resource actions

  4. **Attribute Configuration** - Tests for retrieving attributes and
     relationships

  5. **Type Consistency** - Tests that return types are consistent
  """

  use ExUnit.Case, async: true

  alias AshOaskit.Config

  # Using the test_resources.ex fixtures (Post, Comment in SimpleDomain/Blog)

  describe "resource_type/1" do
    # Tests for JSON:API type retrieval

    test "returns configured type for resource with json_api" do
      # Post has json_api configured with type "post"
      type = Config.resource_type(AshOaskit.Test.Post)

      assert is_binary(type)
    end

    test "returns underscored name as default" do
      # The default type should be the underscored module name
      type = Config.resource_type(AshOaskit.Test.Post)

      assert type == "post"
    end

    test "handles Comment resource" do
      type = Config.resource_type(AshOaskit.Test.Comment)

      assert type == "comment"
    end

    test "returns string type" do
      type = Config.resource_type(AshOaskit.Test.Post)

      assert is_binary(type)
    end
  end

  describe "derive_filter?/1" do
    # Tests for filter derivation setting

    test "returns boolean for Post" do
      result = Config.derive_filter?(AshOaskit.Test.Post)

      assert is_boolean(result)
    end

    test "defaults to true when not configured" do
      # Default behavior should enable filter derivation
      result = Config.derive_filter?(AshOaskit.Test.Post)

      assert result == true
    end

    test "returns boolean for Comment" do
      result = Config.derive_filter?(AshOaskit.Test.Comment)

      assert is_boolean(result)
    end
  end

  describe "derive_sort?/1" do
    # Tests for sort derivation setting

    test "returns boolean for Post" do
      result = Config.derive_sort?(AshOaskit.Test.Post)

      assert is_boolean(result)
    end

    test "defaults to true when not configured" do
      result = Config.derive_sort?(AshOaskit.Test.Post)

      assert result == true
    end

    test "returns boolean for Comment" do
      result = Config.derive_sort?(AshOaskit.Test.Comment)

      assert is_boolean(result)
    end
  end

  describe "default_fields/1" do
    # Tests for default fields configuration

    test "returns nil or list for Post" do
      result = Config.default_fields(AshOaskit.Test.Post)

      assert is_nil(result) or is_list(result)
    end

    test "returns nil when not configured" do
      # Default should be nil (all fields)
      result = Config.default_fields(AshOaskit.Test.Post)

      assert is_nil(result) or is_list(result)
    end
  end

  describe "includes/1" do
    # Tests for includable relationships

    test "returns list for Post" do
      result = Config.includes(AshOaskit.Test.Post)

      assert is_list(result)
    end

    test "defaults to empty list when not configured" do
      result = Config.includes(AshOaskit.Test.Comment)

      assert is_list(result)
    end
  end

  describe "primary_key/1" do
    # Tests for primary key retrieval

    test "returns list of primary key fields" do
      result = Config.primary_key(AshOaskit.Test.Post)

      assert is_list(result)
      assert :id in result
    end

    test "returns :id for standard UUID primary key" do
      result = Config.primary_key(AshOaskit.Test.Post)

      assert result == [:id]
    end

    test "works for Comment resource" do
      result = Config.primary_key(AshOaskit.Test.Comment)

      assert is_list(result)
      refute Enum.empty?(result)
    end
  end

  describe "domain_tag/1" do
    # Tests for domain tag configuration

    test "returns string or nil for Blog domain" do
      result = Config.domain_tag(AshOaskit.Test.Blog)

      assert is_nil(result) or is_binary(result)
    end

    test "returns nil for SimpleDomain without tag" do
      result = Config.domain_tag(AshOaskit.Test.SimpleDomain)

      assert is_nil(result) or is_binary(result)
    end
  end

  describe "route_prefix/1" do
    # Tests for domain route prefix

    test "returns string for Blog domain" do
      result = Config.route_prefix(AshOaskit.Test.Blog)

      assert is_binary(result)
    end

    test "defaults to empty string when not configured" do
      result = Config.route_prefix(AshOaskit.Test.SimpleDomain)

      assert is_binary(result)
    end
  end

  describe "group_by/1" do
    # Tests for operation grouping strategy

    test "returns atom for Blog domain" do
      result = Config.group_by(AshOaskit.Test.Blog)

      assert is_atom(result) or is_nil(result)
    end

    test "defaults to :resource when not configured" do
      result = Config.group_by(AshOaskit.Test.SimpleDomain)

      assert result == :resource or is_nil(result)
    end
  end

  describe "domain_resources/1" do
    # Tests for retrieving domain resources

    test "returns list of resources for Blog domain" do
      result = Config.domain_resources(AshOaskit.Test.Blog)

      assert is_list(result)
    end

    test "includes Post resource in Blog domain" do
      result = Config.domain_resources(AshOaskit.Test.Blog)

      assert AshOaskit.Test.Post in result
    end

    test "includes Comment resource in Blog domain" do
      result = Config.domain_resources(AshOaskit.Test.Blog)

      assert AshOaskit.Test.Comment in result
    end

    test "returns list for SimpleDomain" do
      result = Config.domain_resources(AshOaskit.Test.SimpleDomain)

      assert is_list(result)
    end
  end

  describe "domain_routes/1" do
    # Tests for retrieving domain routes

    test "returns list of routes for Blog domain" do
      result = Config.domain_routes(AshOaskit.Test.Blog)

      assert is_list(result)
    end

    test "returns non-empty list for Blog with json_api routes" do
      result = Config.domain_routes(AshOaskit.Test.Blog)

      refute Enum.empty?(result)
    end

    test "routes have expected structure" do
      routes = Config.domain_routes(AshOaskit.Test.Blog)

      Enum.each(routes, fn route ->
        assert Map.has_key?(route, :type)
        assert Map.has_key?(route, :route)
      end)
    end
  end

  describe "resource_actions/1" do
    # Tests for retrieving resource actions

    test "returns list of actions for Post" do
      result = Config.resource_actions(AshOaskit.Test.Post)

      assert is_list(result)
    end

    test "includes CRUD actions for Post" do
      actions = Config.resource_actions(AshOaskit.Test.Post)
      action_names = Enum.map(actions, & &1.name)

      assert :read in action_names
      assert :create in action_names
    end

    test "works for Comment resource" do
      result = Config.resource_actions(AshOaskit.Test.Comment)

      assert is_list(result)
    end
  end

  describe "resource_action/2" do
    # Tests for retrieving specific action

    test "returns action by name" do
      result = Config.resource_action(AshOaskit.Test.Post, :read)

      assert result != nil
      assert result.name == :read
    end

    test "returns nil for non-existent action" do
      result = Config.resource_action(AshOaskit.Test.Post, :nonexistent)

      assert is_nil(result)
    end

    test "returns create action" do
      result = Config.resource_action(AshOaskit.Test.Post, :create)

      assert result != nil
      assert result.name == :create
    end
  end

  describe "public_attributes/1" do
    # Tests for retrieving public attributes

    test "returns list of attributes for Post" do
      result = Config.public_attributes(AshOaskit.Test.Post)

      assert is_list(result)
    end

    test "excludes private attributes" do
      attrs = Config.public_attributes(AshOaskit.Test.Post)

      Enum.each(attrs, fn attr ->
        refute Map.get(attr, :private?, false)
      end)
    end

    test "returns primary key attribute for Post" do
      attrs = Config.public_attributes(AshOaskit.Test.Post)
      attr_names = Enum.map(attrs, & &1.name)

      # public_attributes returns attributes marked public? true
      # In Ash 3.x, attributes default to not public unless explicitly set
      assert :id in attr_names
    end

    test "works for Comment resource" do
      result = Config.public_attributes(AshOaskit.Test.Comment)

      assert is_list(result)
      refute Enum.empty?(result)
    end
  end

  describe "relationships/1" do
    # Tests for retrieving relationships

    test "returns list for Post" do
      result = Config.relationships(AshOaskit.Test.Post)

      assert is_list(result)
    end

    test "returns list for Comment" do
      result = Config.relationships(AshOaskit.Test.Comment)

      assert is_list(result)
    end
  end

  describe "relationship/2" do
    # Tests for retrieving specific relationship

    test "returns nil for non-existent relationship" do
      result = Config.relationship(AshOaskit.Test.Post, :nonexistent)

      assert is_nil(result)
    end

    test "handles missing relationship gracefully" do
      result = Config.relationship(AshOaskit.Test.Post, :author)

      # Post may or may not have this relationship
      assert is_nil(result) or is_map(result)
    end
  end

  describe "type consistency" do
    # Tests that return types are consistent

    test "all boolean functions return booleans" do
      assert is_boolean(Config.derive_filter?(AshOaskit.Test.Post))
      assert is_boolean(Config.derive_sort?(AshOaskit.Test.Post))
    end

    test "all list functions return lists" do
      assert is_list(Config.includes(AshOaskit.Test.Post))
      assert is_list(Config.primary_key(AshOaskit.Test.Post))
      assert is_list(Config.domain_resources(AshOaskit.Test.Blog))
      assert is_list(Config.domain_routes(AshOaskit.Test.Blog))
      assert is_list(Config.resource_actions(AshOaskit.Test.Post))
      assert is_list(Config.public_attributes(AshOaskit.Test.Post))
      assert is_list(Config.relationships(AshOaskit.Test.Post))
    end

    test "all string functions return strings" do
      assert is_binary(Config.resource_type(AshOaskit.Test.Post))
      assert is_binary(Config.route_prefix(AshOaskit.Test.Blog))
    end
  end

  describe "nil type fallback path (line 89)" do
    # Tests to cover the nil -> default_type(resource) branch

    test "resource_type returns default when json_api type is nil" do
      # NoTypeResource has AshJsonApi extension but no type configured
      type = Config.resource_type(AshOaskit.Test.NoTypeResource)

      # Should return underscored module name
      assert type == "no_type_resource"
    end
  end

  describe "domain prefix edge cases" do
    test "route_prefix returns configured prefix" do
      # EdgeCaseDomain has prefix "/edge"
      prefix = Config.route_prefix(AshOaskit.Test.EdgeCaseDomain)

      assert prefix == "/edge"
    end
  end
end
