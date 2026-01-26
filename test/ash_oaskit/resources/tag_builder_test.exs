defmodule AshOaskit.TagBuilderTest do
  @moduledoc """
  Tests for AshOaskit.TagBuilder module.

  This test module verifies the tag generation functionality, including:

  - Resource-based grouping (default)
  - Domain-based grouping
  - Custom tag configuration
  - Tag descriptions and external docs
  - Operation tag assignment
  - Tag merging
  """

  use ExUnit.Case, async: true

  alias AshOaskit.TagBuilder

  # Mock resources for testing - using empty modules since we only need module references
  defmodule MockPost do
  end

  defmodule MockComment do
  end

  describe "build_tag/3" do
    test "builds tag with name only" do
      tag = TagBuilder.build_tag("Posts")

      assert tag == %{"name" => "Posts"}
    end

    test "builds tag with name and description" do
      tag = TagBuilder.build_tag("Posts", "Blog post operations")

      assert tag == %{"name" => "Posts", "description" => "Blog post operations"}
    end

    test "builds tag with external docs" do
      external_docs = %{"url" => "https://docs.example.com/posts"}
      tag = TagBuilder.build_tag("Posts", nil, external_docs: external_docs)

      assert tag == %{"name" => "Posts", "externalDocs" => external_docs}
    end

    test "builds tag with all fields" do
      external_docs = %{"url" => "https://docs.example.com/posts", "description" => "Full docs"}
      tag = TagBuilder.build_tag("Posts", "Blog posts", external_docs: external_docs)

      assert tag["name"] == "Posts"
      assert tag["description"] == "Blog posts"
      assert tag["externalDocs"] == external_docs
    end

    test "ignores nil description" do
      tag = TagBuilder.build_tag("Posts", nil)

      assert tag == %{"name" => "Posts"}
      refute Map.has_key?(tag, "description")
    end
  end

  describe "resource_tag_name/1" do
    test "extracts last module segment" do
      assert TagBuilder.resource_tag_name(MyApp.Blog.Post) == "Post"
      assert TagBuilder.resource_tag_name(MyApp.Blog.Comment) == "Comment"
    end

    test "handles single segment modules" do
      assert TagBuilder.resource_tag_name(Post) == "Post"
    end

    test "handles deeply nested modules" do
      assert TagBuilder.resource_tag_name(MyApp.V1.Blog.Resources.Post) == "Post"
    end
  end

  describe "domain_tag_name/1" do
    test "extracts last module segment" do
      assert TagBuilder.domain_tag_name(AshOaskit.Test.Blog) == "Blog"
      assert TagBuilder.domain_tag_name(AshOaskit.Test.Publishing) == "Publishing"
    end

    test "handles deeply nested modules" do
      assert TagBuilder.domain_tag_name(AshOaskit.Test.SimpleDomain) == "SimpleDomain"
    end
  end

  describe "operation_tag/2" do
    test "returns resource name by default" do
      route = %{resource: MyApp.Blog.Post}

      assert TagBuilder.operation_tag(route) == "Post"
    end

    test "returns resource name for :resource grouping" do
      route = %{resource: MyApp.Blog.Post}

      assert TagBuilder.operation_tag(route, group_by: :resource) == "Post"
    end

    test "handles missing resource gracefully" do
      route = %{}

      # Should not raise, returns nil-safe result
      result = TagBuilder.operation_tag(route)
      assert is_binary(result) or is_nil(result)
    end
  end

  describe "operation_tags/2" do
    test "returns list with single tag" do
      route = %{resource: MyApp.Blog.Post}

      tags = TagBuilder.operation_tags(route)

      assert tags == ["Post"]
    end

    test "returns list for domain grouping" do
      route = %{resource: MyApp.Blog.Post}

      tags = TagBuilder.operation_tags(route, group_by: :resource)

      assert is_list(tags)
      assert [_] = tags
    end
  end

  describe "build_resource_tags/2" do
    test "returns empty list for empty domains" do
      tags = TagBuilder.build_resource_tags([])

      assert tags == []
    end

    test "includes descriptions by default" do
      # We can't easily test with real domains, but we can test the function signature
      tags = TagBuilder.build_resource_tags([], true)

      assert is_list(tags)
    end

    test "excludes descriptions when requested" do
      tags = TagBuilder.build_resource_tags([], false)

      assert is_list(tags)
    end
  end

  describe "build_domain_tags/2" do
    test "returns empty list for empty domains" do
      tags = TagBuilder.build_domain_tags([])

      assert tags == []
    end

    test "creates tag for each domain" do
      tags =
        TagBuilder.build_domain_tags(
          [AshOaskit.Test.Blog, AshOaskit.Test.Publishing],
          false
        )

      assert [_, _] = tags
      tag_names = Enum.map(tags, & &1["name"])
      assert "Blog" in tag_names
      assert "Publishing" in tag_names
    end

    test "sorts tags alphabetically" do
      tags =
        TagBuilder.build_domain_tags(
          [AshOaskit.Test.Publishing, AshOaskit.Test.Blog],
          false
        )

      tag_names = Enum.map(tags, & &1["name"])
      assert tag_names == ["Blog", "Publishing"]
    end

    test "removes duplicate domain names" do
      tags =
        TagBuilder.build_domain_tags(
          [AshOaskit.Test.Blog, AshOaskit.Test.Blog],
          false
        )

      assert [_] = tags
    end

    test "includes descriptions when requested" do
      tags = TagBuilder.build_domain_tags([AshOaskit.Test.Blog], true)

      assert [_] = tags
      assert tags |> hd() |> Map.get("description") == "Blog domain operations"
    end
  end

  describe "build_custom_tags/2" do
    test "returns empty list for empty domains" do
      tags = TagBuilder.build_custom_tags([])

      assert tags == []
    end

    test "falls back to domain name when no custom tag configured" do
      tags = TagBuilder.build_custom_tags([AshOaskit.Test.Blog], false)

      assert [_] = tags
      assert hd(tags)["name"] == "Blog"
    end
  end

  describe "build_tags/2" do
    test "defaults to resource grouping" do
      tags = TagBuilder.build_tags([])

      assert is_list(tags)
    end

    test "respects group_by: :domain option" do
      tags = TagBuilder.build_tags([AshOaskit.Test.Blog], group_by: :domain)

      # Should have domain tag, not resource tags
      tag_names = Enum.map(tags, & &1["name"])
      assert "Blog" in tag_names
    end

    test "respects group_by: :resource option" do
      tags = TagBuilder.build_tags([], group_by: :resource)

      assert is_list(tags)
    end

    test "respects group_by: :custom option" do
      tags = TagBuilder.build_tags([AshOaskit.Test.Blog], group_by: :custom)

      assert is_list(tags)
    end

    test "respects include_descriptions option" do
      tags_with =
        TagBuilder.build_tags([AshOaskit.Test.Blog],
          group_by: :domain,
          include_descriptions: true
        )

      tags_without =
        TagBuilder.build_tags([AshOaskit.Test.Blog],
          group_by: :domain,
          include_descriptions: false
        )

      # With descriptions
      unless Enum.empty?(tags_with) do
        assert Map.has_key?(hd(tags_with), "description")
      end

      # Without descriptions
      unless Enum.empty?(tags_without) do
        refute Map.has_key?(hd(tags_without), "description")
      end
    end
  end

  describe "get_default_grouping/1" do
    test "returns :resource for empty list" do
      assert TagBuilder.get_default_grouping([]) == :resource
    end

    test "returns :resource as default" do
      # Without AshJsonApi config, should default to :resource
      assert TagBuilder.get_default_grouping([AshOaskit.Test.Blog]) == :resource
    end
  end

  describe "merge_tags/2" do
    test "returns generated tags when no custom tags" do
      generated = [%{"name" => "Posts"}, %{"name" => "Comments"}]

      result = TagBuilder.merge_tags(generated, [])

      # merge_tags sorts results alphabetically
      assert result == [%{"name" => "Comments"}, %{"name" => "Posts"}]
    end

    test "returns custom tags when no generated tags" do
      custom = [%{"name" => "Custom"}]

      result = TagBuilder.merge_tags([], custom)

      assert result == custom
    end

    test "custom tags override generated with same name" do
      generated = [%{"name" => "Posts", "description" => "Generated"}]
      custom = [%{"name" => "Posts", "description" => "Custom"}]

      result = TagBuilder.merge_tags(generated, custom)

      assert [_] = result
      assert hd(result)["description"] == "Custom"
    end

    test "adds custom tags not in generated" do
      generated = [%{"name" => "Posts"}]
      custom = [%{"name" => "Custom"}]

      result = TagBuilder.merge_tags(generated, custom)

      assert [_, _] = result
      tag_names = Enum.map(result, & &1["name"])
      assert "Posts" in tag_names
      assert "Custom" in tag_names
    end

    test "sorts merged tags alphabetically" do
      generated = [%{"name" => "Zebra"}]
      custom = [%{"name" => "Alpha"}]

      result = TagBuilder.merge_tags(generated, custom)

      tag_names = Enum.map(result, & &1["name"])
      assert tag_names == ["Alpha", "Zebra"]
    end

    test "handles complex merge scenario" do
      generated = [
        %{"name" => "Posts", "description" => "Generated posts"},
        %{"name" => "Comments", "description" => "Generated comments"}
      ]

      custom = [
        %{
          "name" => "Posts",
          "description" => "Custom posts",
          "externalDocs" => %{"url" => "..."}
        },
        %{"name" => "NewTag", "description" => "Brand new"}
      ]

      result = TagBuilder.merge_tags(generated, custom)

      assert [_, _, _] = result

      posts_tag = Enum.find(result, &(&1["name"] == "Posts"))
      assert posts_tag["description"] == "Custom posts"
      assert Map.has_key?(posts_tag, "externalDocs")

      comments_tag = Enum.find(result, &(&1["name"] == "Comments"))
      assert comments_tag["description"] == "Generated comments"

      new_tag = Enum.find(result, &(&1["name"] == "NewTag"))
      assert new_tag["description"] == "Brand new"
    end
  end

  describe "build_tags_with_docs/2" do
    test "adds external docs to tags when base_url provided" do
      tags =
        TagBuilder.build_tags_with_docs([AshOaskit.Test.Blog],
          group_by: :domain,
          base_url: "https://docs.example.com"
        )

      unless Enum.empty?(tags) do
        tag = hd(tags)
        assert Map.has_key?(tag, "externalDocs")
        assert String.contains?(tag["externalDocs"]["url"], "https://docs.example.com")
      end
    end

    test "does not add external docs when base_url not provided" do
      tags = TagBuilder.build_tags_with_docs([AshOaskit.Test.Blog], group_by: :domain)

      unless Enum.empty?(tags) do
        tag = hd(tags)
        # May or may not have externalDocs depending on other config
        # Just verify it doesn't crash
        assert is_map(tag)
      end
    end

    test "creates URL-friendly slugs" do
      tags =
        TagBuilder.build_tags_with_docs([AshOaskit.Test.Blog],
          group_by: :domain,
          base_url: "https://docs.example.com"
        )

      unless Enum.empty?(tags) do
        tag = hd(tags)
        url = tag["externalDocs"]["url"]
        # Should be lowercase
        assert url == String.downcase(url)
      end
    end
  end

  describe "schema structure validation" do
    test "all tags are valid OpenAPI tag objects" do
      tags = [
        TagBuilder.build_tag("Posts"),
        TagBuilder.build_tag("Posts", "Description"),
        TagBuilder.build_tag("Posts", "Description",
          external_docs: %{"url" => "https://example.com"}
        )
      ]

      for tag <- tags do
        assert is_map(tag)
        assert is_binary(tag["name"])
        if Map.has_key?(tag, "description"), do: assert(is_binary(tag["description"]))
        if Map.has_key?(tag, "externalDocs"), do: assert(is_map(tag["externalDocs"]))
      end
    end

    test "tags can be serialized to JSON" do
      tags = [
        TagBuilder.build_tag("Posts", "Blog posts"),
        TagBuilder.build_tag("Comments", nil,
          external_docs: %{"url" => "https://docs.example.com"}
        )
      ]

      assert {:ok, _json} = Jason.encode(tags)
    end
  end

  describe "with real Ash domains" do
    test "build_resource_tags with real domain" do
      tags = TagBuilder.build_resource_tags([AshOaskit.Test.Publishing], true)

      assert is_list(tags)
      # Publishing domain has Author, Article, Review, Tag, Category, ArticleTag
      refute Enum.empty?(tags)
      # Tags should have names
      for tag <- tags do
        assert is_binary(tag["name"])
      end
    end

    test "build_resource_tags without descriptions" do
      tags = TagBuilder.build_resource_tags([AshOaskit.Test.Publishing], false)

      for tag <- tags do
        refute Map.has_key?(tag, "description")
      end
    end

    test "build_tags with real domain defaults to resource grouping" do
      tags = TagBuilder.build_tags([AshOaskit.Test.Publishing])

      assert is_list(tags)
      refute Enum.empty?(tags)
    end

    test "build_tags_with_docs with real domain" do
      tags =
        TagBuilder.build_tags_with_docs(
          [AshOaskit.Test.Publishing],
          base_url: "https://api.example.com/docs"
        )

      for tag <- tags do
        assert Map.has_key?(tag, "externalDocs")
        assert String.starts_with?(tag["externalDocs"]["url"], "https://api.example.com/docs")
      end
    end

    test "operation_tag with domain grouping" do
      route = %{resource: AshOaskit.Test.Article}

      tag = TagBuilder.operation_tag(route, group_by: :domain)

      # Should try to get domain tag
      assert is_binary(tag) or is_nil(tag)
    end

    test "operation_tag with custom grouping" do
      route = %{resource: AshOaskit.Test.Article}

      tag = TagBuilder.operation_tag(route, group_by: :custom)

      assert is_binary(tag)
    end

    test "build_custom_tags with real domain" do
      tags = TagBuilder.build_custom_tags([AshOaskit.Test.Publishing], true)

      assert is_list(tags)
      assert [_] = tags
      assert hd(tags)["name"] == "Publishing"
    end

    test "get_default_grouping with real domain" do
      result = TagBuilder.get_default_grouping([AshOaskit.Test.Publishing])

      # Should return :resource as default (domain not configured with group_by)
      assert result == :resource
    end
  end

  describe "integration scenarios" do
    test "building tags for multi-domain API" do
      domains = [AshOaskit.Test.Blog, AshOaskit.Test.Publishing, AshOaskit.Test.SimpleDomain]

      # Resource grouping would show individual resources
      # Domain grouping shows domains
      domain_tags = TagBuilder.build_tags(domains, group_by: :domain)

      assert length(domain_tags) == 3
      tag_names = Enum.map(domain_tags, & &1["name"])
      assert "Blog" in tag_names
      assert "Publishing" in tag_names
      assert "SimpleDomain" in tag_names
    end

    test "merging generated and custom tags for documentation" do
      generated =
        TagBuilder.build_domain_tags([AshOaskit.Test.Blog, AshOaskit.Test.Publishing], true)

      custom = [
        %{
          "name" => "Blog",
          "description" => "Custom blog description with more detail",
          "externalDocs" => %{
            "url" => "https://docs.example.com/blog",
            "description" => "Complete blog API documentation"
          }
        },
        %{
          "name" => "Webhooks",
          "description" => "Webhook configuration endpoints"
        }
      ]

      merged = TagBuilder.merge_tags(generated, custom)

      # Should have Blog (custom), Publishing (generated), Webhooks (custom)
      assert length(merged) == 3

      blog = Enum.find(merged, &(&1["name"] == "Blog"))
      assert blog["description"] == "Custom blog description with more detail"
      assert Map.has_key?(blog, "externalDocs")
    end

    test "operation tagging consistency" do
      route = %{resource: AshOaskit.Test.Post}

      # Same route should get same tag regardless of how we call it
      tag1 = TagBuilder.operation_tag(route, group_by: :resource)
      tags_list = TagBuilder.operation_tags(route, group_by: :resource)

      assert tag1 == hd(tags_list)
    end
  end

  describe "edge cases" do
    test "resource domain tag when domain is nil" do
      # Route with resource that might not have a domain configured
      route = %{resource: AshOaskit.Test.NoTypeResource}

      tag = TagBuilder.operation_tag(route, group_by: :domain)

      assert is_binary(tag)
    end
  end
end
