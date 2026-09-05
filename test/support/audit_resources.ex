defmodule AshOaskit.Test.Another.Address do
  @moduledoc false
  use Ash.Resource, data_layer: :embedded

  attributes do
    attribute :different, :integer, public?: true
  end
end
