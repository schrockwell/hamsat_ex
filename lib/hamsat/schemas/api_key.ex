defmodule Hamsat.Schemas.APIKey do
  use Hamsat, :schema

  schema "api_keys" do
    field :enabled, :boolean, default: true
    field :description, :string

    timestamps()
  end
end
