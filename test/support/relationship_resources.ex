# Test resources for relationship, calculation, aggregate, and embedded resource testing
#
# This module defines additional Ash resources used to test advanced OpenAPI
# spec generation features that require relationships between resources.
#
# ## Resources
#
# ### Core Resources (with relationships)
# - `AshOaskit.Test.Author` - Author with has_many posts, calculations
# - `AshOaskit.Test.Article` - Article with belongs_to author, has_many comments
# - `AshOaskit.Test.Review` - Review with belongs_to article
# - `AshOaskit.Test.Tag` - Tag for many_to_many relationship testing
# - `AshOaskit.Test.ArticleTag` - Join resource for article-tag relationship
#
# ### Embedded Resources
# - `AshOaskit.Test.Address` - Simple embedded resource
# - `AshOaskit.Test.Profile` - Embedded resource with nested embedded (Address)
#
# ### Recursive/Self-referential Resources
# - `AshOaskit.Test.Category` - Self-referential with parent/children
#
# ## Domains
#
# - `AshOaskit.Test.Publishing` - Domain with all relationship resources
#
# ## Test Coverage
#
# These resources enable testing of:
# - belongs_to relationships (Article -> Author)
# - has_many relationships (Author -> Articles)
# - has_one relationships (Author -> Profile)
# - many_to_many relationships (Article <-> Tags)
# - Self-referential relationships (Category parent/children)
# - Calculations with expressions
# - Aggregates (count, sum, etc.)
# - Embedded resources
# - Nested embedded resources
# - Recursive type detection and $ref generation

# ===========================================================================
# Embedded Resources (must be defined first - no domain required)
# ===========================================================================

defmodule AshOaskit.Test.Address do
  @moduledoc """
  Embedded resource for address data.

  Used to test embedded resource schema generation, including:
  - Embedded resource detection
  - Input schema generation for embedded types
  - Nested embedding (used in Profile)
  """
  use Ash.Resource, data_layer: :embedded

  attributes do
    attribute :street, :string do
      description("Street address line")
    end

    attribute :city, :string do
      allow_nil? false
      description("City name")
    end

    attribute :state, :string do
      description("State or province")
    end

    attribute :postal_code, :string do
      constraints(match: ~r/^\d{5}(-\d{4})?$/)
      description("ZIP or postal code")
    end

    attribute :country, :string do
      default("US")
      description("ISO country code")
    end
  end
end

defmodule AshOaskit.Test.Profile do
  @moduledoc """
  Embedded resource for user profile data with nested embedded.

  Used to test:
  - Nested embedded resources (Profile contains Address)
  - Recursive embedded schema generation
  - Multiple levels of embedding
  """
  use Ash.Resource, data_layer: :embedded

  attributes do
    attribute :bio, :string do
      constraints(max_length: 500)
      description("Short biography")
    end

    attribute :website, :string do
      description("Personal website URL")
    end

    attribute :avatar_url, :string do
      description("URL to avatar image")
    end

    attribute :address, AshOaskit.Test.Address do
      description("Mailing address")
    end

    attribute :social_links, {:array, :string} do
      default([])
      description("Social media profile URLs")
    end
  end
end

# ===========================================================================
# Core Resources with Relationships
# ===========================================================================

defmodule AshOaskit.Test.Author do
  @moduledoc """
  Author resource with relationships and calculations.

  Used to test:
  - has_many relationships (articles)
  - has_one relationship (profile - embedded)
  - Calculations (article_count, full_name)
  - Aggregates (total_articles)
  """
  use Ash.Resource,
    domain: AshOaskit.Test.Publishing,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshJsonApi.Resource]

  json_api do
    type("author")
  end

  attributes do
    uuid_primary_key(:id)

    attribute :first_name, :string do
      allow_nil? false
      description("Author's first name")
    end

    attribute :last_name, :string do
      allow_nil? false
      description("Author's last name")
    end

    attribute :email, :string do
      allow_nil? false
      constraints(match: ~r/^[^\s]+@[^\s]+$/)
      description("Author's email address")
    end

    attribute :profile, AshOaskit.Test.Profile do
      description("Author's profile information")
    end

    attribute :active, :boolean do
      default(true)
      description("Whether the author is currently active")
    end

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  relationships do
    has_many :articles, AshOaskit.Test.Article do
      description("Articles written by this author")
    end
  end

  calculations do
    calculate :full_name, :string, expr(first_name <> " " <> last_name) do
      description("Author's full name")
    end

    calculate :article_count, :integer, expr(count(articles)) do
      description("Number of articles written")
    end

    # Calculation with arguments for coverage testing
    calculate :greeting, :string, expr("Hello, " <> ^arg(:name)) do
      description("Personalized greeting")

      argument :name, :string do
        allow_nil? false
      end
    end

    # Calculation with optional argument for coverage testing
    calculate :formal_greeting,
              :string,
              expr("Dear " <> (^arg(:title) || "") <> " " <> first_name) do
      description("Formal greeting with optional title")

      argument :title, :string do
        allow_nil? true
        default(nil)
      end
    end
  end

  aggregates do
    count :total_articles, :articles do
      description("Total number of articles")
    end
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      accept([:first_name, :last_name, :email, :profile, :active])
    end

    update :update do
      accept([:first_name, :last_name, :email, :profile, :active])
    end
  end
