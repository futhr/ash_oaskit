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
#
# ## Visibility Coverage
#
# Specs must only expose fields marked `public? true` (matching what
# AshJsonApi serializes). `Post.internal_notes` is deliberately
# non-public to regression-test that filtering; `Comment`'s timestamps
# are deliberately public to prove public timestamps DO appear.

defmodule AshOaskit.Test.Priority do
  @moduledoc """
  `Ash.Type.Enum` implementor used to test the generic enum fallback
  in `TypeMapper` (string schema with enum from `values/0`).
  """
  use Ash.Type.Enum, values: [:low, :medium, :high]
end

defmodule AshOaskit.Test.Subject do
  @moduledoc """
  `Ash.Type.NewType` wrapper used to test the generic NewType fallback
  in `TypeMapper` (schema resolved from the subtype).
  """
  use Ash.Type.NewType, subtype_of: :string, constraints: [max_length: 120]
end

defmodule AshOaskit.Test.Post do
  @moduledoc false
  use Ash.Resource,
    domain: AshOaskit.Test.SimpleDomain,
    extensions: [AshJsonApi.Resource]

  json_api do
    type "post"
  end

  attributes do
    uuid_primary_key :id

    attribute :title, :string do
      public? true
      allow_nil? false
      constraints min_length: 1, max_length: 255
    end

    attribute :body, :string do
      public? true
      description "Post content"
    end

    attribute :status, :atom do
      public? true
      constraints one_of: [:draft, :published]
    end

    attribute :view_count, :integer do
      public? true
      constraints min: 0
    end

    attribute :rating, :float do
      public? true
      constraints min: 0.0, max: 5.0
    end

    attribute :published_at, :utc_datetime, public?: true
    attribute :tags, {:array, :string}, public?: true
    attribute :metadata, :map, public?: true
    attribute :slug, :ci_string, public?: true
    attribute :duration, :time, public?: true
    attribute :local_time, :naive_datetime, public?: true
    attribute :attachment, :binary, public?: true
    attribute :config, :term, public?: true
    attribute :score, :decimal, public?: true
    attribute :external_id, :uuid_v7, public?: true
    attribute :priority, AshOaskit.Test.Priority, public?: true
    attribute :subject, AshOaskit.Test.Subject, public?: true

    attribute :is_featured, :boolean do
      public? true
      default false
    end

    attribute :email, :string do
      public? true
      constraints match: ~r/^[^\s]+@[^\s]+$/
    end

    # Deliberately non-public: must never appear in generated specs
    attribute :internal_notes, :string

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:title, :body, :status, :tags, :is_featured]
    end

    update :update do
      accept [:title, :body, :status, :tags, :is_featured]
    end
  end
end

defmodule AshOaskit.Test.NoDomainResource do
  @moduledoc false
  use Ash.Resource,
    data_layer: :embedded

  attributes do
    attribute :name, :string, public?: true
  end
end

# Resource with AshJsonApi extension but without explicit type (for nil type path testing)
defmodule AshOaskit.Test.NoTypeResource do
  @moduledoc false
  use Ash.Resource,
    domain: AshOaskit.Test.EdgeCaseDomain,
    extensions: [AshJsonApi.Resource]

  json_api do
    type "no-type-resource"
  end

  attributes do
    uuid_primary_key :id
    attribute :name, :string, public?: true
  end

  actions do
    defaults [:read]
  end
end

defmodule AshOaskit.Test.PhoneType do
  @moduledoc """
  Custom type module that implements `json_schema/1`.

  Used to test the `normalize_complex_type` path in `TypeMapper` where atom types
  with a `json_schema/1` callback get wrapped as `{:custom, schema}`.
  """

  def json_schema(_opts) do
    %{"type" => "string", "format" => "phone"}
  end
end

