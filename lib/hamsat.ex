defmodule Hamsat do
  @moduledoc """
  Hamsat keeps the contexts that define your domain
  and business logic.

  Contexts are also responsible for managing your data, regardless
  if it comes from the database, an external API or others.
  """

  defmacro __using__(:schema) do
    quote do
      use Ecto.Schema
      import Ecto.Changeset

      @primary_key {:id, :binary_id, autogenerate: true}
      @foreign_key_type :binary_id
      @timestamps_opts [type: :utc_datetime]
    end
  end

  defmacro __using__(:repo) do
    quote do
      import Ecto
      import Ecto.Query
      import Ecto.Changeset

      alias Hamsat.Repo
    end
  end
end
