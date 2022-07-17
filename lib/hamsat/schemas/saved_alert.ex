defmodule Hamsat.Schemas.SavedAlert do
  use Ecto.Schema
  import Ecto.Changeset

  alias Hamsat.Schemas.Alert
  alias Hamsat.Accounts.User

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "saved_alerts" do
    belongs_to :alert, Alert
    belongs_to :user, User

    timestamps()
  end

  def changeset(%User{} = user, %Alert{} = alert) do
    %__MODULE__{user_id: user.id, alert_id: alert.id}
    |> change()
    |> unique_constraint([:user_id, :alert_id])
  end
end
