# Fixtures for :resource_scope option testing.
#
# The Scoped domain deliberately mixes three exposure shapes:
#
# - `Device`   - routed (full base_route) and related to Site
# - `Site`     - no routes, but referenced by Device's relationship, so
#                `:routed` scope must still emit its schemas (closure)
# - `AuditLog` - no routes and no inbound relationships: an internal
#                resource whose schemas/tag must drop under `:routed`

defmodule AshOaskit.Test.Scoped.Site do
  @moduledoc false
  use Ash.Resource,
    domain: AshOaskit.Test.Scoped,
    extensions: [AshJsonApi.Resource]

  json_api do
    type "site"
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      public? true
      allow_nil? false
    end
  end

  actions do
    defaults [:read]
  end
end

defmodule AshOaskit.Test.Scoped.Device do
  @moduledoc false
  use Ash.Resource,
    domain: AshOaskit.Test.Scoped,
    extensions: [AshJsonApi.Resource]

  json_api do
    type "device"

    includes [:site]
  end

  attributes do
    uuid_primary_key :id

    attribute :label, :string do
      public? true
      allow_nil? false
    end
  end

  relationships do
    belongs_to :site, AshOaskit.Test.Scoped.Site do
      public? true
    end
  end

  actions do
    defaults [:read]
  end
end

defmodule AshOaskit.Test.Scoped.AuditLog do
  @moduledoc false
  use Ash.Resource,
    domain: AshOaskit.Test.Scoped,
    extensions: [AshJsonApi.Resource]

  json_api do
    type "audit_log"
  end

  attributes do
    uuid_primary_key :id

    attribute :event, :string do
      public? true
      allow_nil? false
    end
  end

  actions do
    defaults [:read]
  end
end

defmodule AshOaskit.Test.Scoped do
  @moduledoc false
  use Ash.Domain,
    validate_config_inclusion?: false,
    extensions: [AshJsonApi.Domain]

  resources do
    resource AshOaskit.Test.Scoped.Device
    resource AshOaskit.Test.Scoped.Site
    resource AshOaskit.Test.Scoped.AuditLog
  end

  json_api do
    routes do
      base_route "/devices", AshOaskit.Test.Scoped.Device do
        get :read
        index :read
      end
    end
  end
end