end

defmodule AshOaskit.Test.Article do
  @moduledoc """
  Article resource with multiple relationship types.

  Used to test:
  - belongs_to relationship (author)
  - has_many relationship (reviews)
  - many_to_many relationship (tags via article_tags)
  - Calculations depending on relationships
  - Aggregates on relationships
  """
  use Ash.Resource,
    domain: AshOaskit.Test.Publishing,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshJsonApi.Resource]

  json_api do
    type("article")
  end

  attributes do
    uuid_primary_key(:id)

    attribute :title, :string do
      allow_nil? false
      constraints(min_length: 1, max_length: 255)
      description("Article title")
    end

    attribute :content, :string do
      description("Article body content")
    end

    attribute :status, :atom do
      constraints(one_of: [:draft, :published, :archived])
      default(:draft)
      description("Publication status")
    end

    attribute :published_at, :utc_datetime do
      description("When the article was published")
    end

    attribute :word_count, :integer do
      constraints(min: 0)
      description("Number of words in the article")
    end

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  relationships do
    belongs_to :author, AshOaskit.Test.Author do
      public? true
      allow_nil? false
      description("The author who wrote this article")
    end

    has_many :reviews, AshOaskit.Test.Review do
      public? true
      description("Reviews of this article")
    end

    many_to_many :tags, AshOaskit.Test.Tag do
      through(AshOaskit.Test.ArticleTag)
      description("Tags associated with this article")
    end
  end

  calculations do
    calculate :author_name, :string, expr(author.first_name <> " " <> author.last_name) do
      description("Name of the article's author")
    end

    calculate :review_count, :integer, expr(count(reviews)) do
      description("Number of reviews")
    end
  end

  aggregates do
    count :total_reviews, :reviews do
      description("Total number of reviews")
    end

    avg :average_rating, :reviews, :rating do
      description("Average review rating")
    end

    count :tag_count, :tags do
      description("Number of tags")
    end

    # Additional aggregates for coverage testing
    first :first_review_rating, :reviews, :rating do
      description("Rating of the first review")
    end

    list :review_ratings, :reviews, :rating do
      description("List of all review ratings")
    end

    min :min_review_rating, :reviews, :rating do
      description("Minimum review rating")
    end

    max :max_review_rating, :reviews, :rating do
      description("Maximum review rating")
    end

    sum :total_rating, :reviews, :rating do
      description("Sum of all review ratings")
    end

    exists :has_reviews, :reviews do
      description("Whether this article has any reviews")
    end
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      accept([:title, :content, :status, :word_count, :author_id])
    end

    update :update do
      primary? true
      accept([:title, :content, :status, :word_count])
    end

    update :publish do
      accept([])

      change(set_attribute(:status, :published))
      change(set_attribute(:published_at, &DateTime.utc_now/0))
    end
  end
end

defmodule AshOaskit.Test.Review do
  @moduledoc """
  Review resource for testing belongs_to relationships.

  Used to test:
  - belongs_to relationship (article)
  - Simple aggregate source (rating for average)
  """
  use Ash.Resource,
    domain: AshOaskit.Test.Publishing,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshJsonApi.Resource]

  json_api do
    type("review")
  end

  attributes do
    uuid_primary_key(:id)

    attribute :rating, :integer do
      allow_nil? false
      constraints(min: 1, max: 5)
      description("Rating from 1 to 5 stars")
    end

    attribute :comment, :string do
      constraints(max_length: 1000)
      description("Review comment text")
    end

    attribute :reviewer_name, :string do
      allow_nil? false
      description("Name of the reviewer")
    end

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  relationships do
    belongs_to :article, AshOaskit.Test.Article do
      allow_nil? false
      description("The article being reviewed")
    end
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      accept([:rating, :comment, :reviewer_name, :article_id])
    end
  end
end

