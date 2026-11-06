defmodule AshOaskit.Test.RequestContract.Address do
  @moduledoc false
  use Ash.Resource, data_layer: :embedded

  attributes do
    attribute :street, :string, allow_nil?: false, public?: true
    attribute :city, :string, allow_nil?: false, public?: true
  end

  actions do
    defaults [:read, create: :*, update: :*]

    create :from_city do
      accept [:city]
      change set_attribute(:street, "Default street")
    end

    update :move do
      accept [:city]
      require_attributes [:city]
    end
  end
end

defmodule AshOaskit.Test.RequestContract.CityAddress do
  @moduledoc false
  use Ash.Type.NewType,
    subtype_of: AshOaskit.Test.RequestContract.Address,
    constraints: [create_action: :from_city]
end

defmodule AshOaskit.Test.RequestContract.InputNode do
  @moduledoc false
  use Ash.Resource, data_layer: :embedded

  attributes do
    attribute :name, :string, public?: true, allow_nil?: false
    attribute :children, {:array, AshOaskit.Test.RequestContract.Address}, public?: true
  end
end

defmodule AshOaskit.Test.RequestContract.KeyedAddress do
  @moduledoc false
  use Ash.Resource, data_layer: :embedded

  attributes do
    uuid_primary_key :id, public?: true
    attribute :city, :string, public?: true, allow_nil?: false
  end
end

defmodule AshOaskit.Test.RequestContract.Owner do
  @moduledoc false
  use Ash.Resource,
    domain: AshOaskit.Test.RequestContract.Domain,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshJsonApi.Resource]

  json_api do
    type "owner"
  end

  actions do
    defaults [:read, create: [:name]]
  end

  attributes do
    uuid_primary_key :id
    attribute :name, :string, public?: true
  end
end

defmodule AshOaskit.Test.RequestContract.Item do
  @moduledoc false
  use Ash.Resource,
    domain: AshOaskit.Test.RequestContract.Domain,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshJsonApi.Resource]

  json_api do
    type "item"
    includes [:owner]

    routes do
      base "/items"
      get :read
      index :read
      post :create
      patch :update
      route :post, "/:id/archive", :archive
      # Non-generic PATCH: the `note` path param locates the record through the
      # read action. The update action gets its `note` argument from the body.
      patch :relabel, route: "/by_note/:note/relabel"
    end
  end

  actions do
    defaults [:read]

    create :create do
      primary? true
      accept [:name, :note, :address, :replacement, :addresses, :delivery, :loose]
      # `note` has allow_nil? true, but this action requires a value.
      require_attributes [:note]
    end

    update :update do
      primary? true
      accept [:name, :address, :replacement, :addresses, :delivery, :loose]
      require_atomic? false
    end

    update :relabel do
      accept []
      argument :note, :string, allow_nil?: false
      change set_attribute(:note, arg(:note))
    end

    update :require_note do
      accept [:note]
      require_attributes [:note]
    end

    action :archive, :boolean do
      argument :id, :uuid, allow_nil?: false
      argument :reason, :string, allow_nil?: false
      run fn _input, _context -> {:ok, true} end
    end
  end

  attributes do
    uuid_primary_key :id
    attribute :name, :string, allow_nil?: false, public?: true
    attribute :note, :string, public?: true
    attribute :address, AshOaskit.Test.RequestContract.Address, public?: true

    attribute :replacement, AshOaskit.Test.RequestContract.Address,
      public?: true,
      constraints: [on_update: :replace]

    attribute :addresses, {:array, AshOaskit.Test.RequestContract.Address}, public?: true

    attribute :delivery, AshOaskit.Test.RequestContract.Address,
      public?: true,
      constraints: [create_action: :from_city, update_action: :move]

    attribute :loose, AshOaskit.Test.RequestContract.Address,
      public?: true,
      constraints: [skip_unknown_inputs: [:*]]
  end

  relationships do
    belongs_to :owner, AshOaskit.Test.RequestContract.Owner, public?: true
  end
end

defmodule AshOaskit.Test.RequestContract.Domain do
  @moduledoc false
  use Ash.Domain, validate_config_inclusion?: false, extensions: [AshJsonApi.Domain]

  resources do
    resource AshOaskit.Test.RequestContract.Item
    resource AshOaskit.Test.RequestContract.Owner
  end
end

defmodule AshOaskit.Test.RequestContract.Router do
  @moduledoc false
  use AshJsonApi.Router, domains: [AshOaskit.Test.RequestContract.Domain]
end
