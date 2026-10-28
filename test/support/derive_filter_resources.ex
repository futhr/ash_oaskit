defmodule AshOaskit.Test.Kennel.Owner do
  @moduledoc false
  use Ash.Resource,
    domain: AshOaskit.Test.Kennel,
    extensions: [AshJsonApi.Resource]

  json_api do
    type "owner"
    derive_filter? false
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string, public?: true
  end

  actions do
    defaults [:read]
  end
end

defmodule AshOaskit.Test.Kennel.Pet do
  @moduledoc false
  use Ash.Resource,
    domain: AshOaskit.Test.Kennel,
    extensions: [AshJsonApi.Resource]

  json_api do
    type "pet"
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string, public?: true
  end

  relationships do
    belongs_to :owner, AshOaskit.Test.Kennel.Owner do
      public? true
    end
  end

  actions do
    defaults [:read]
  end
end

defmodule AshOaskit.Test.Kennel do
  @moduledoc false
  use Ash.Domain,
    validate_config_inclusion?: false,
    extensions: [AshJsonApi.Domain]

  resources do
    resource AshOaskit.Test.Kennel.Owner
    resource AshOaskit.Test.Kennel.Pet
  end

  json_api do
    routes do
      base_route "/owners", AshOaskit.Test.Kennel.Owner do
        index :read
      end

      base_route "/pets", AshOaskit.Test.Kennel.Pet do
        index :read
      end
    end
  end
end
