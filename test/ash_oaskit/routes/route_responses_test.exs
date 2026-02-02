defmodule AshOaskit.RouteResponsesTest do
  @moduledoc """
  Tests for the AshOaskit.RelationshipRoutes.RouteResponses module.

  This module tests the generation of OpenAPI response schemas for JSON:API
  relationship endpoints, including resource identifier schemas, linkage
  schemas, and full response wrappers.

  ## Test Categories

  - **Resource identifiers** - Type/id schema generation with enum constraints
  - **Linkage schemas** - To-one (nullable) and to-many (array) linkage
  - **Response schemas** - Full response objects with data, links, and meta
  - **Related responses** - Schemas for related resource endpoints
  - **Request bodies** - Input schemas for relationship modification
  - **Cardinality detection** - belongs_to/has_one vs has_many/many_to_many
  - **Version differences** - OpenAPI 3.0 nullable flag vs 3.1 type arrays
  - **Route integration** - Building responses from actual route definitions

  ## Why These Tests Matter

  Relationship endpoints are complex in JSON:API. The response format varies
  by cardinality (to-one vs to-many), operation type (read vs modify), and
  OpenAPI version (3.0 nullable vs 3.1 type arrays). These tests ensure all
  combinations produce valid schemas.
  """

  use ExUnit.Case, async: true

  alias AshJsonApi.Domain.Info
  alias AshOaskit.RelationshipRoutes.RouteResponses
  alias AshOaskit.Test.Author
  alias AshOaskit.Test.Post
  alias AshOaskit.Test.Publishing
  alias AshOaskit.Test.Review

  describe "RouteResponses relationship schemas" do
    test "builds resource identifier schema with type and id" do
      schema =
        RouteResponses.build_resource_identifier_schema("comment")

      assert schema[:required] == ["type", "id"]
      assert schema[:properties]["type"][:enum] == ["comment"]
    end

    test "to-many relationship linkage is an array" do
      rel = %{type: :has_many, destination: Review}

      schema =
        RouteResponses.build_relationship_linkage_schema(rel,
          version: "3.1"
        )

      assert schema[:type] == :array
    end

    test "to-one relationship linkage is nullable in 3.1" do
      rel = %{type: :belongs_to, destination: Author}

      schema =
        RouteResponses.build_relationship_linkage_schema(rel,
          version: "3.1"
        )

      assert Map.has_key?(schema, :oneOf)
      assert %{type: :null} in schema[:oneOf]
    end

    test "to-one relationship linkage is nullable in 3.0" do
      rel = %{type: :belongs_to, destination: Author}

      schema =
        RouteResponses.build_relationship_linkage_schema(rel,
          version: "3.0"
        )

      assert schema[:nullable] == true
    end

    test "builds full relationship response schema" do
      rel = %{type: :has_many, destination: Review}

      schema =
        RouteResponses.build_relationship_response_schema(rel,
          version: "3.1"
        )

      assert Map.has_key?(schema[:properties], "data")
      assert Map.has_key?(schema[:properties], "links")
    end

    test "builds related response for to-many" do
      rel = %{type: :has_many, destination: Review}

      schema =
        RouteResponses.build_related_response_schema(rel,
          version: "3.1"
        )

      assert schema[:properties]["data"][:type] == :array
      assert schema[:properties]["data"][:items]["$ref"] =~ "ReviewResponse"
    end

    test "builds related response for to-one" do
      rel = %{type: :belongs_to, destination: Author}

      schema =
        RouteResponses.build_related_response_schema(rel,
          version: "3.1"
        )

      data_schema = schema[:properties]["data"]
      assert Map.has_key?(data_schema, :oneOf)
      assert %{type: :null} in data_schema[:oneOf]
    end

    test "builds request body for relationship modification" do
      rel = %{type: :has_many, destination: Review}
      body = RouteResponses.build_request_body(rel, version: "3.1")
      assert body[:required] == true
      assert body[:content]["application/vnd.api+json"][:schema][:required] == ["data"]
    end

    test "delete relationship responses include 200 and 204" do
      responses =
        RouteResponses.build_delete_relationship_responses()

      assert Map.has_key?(responses, "200")
      assert Map.has_key?(responses, "204")
    end

    test "cardinality detection for belongs_to" do
      assert RouteResponses.relationship_cardinality(%{
               type: :belongs_to
             }) == :one
    end

    test "cardinality detection for has_many" do
      assert RouteResponses.relationship_cardinality(%{
               type: :has_many
             }) == :many
    end
  end

  describe "RouteResponses with routes" do
    test "builds related responses when relationship exists" do
      routes = Info.routes(Publishing)
      related_route = Enum.find(routes, &(&1.type == :related))

      if related_route do
        responses =
          RouteResponses.build_related_responses(
            related_route,
            version: "3.1"
          )

        assert Map.has_key?(responses, "200")
      end
    end

    test "builds relationship responses when relationship exists" do
      routes = Info.routes(Publishing)
      rel_route = Enum.find(routes, &(&1.type == :relationship))

      if rel_route do
        responses =
          RouteResponses.build_relationship_responses(
            rel_route,
            version: "3.1"
          )

        assert Map.has_key?(responses, "200")
      end
    end

    test "build_modify_relationship_responses with relationship route" do
      routes = Info.routes(Publishing)
      post_rel_route = Enum.find(routes, &(&1.type == :post_to_relationship))

      if post_rel_route do
        responses =
          RouteResponses.build_modify_relationship_responses(
            post_rel_route,
            [version: "3.1"],
            "200"
          )

        assert Map.has_key?(responses, "200")
        assert Map.has_key?(responses, "422")
      end
    end

    test "returns generic response when route has no relationship" do
      route = %{relationship: nil, resource: Post}

      responses =
        RouteResponses.build_related_responses(
          route,
          version: "3.1"
        )

      assert responses["200"][:description] == "Successful response"
    end
  end
end
