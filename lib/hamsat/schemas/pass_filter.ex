defmodule Hamsat.Schemas.PassFilter do
  use Hamsat, :schema

  alias Hamsat.Accounts.User

  schema "pass_filters" do
    belongs_to :user, User

    field :digital_mod, :boolean, default: true
    field :fm_mod, :boolean, default: true
    field :linear_mod, :boolean, default: true
    field :min_el, :integer, default: 0

    timestamps()
  end

  @doc false
  def changeset(pass_filter, attrs) do
    pass_filter
    |> cast(attrs, [:digital_mod, :fm_mod, :linear_mod, :min_el])
    |> validate_required([:digital_mod, :fm_mod, :linear_mod, :min_el])
    |> validate_number(:min_el, greater_than_or_equal_to: 0, less_than_or_equal_to: 90)
  end
end
