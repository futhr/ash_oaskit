# KitchenSink test resources for edge-case coverage
#
# These resources exercise types and features NOT covered by the existing
# test_resources.ex and relationship_resources.ex, specifically:
#
# - Deeply nested embedded resources (3+ levels)
# - Array of embedded resources
# - Union types as attributes (via Ash.Type.NewType)
# - Read-only attributes (writable?: false) — excluded from input schemas
# - DurationName type in a real resource
# - Custom type with json_schema/1 callback in a real resource

# ===========================================================================
# Custom Union Type (Ash.Type.NewType-style with constraints/0)
# ===========================================================================

defmodule AshOaskit.Test.ContentBlock do
  @moduledoc """
  Union type representing different content block types.

  Exercises the `{:union, types}` path in TypeMapper when used as
  an attribute type in a real resource.
  """
  use Ash.Type.NewType,
    subtype_of: :union,
    constraints: [
      types: [
        text: [
          type: :string,
          tag: :type,
          tag_value: :text
        ],
        image: [
          type: :map,
          tag: :type,
          tag_value: :image
        ],
        code: [
          type: :string,
          tag: :type,
          tag_value: :code
        ]
      ]
    ]
end

# ===========================================================================
# Custom type with json_schema/1 callback
# ===========================================================================

defmodule AshOaskit.Test.Coordinate do
  @moduledoc """
  Custom type that implements json_schema/1 for OpenAPI generation.

  Returns an object schema with latitude/longitude properties.
  """
  use Ash.Type

  @impl Ash.Type
  def storage_type(_), do: :map

  @impl Ash.Type
  def cast_input(nil, _), do: {:ok, nil}
  def cast_input(%{"lat" => _, "lng" => _} = value, _), do: {:ok, value}
  def cast_input(_, _), do: :error

  @impl Ash.Type
  def cast_stored(nil, _), do: {:ok, nil}
  def cast_stored(value, _), do: {:ok, value}

  @impl Ash.Type
  def dump_to_native(nil, _), do: {:ok, nil}
  def dump_to_native(value, _), do: {:ok, value}

  def json_schema(_opts) do
    %{
      "type" => "object",
      "properties" => %{
        "lat" => %{"type" => "number", "minimum" => -90, "maximum" => 90},
        "lng" => %{"type" => "number", "minimum" => -180, "maximum" => 180}
      },
      "required" => ["lat", "lng"]
    }
  end
end

# ===========================================================================
# Deeply Nested Embedded Resources (3+ levels)
# ===========================================================================

defmodule AshOaskit.Test.GeoPoint do
  @moduledoc "Level 3: deepest embedded resource (lat/lng)."
  use Ash.Resource, data_layer: :embedded

  attributes do
    attribute :lat, :float do
      allow_nil? false
      constraints min: -90.0, max: 90.0
    end

    attribute :lng, :float do
      allow_nil? false
      constraints min: -180.0, max: 180.0
    end
  end
end

defmodule AshOaskit.Test.Location do
  @moduledoc "Level 2: contains a GeoPoint (nested embedded)."
  use Ash.Resource, data_layer: :embedded

  attributes do
    attribute :label, :string do
      allow_nil? false
    end

    attribute :geo, AshOaskit.Test.GeoPoint do
      allow_nil? false
      description "Geographic coordinates"
    end
  end
end

defmodule AshOaskit.Test.Venue do
  @moduledoc "Level 1: contains a Location (2 levels of nesting beneath it)."
  use Ash.Resource, data_layer: :embedded

  attributes do
    attribute :name, :string do
      allow_nil? false
    end

    attribute :location, AshOaskit.Test.Location do
      allow_nil? false
      description "Venue location with coordinates"
    end

    attribute :capacity, :integer do
      constraints min: 1
    end
  end
end

# ===========================================================================
# Main KitchenSink Resource
# ===========================================================================

defmodule AshOaskit.Test.KitchenSink do
  @moduledoc """
  Resource that exercises every edge-case type and attribute option.

  Covers gaps identified in test resource analysis:
  - Union type attribute (ContentBlock)
  - Custom type with json_schema/1 (Coordinate)
  - Deeply nested embedded (Venue → Location → GeoPoint, 3 levels)
  - Array of embedded resources
  - Read-only attribute (slug) — should appear in output, NOT in input
  - DurationName type attribute
  """
  use Ash.Resource,
    domain: AshOaskit.Test.Lab,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshJsonApi.Resource]

  json_api do
    type "kitchen-sink"
  end

  attributes do
    uuid_primary_key :id

    # --- Standard types already covered elsewhere, but needed for a valid resource ---
    attribute :name, :string do
      allow_nil? false
      constraints min_length: 1, max_length: 200
    end

    # --- Union type attribute ---
    attribute :content, AshOaskit.Test.ContentBlock do
      description "Polymorphic content block (text, image, or code)"
    end

    # --- Custom type with json_schema/1 ---
    attribute :coordinates, AshOaskit.Test.Coordinate do
      description "Geographic coordinates via custom type"
    end

    # --- Deeply nested embedded (3 levels) ---
    attribute :venue, AshOaskit.Test.Venue do
      description "Event venue with nested location and geo point"
    end

    # --- Array of embedded resources ---
    attribute :locations, {:array, AshOaskit.Test.Location} do
      description "Multiple locations with coordinates"
    end

    # --- DurationName type ---
    attribute :billing_unit, :duration_name do
      description "Billing time unit"
    end

    # --- Read-only attribute (in output but NOT in input schemas) ---
    attribute :slug, :string do
      writable? false
      description "Auto-generated URL slug"
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [
        :name,
        :content,
        :coordinates,
        :venue,
        :locations,
        :billing_unit
      ]
    end

    update :update do
      accept [:name, :content, :coordinates, :venue, :locations, :billing_unit]
    end
  end
end

# ===========================================================================
# Domain
# ===========================================================================

defmodule AshOaskit.Test.Lab do
  @moduledoc """
  Domain for KitchenSink edge-case testing.
  """
  use Ash.Domain,
    validate_config_inclusion?: false,
    extensions: [AshJsonApi.Domain]

  resources do
    resource AshOaskit.Test.KitchenSink
  end

  json_api do
    routes do
      base_route "/kitchen-sinks", AshOaskit.Test.KitchenSink do
        get :read
        index :read
        post :create
        patch :update
        delete :destroy
      end
    end
  end
end