defmodule AshOaskit.Test.NilTypeResource do
  @moduledoc """
  Test resource with AshJsonApi extension but no explicit type set in the json_api block.

  When `AshJsonApi.Resource.Info.type/1` returns nil, the system falls back to
  `Macro.underscore/1` of the module name. This resource exercises that fallback
  path across several modules:

  - `Config.resource_type/1` — produces `"nil_type_resource"`
  - `FilterBuilder` — `derive_filter?/1` returns nil, defaults to true
  - `SortBuilder` — `derive_sort?/1` returns nil, defaults to true
  """
  use Ash.Resource,
    domain: AshOaskit.Test.EdgeCaseDomain,
    extensions: [AshJsonApi.Resource]

  json_api do
  end

  attributes do
    uuid_primary_key :id
    attribute :label, :string, public?: true
  end

  actions do
    defaults [:read]
  end
end

# Domain for edge case testing
defmodule AshOaskit.Test.EdgeCaseDomain do
  @moduledoc false
  use Ash.Domain,
    validate_config_inclusion?: false,
    extensions: [AshJsonApi.Domain]

  resources do
    resource AshOaskit.Test.NoTypeResource
    resource AshOaskit.Test.NilTypeResource
  end

  json_api do
    prefix "/edge"

    routes do
      base_route "/no-type", AshOaskit.Test.NoTypeResource do
        index :read
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
    type "comment"
  end

  attributes do
    uuid_primary_key :id
    attribute :content, :string, allow_nil?: false, public?: true

    # Deliberately public timestamps: must appear in generated specs
    create_timestamp :inserted_at, public?: true
    update_timestamp :updated_at, public?: true
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:content]
    end
  end
end

# Resource that declares its routes on the RESOURCE (classic ash_json_api
# style) — regression guard for resource-level route gathering
defmodule AshOaskit.Test.Gadget do
  @moduledoc false
  use Ash.Resource,
    domain: AshOaskit.Test.Workshop,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshJsonApi.Resource]

  json_api do
    type "gadget"

    routes do
      base "/gadgets"
      get :read
      index :read
      post :create
      route :post, "/:id/activate", :activate
      route :get, "/search", :search, query_params: [:query]
      route :post, "/recalibrate", :recalibrate, wrap_in_result?: true
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      public? true
      allow_nil? false
    end

    attribute :status, :atom do
      public? true
      constraints one_of: [:idle, :active]
      default :idle
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:name]
    end

    update :update do
      accept [:name, :status]
    end

    action :activate do
      argument :force, :boolean, default: false

      run fn _input, _context -> :ok end
    end

    action :search, {:array, :string} do
      argument :query, :string, allow_nil?: false

      run fn _input, _context -> {:ok, []} end
    end

    action :recalibrate, :integer do
      run fn _input, _context -> {:ok, 0} end
    end
  end
end

# Domain that ALSO declares routes for Gadget at the domain level —
# proves both sources merge without duplicating operations
defmodule AshOaskit.Test.Workshop do
  @moduledoc false
  use Ash.Domain,
    validate_config_inclusion?: false,
    extensions: [AshJsonApi.Domain]

  resources do
    resource AshOaskit.Test.Gadget
  end

  json_api do
    routes do
      base_route "/gadgets", AshOaskit.Test.Gadget do
        patch :update
        delete :destroy
      end
    end
  end
end

# Simple domain without AshJsonApi routes (for fallback testing)
defmodule AshOaskit.Test.SimpleDomain do
  @moduledoc false
  use Ash.Domain, validate_config_inclusion?: false

  resources do
    resource AshOaskit.Test.Post
    resource AshOaskit.Test.Comment
  end
end

# Domain with AshJsonApi extension and routes
defmodule AshOaskit.Test.Blog do
  @moduledoc false
  use Ash.Domain,
    validate_config_inclusion?: false,
    extensions: [AshJsonApi.Domain]

  resources do
    resource AshOaskit.Test.Post
    resource AshOaskit.Test.Comment
  end

  json_api do
    routes do
      base_route "/posts", AshOaskit.Test.Post do
        get :read
        index :read
        post :create
        patch :update
        delete :destroy
      end

      base_route "/comments", AshOaskit.Test.Comment do
        get :read
        index :read
        post :create
        delete :destroy
      end
    end
  end
end
