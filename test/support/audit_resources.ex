defmodule AshOaskit.Test.Another.Address do
  @moduledoc false
  use Ash.Resource, data_layer: :embedded

  attributes do
    attribute :different, :integer, public?: true
  end
end

defmodule AshOaskit.Test.ShippingInfo do
  @moduledoc false
  use Ash.Resource, data_layer: :embedded

  attributes do
    attribute :address, AshOaskit.Test.Address, public?: true, allow_nil?: false
  end
end

defmodule AshOaskit.Test.WrappedShippingInfo do
  @moduledoc false
  use Ash.Type.NewType, subtype_of: AshOaskit.Test.ShippingInfo
end

defmodule AshOaskit.Test.SchemaAuditResource do
  @moduledoc false
  use Ash.Resource, domain: nil, extensions: [AshJsonApi.Resource]

  json_api do
    type "schema-audit"

    routes do
      base "/schema-audit"
      post :create
      post :create, route: "/:label"
      post :relate, route: "/relate", relationship_arguments: [{:id, :author}, :tags]
      route :get, "/shipping", :shipping
    end
  end

  attributes do
    uuid_primary_key :id
  end

  actions do
    create :create do
      accept []
      argument :shipping, AshOaskit.Test.WrappedShippingInfo, allow_nil?: false
      argument :label, :string, allow_nil?: false
      argument :mode, :string, allow_nil?: false, default: "standard"
    end

    create :relate do
      accept []
      argument :author, :uuid, allow_nil?: false
      argument :tags, {:array, :map}, allow_nil?: false, default: []
    end

    action :shipping, {:array, AshOaskit.Test.ShippingInfo} do
      run fn _, _ -> {:ok, []} end
    end
  end
end

defmodule AshOaskit.Test.SchemaAuditDomain do
  @moduledoc false
  use Ash.Domain, extensions: [AshJsonApi.Domain], validate_config_inclusion?: false

  resources do
    resource AshOaskit.Test.SchemaAuditResource
  end
end
