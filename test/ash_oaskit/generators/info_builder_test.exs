defmodule AshOaskit.Generators.InfoBuilderTest do
  @moduledoc """
  Tests for the `AshOaskit.Generators.InfoBuilder` module.

  Verifies the generation of OpenAPI Info objects, server configurations,
  and resource tags from Ash domains.

  ## Test categories

    - `build_info/1` — Info object with title, version, description, contact, license
    - `build_servers/1` — Server array from URL strings and server objects
    - `build_tags/1` — Tag generation from domain resources
  """
  use ExUnit.Case, async: true

  alias AshOaskit.Generators.InfoBuilder

  describe "build_info/1" do
    test "builds info with title and default version" do
      info = InfoBuilder.build_info(title: "Pet Store")

      assert info.title == "Pet Store"
      assert info.version == "1.0.0"
    end

    test "includes api_version when provided" do
      info = InfoBuilder.build_info(title: "API", api_version: "2.5.0")

      assert info.version == "2.5.0"
    end

    test "includes description when provided" do
      info = InfoBuilder.build_info(title: "API", description: "My API description")

      assert info.description == "My API description"
    end

    test "includes contact when provided" do
      contact = %{"name" => "Support", "email" => "support@example.com"}
      info = InfoBuilder.build_info(title: "API", contact: contact)

      assert info.contact == contact
    end

    test "includes license when provided" do
      license = %{"name" => "MIT"}
      info = InfoBuilder.build_info(title: "API", license: license)

      assert info.license == license
    end

    test "includes terms_of_service when provided" do
      info = InfoBuilder.build_info(title: "API", terms_of_service: "https://example.com/tos")

      assert info.termsOfService == "https://example.com/tos"
    end

    test "omits nil values" do
      info = InfoBuilder.build_info(title: "API")

      refute Map.has_key?(info, :description)
      refute Map.has_key?(info, :contact)
      refute Map.has_key?(info, :license)
      refute Map.has_key?(info, :termsOfService)
    end

    test "includes all fields when fully specified" do
      info =
        InfoBuilder.build_info(
          title: "Full API",
          api_version: "3.0.0",
          description: "A complete API",
          terms_of_service: "https://example.com/tos",
          contact: %{"name" => "Dev"},
          license: %{"name" => "Apache-2.0"}
        )

      assert info.title == "Full API"
      assert info.version == "3.0.0"
      assert info.description == "A complete API"
      assert info.termsOfService == "https://example.com/tos"
      assert info.contact == %{"name" => "Dev"}
      assert info.license == %{"name" => "Apache-2.0"}
    end
  end

  describe "build_servers/1" do
    test "returns default server when no servers specified" do
      servers = InfoBuilder.build_servers([])

      assert servers == [%{url: "/"}]
    end

    test "normalizes string URLs to server objects" do
      servers = InfoBuilder.build_servers(servers: ["https://api.example.com"])

      assert servers == [%{url: "https://api.example.com"}]
    end

    test "passes through server objects unchanged" do
      server = %{url: "https://api.example.com", description: "Production"}
      servers = InfoBuilder.build_servers(servers: [server])

      assert servers == [server]
    end

    test "handles multiple servers" do
      servers =
        InfoBuilder.build_servers(
          servers: [
            "https://api.example.com",
            %{url: "https://staging.example.com", description: "Staging"}
          ]
        )

      assert length(servers) == 2
      assert Enum.at(servers, 0) == %{url: "https://api.example.com"}
      assert Enum.at(servers, 1).description == "Staging"
    end
  end

  describe "build_tags/1" do
    test "generates tags from domain resources" do
      tags = InfoBuilder.build_tags([AshOaskit.Test.Blog])

      tag_names = Enum.map(tags, & &1.name)
      assert "Post" in tag_names
    end

    test "deduplicates tags by name" do
      tags = InfoBuilder.build_tags([AshOaskit.Test.Blog, AshOaskit.Test.Blog])

      tag_names = Enum.map(tags, & &1.name)
      assert tag_names == Enum.uniq(tag_names)
    end

    test "returns empty list for empty domains" do
      tags = InfoBuilder.build_tags([])

      assert tags == []
    end
  end
end