defmodule AshOaskit.Test.Tag do
  @moduledoc """
  Tag resource for many_to_many relationship testing.

  Used to test:
  - many_to_many relationship (articles via article_tags)
  - Simple resource with minimal attributes
  """
  use Ash.Resource,
    domain: AshOaskit.Test.Publishing,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshJsonApi.Resource]

  json_api do
    type("tag")
  end

  attributes do
    uuid_primary_key(:id)

    attribute :name, :string do
      allow_nil? false
      constraints(min_length: 1, max_length: 50)
      description("Tag name")
    end

    attribute :slug, :ci_string do
      allow_nil? false
      description("URL-friendly tag identifier")
    end

    attribute :color, :string do
      constraints(match: ~r/^#[0-9A-Fa-f]{6}$/)
      description("Hex color code for display")
    end

    create_timestamp(:inserted_at)
  end

  relationships do
    many_to_many :articles, AshOaskit.Test.Article do
      through(AshOaskit.Test.ArticleTag)
      description("Articles with this tag")
    end
  end

  aggregates do
    count :article_count, :articles do
      description("Number of articles with this tag")
    end
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      accept([:name, :slug, :color])
    end
  end
end

defmodule AshOaskit.Test.ArticleTag do
  @moduledoc """
  Join resource for Article-Tag many_to_many relationship.

  This is a simple join table resource that connects articles to tags.
  """
  use Ash.Resource,
    domain: AshOaskit.Test.Publishing,
    data_layer: Ash.DataLayer.Ets

  attributes do
    uuid_primary_key(:id)
    create_timestamp(:inserted_at)
  end

  relationships do
    belongs_to :article, AshOaskit.Test.Article do
      primary_key? true
      allow_nil? false
    end

    belongs_to :tag, AshOaskit.Test.Tag do
      primary_key? true
      allow_nil? false
    end
  end

  actions do
    defaults([:read, :destroy, :create])
  end
end

# ===========================================================================
# Self-Referential Resource
# ===========================================================================

defmodule AshOaskit.Test.Category do
  @moduledoc """
  Self-referential resource for recursive relationship testing.

  Used to test:
  - Self-referential belongs_to (parent category)
  - Self-referential has_many (child categories)
  - Cycle detection in schema generation
  - $ref usage for recursive types
  """
  use Ash.Resource,
    domain: AshOaskit.Test.Publishing,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshJsonApi.Resource]

  json_api do
    type("category")
  end

  attributes do
    uuid_primary_key(:id)

    attribute :name, :string do
      allow_nil? false
      constraints(min_length: 1, max_length: 100)
      description("Category name")
    end

    attribute :description, :string do
      description("Category description")
    end

    attribute :slug, :ci_string do
      allow_nil? false
      description("URL-friendly identifier")
    end

    attribute :position, :integer do
      default(0)
      description("Sort position within parent")
    end

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  relationships do
    belongs_to :parent, __MODULE__ do
      description("Parent category (null for root categories)")
    end

    has_many :children, __MODULE__ do
      destination_attribute(:parent_id)
      description("Child categories")
    end
  end

  calculations do
    calculate :full_path,
              :string,
              expr(
                if is_nil(parent_id) do
                  name
                else
                  parent.name <> " > " <> name
                end
              ) do
      description("Full category path")
    end

    calculate :child_count, :integer, expr(count(children)) do
      description("Number of direct child categories")
    end
  end

  aggregates do
    count :total_children, :children do
      description("Total number of child categories")
    end
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      accept([:name, :description, :slug, :position, :parent_id])
    end

    update :update do
      accept([:name, :description, :slug, :position, :parent_id])
    end
  end
end

# ===========================================================================
# Domain Definition
# ===========================================================================

defmodule AshOaskit.Test.Publishing do
  @moduledoc """
  Domain for relationship testing resources.

  This domain includes all resources with relationships, calculations,
  aggregates, and embedded resources for comprehensive testing.
  """
  use Ash.Domain,
    validate_config_inclusion?: false,
    extensions: [AshJsonApi.Domain]

  resources do
    resource(AshOaskit.Test.Author)
    resource(AshOaskit.Test.Article)
    resource(AshOaskit.Test.Review)
    resource(AshOaskit.Test.Tag)
    resource(AshOaskit.Test.ArticleTag)
    resource(AshOaskit.Test.Category)
  end

  json_api do
    routes do
      base_route "/authors", AshOaskit.Test.Author do
        get(:read)
        index(:read)
        post(:create)
        patch(:update)
        delete(:destroy)
      end

      base_route "/articles", AshOaskit.Test.Article do
        get(:read)
        index(:read)
        post(:create)
        patch(:update)
        delete(:destroy)
        # Relationship routes for coverage testing
        related(:reviews, :read)
        related(:author, :read)
        relationship(:reviews, :read)
        relationship(:author, :read)
        post_to_relationship(:reviews)
        delete_from_relationship(:reviews)
      end

      base_route "/reviews", AshOaskit.Test.Review do
        get(:read)
        index(:read)
        post(:create)
        delete(:destroy)
      end

      base_route "/tags", AshOaskit.Test.Tag do
        get(:read)
        index(:read)
        post(:create)
        delete(:destroy)
      end

      base_route "/categories", AshOaskit.Test.Category do
        get(:read)
        index(:read)
        post(:create)
        patch(:update)
        delete(:destroy)
      end
    end
  end
end
