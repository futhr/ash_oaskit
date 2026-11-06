defmodule AshOaskit.Test.SensitiveDefaultsResource do
  @moduledoc false

  use Ash.Resource, domain: nil, extensions: [AshJsonApi.Resource]

  json_api do
    type "sensitive-defaults"

    routes do
      base "/sensitive-defaults"
      post :create
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :label, :string do
      public? true
      default "ordinary-default"
    end

    attribute :credential, :string do
      public? true
      sensitive? true
      default "synthetic-attribute-secret"
      constraints min_length: 8
    end

    attribute :internal_note, :string do
      public? false
      default "synthetic-private-default"
    end
  end

  actions do
    create :create do
      accept [:label, :credential]

      argument :password, :string do
        sensitive? true
        default "synthetic-argument-secret"
        constraints min_length: 8
      end
    end
  end
end

defmodule AshOaskit.Test.SensitiveDefaultsDomain do
  @moduledoc false

  use Ash.Domain, extensions: [AshJsonApi.Domain], validate_config_inclusion?: false

  resources do
    resource AshOaskit.Test.SensitiveDefaultsResource
  end
end
