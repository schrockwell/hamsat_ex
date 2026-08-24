defmodule Hamsat.Accounts.PushSubscription do
  use Hamsat, :schema

  alias Hamsat.Accounts.User

  schema "push_subscriptions" do
    belongs_to :user, User
    field :endpoint, :string
    field :p256dh, :string
    field :auth, :string

    timestamps()
  end

  def changeset(%User{} = user, attrs) do
    %__MODULE__{user_id: user.id}
    |> cast(attrs, [:endpoint, :p256dh, :auth])
    |> validate_required([:endpoint, :p256dh, :auth])
    |> unique_constraint([:user_id, :endpoint])
  end

  @doc "The map shape `Hamsat.Push.WebPush.send_notification/2` expects."
  def to_web_push(%__MODULE__{} = sub) do
    %{"endpoint" => sub.endpoint, "keys" => %{"p256dh" => sub.p256dh, "auth" => sub.auth}}
  end
end
