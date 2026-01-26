# Test resources for AshOaskit
#
# This module defines Ash resources and domains used throughout the test suite
# to validate OpenAPI spec generation. The resources include various attribute
# types to ensure comprehensive type mapping coverage.
#
# ## Resources
#
# - `AshOaskit.Test.Post` - Main test resource with all supported attribute types
# - `AshOaskit.Test.Comment` - Secondary resource for multi-resource domain testing
#
# ## Domains
#
# - `AshOaskit.Test.SimpleDomain` - Basic domain without AshJsonApi (fallback testing)
# - `AshOaskit.Test.Blog` - Domain with AshJsonApi routes (path generation testing)
#
# ## Usage in Tests
#
#     # Test schema generation
#     spec = AshOaskit.spec(domains: [AshOaskit.Test.SimpleDomain])
#     assert spec["components"]["schemas"]["PostAttributes"]
#
#     # Test path generation
#     spec = AshOaskit.spec(domains: [AshOaskit.Test.Blog])
#     assert spec["paths"]["/posts"]
#
# ## Attribute Coverage
#
# The Post resource includes attributes for testing all supported Ash types:
# - Basic types: string, integer, float, decimal, boolean
# - Date/time types: time, utc_datetime, naive_datetime
# - Special types: uuid, binary, map, atom, term, ci_string
# - Array types: {:array, :string}
# - Constraints: min_length, max_length, min, max, match, one_of

defmodule AshOaskit.Test.Post do
  @moduledoc false
  use Ash.Resource,
    domain: AshOaskit.Test.SimpleDomain,
    extensions: [AshJsonApi.Resource]

  json_api do
    type("post")
  end

  attributes do
    uuid_primary_key(:id)

    attribute :title, :string do
      allow_nil?(false)
      constraints(min_length: 1, max_length: 255)
    end

    attribute :body, :string do
      description("Post content")
    end

    attribute :status, :atom do
      constraints(one_of: [:draft, :published])
    end

    attribute :view_count, :integer do
      constraints(min: 0)
    end

    attribute :rating, :float do
      constraints(min: 0.0, max: 5.0)
    end

    attribute(:published_at, :utc_datetime)
    attribute(:tags, {:array, :string})
    attribute(:metadata, :map)
    attribute(:slug, :ci_string)
    attribute(:duration, :time)
    attribute(:local_time, :naive_datetime)
    attribute(:attachment, :binary)
    attribute(:config, :term)
    attribute(:score, :decimal)

    attribute :is_featured, :boolean do
      default(false)
    end

    attribute :email, :string do
      constraints(match: ~r/^[^\s]+@[^\s]+$/)
    end

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      accept([:title, :body, :status, :tags, :is_featured])
    end

    update :update do
      accept([:title, :body, :status, :tags, :is_featured])
    end
  end
end

# Resource with AshJsonApi extension but without explicit type (for nil type path testing)
defmodule AshOaskit.Test.NoTypeResource do
  @moduledoc false
  use Ash.Resource,
    domain: AshOaskit.Test.EdgeCaseDomain,
    extensions: [AshJsonApi.Resource]

  # Intentionally no json_api block - type will be nil, triggering default_type path

  attributes do
    uuid_primary_key(:id)
    attribute(:name, :string)
  end

  actions do
    defaults([:read])
  end
end

# Domain for edge case testing
defmodule AshOaskit.Test.EdgeCaseDomain do
  @moduledoc false
  use Ash.Domain,
    validate_config_inclusion?: false,
    extensions: [AshJsonApi.Domain]

  resources do
    resource(AshOaskit.Test.NoTypeResource)
  end

  json_api do
    prefix("/edge")

    routes do
      base_route "/no-type", AshOaskit.Test.NoTypeResource do
        index(:read)
      end
    end
  end
end

defmodule AshOaskit.Test.Comment do
  @moduledoc false
  use Ash.Resource,
    domain: AshOaskit.Test.SimpleDomain,
    extensions: [AshJsonApi.Resource]

  json_api do
    type("comment")
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:content, :string, allow_nil?: false)
    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      accept([:content])
    end
  end
end

# Simple domain without AshJsonApi routes (for fallback testing)
defmodule AshOaskit.Test.SimpleDomain do
  @moduledoc false
  use Ash.Domain, validate_config_inclusion?: false

  resources do
    resource(AshOaskit.Test.Post)
    resource(AshOaskit.Test.Comment)
  end
end

# Domain with AshJsonApi extension and routes
defmodule AshOaskit.Test.Blog do
  @moduledoc false
  use Ash.Domain,
    validate_config_inclusion?: false,
    extensions: [AshJsonApi.Domain]

  resources do
    resource(AshOaskit.Test.Post)
    resource(AshOaskit.Test.Comment)
  end

  json_api do
    routes do
      base_route "/posts", AshOaskit.Test.Post do
        get(:read)
        index(:read)
        post(:create)
        patch(:update)
        delete(:destroy)
      end

      base_route "/comments", AshOaskit.Test.Comment do
        get(:read)
        index(:read)
        post(:create)
        delete(:destroy)
      end
    end
  end
end
