defmodule Hamsat.Schemas.ChatMessage do
  use Hamsat, :schema

  alias Hamsat.Accounts.User
  alias Hamsat.Schemas.Alert
  alias Hamsat.Alerts.Chat

  schema "chat_messages" do
    belongs_to :alert, Alert
    belongs_to :user, User

    field :body, :string

    timestamps()
  end

  def changeset(%__MODULE__{} = message, params \\ %{}) do
    message
    |> cast(params, [:body])
    |> update_change(:body, &String.trim/1)
    |> validate_required([:body])
    |> validate_length(:body, max: 200)
  end

  def sender_name(%__MODULE__{user: %User{} = user}), do: Chat.username(user)
end
