defmodule Hamsat.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset
  import Hamsat.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "users" do
    field :email, :string
    field :password, :string, virtual: true, redact: true
    field :hashed_password, :string, redact: true
    field :confirmed_at, :naive_datetime

    field :home_lat, :float
    field :home_lon, :float
    field :timezone, :string, default: "Etc/UTC"
    field :time_format, :string, default: "24h"
    field :latest_callsign, :string
    field :latest_modes, {:array, :string}
    field :latest_mhz_direction, Ecto.Enum, values: [:up, :down]
    field :prefer_ssb_mode, :integer
    field :prefer_data_mode, :integer
    field :prefer_cw_mode, :integer
    field :prefer_fm_mode, :integer
    field :prefer_dx_el, :integer
    field :prefer_my_el, :integer

    has_many :alerts, Hamsat.Schemas.Alert
    has_many :saved_alerts, Hamsat.Schemas.SavedAlert

    has_one :pass_filter, Hamsat.Schemas.PassFilter

    # Needed for the LocationPicker on the user registration form
    field :home_grid, :string, virtual: true

    timestamps()
  end

  @doc """
  A user changeset for registration.

  It is important to validate the length of both email and password.
  Otherwise databases may truncate the email without warnings, which
  could lead to unpredictable or insecure behaviour. Long passwords may
  also be very expensive to hash for certain algorithms.

  ## Options

    * `:hash_password` - Hashes the password so it can be stored securely
      in the database and ensures the password field is cleared to prevent
      leaks in the logs. If password hashing is not needed and clearing the
      password field is not desired (like when using this changeset for
      validations on a LiveView form), this option can be set to `false`.
      Defaults to `true`.
  """
  def registration_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:email, :password, :home_lat, :home_lon])
    |> validate_email(opts)
    |> validate_password(opts)
    |> validate_home_location()
  end

  defp validate_email(changeset, opts \\ []) do
    changeset
    |> validate_required([:email])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
    |> validate_length(:email, max: 160)
    |> maybe_validate_email_uniqueness(opts)
    |> unique_constraint(:email)
  end

  defp maybe_validate_email_uniqueness(changeset, opts) do
    if opts[:repo] do
      unsafe_validate_unique(changeset, :email, opts[:repo])
    else
      changeset
    end
  end

  defp validate_password(changeset, opts) do
    changeset
    |> validate_required([:password])
    |> validate_length(:password, min: 8, max: 72)
    # |> validate_format(:password, ~r/[a-z]/, message: "at least one lower case character")
    # |> validate_format(:password, ~r/[A-Z]/, message: "at least one upper case character")
    # |> validate_format(:password, ~r/[!?@#$%^&*_0-9]/, message: "at least one digit or punctuation character")
    |> maybe_hash_password(opts)
  end

  defp maybe_hash_password(changeset, opts) do
    hash_password? = Keyword.get(opts, :hash_password, true)
    password = get_change(changeset, :password)

    if hash_password? && password && changeset.valid? do
      changeset
      # If using Bcrypt, then further validate it is at most 72 bytes long
      |> validate_length(:password, max: 72, count: :bytes)
      |> put_change(:hashed_password, Bcrypt.hash_pwd_salt(password))
      |> delete_change(:password)
    else
      changeset
    end
  end

  @doc """
  A user changeset for changing the email.

  It requires the email to change otherwise an error is added.
  """
  def email_changeset(user, attrs) do
    user
    |> cast(attrs, [:email])
    |> validate_email()
    |> case do
      %{changes: %{email: _}} = changeset -> changeset
      %{} = changeset -> add_error(changeset, :email, "did not change")
    end
  end

  @doc """
  A user changeset for changing the password.

  ## Options

    * `:hash_password` - Hashes the password so it can be stored securely
      in the database and ensures the password field is cleared to prevent
      leaks in the logs. If password hashing is not needed and clearing the
      password field is not desired (like when using this changeset for
      validations on a LiveView form), this option can be set to `false`.
      Defaults to `true`.
  """
  def password_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:password])
    |> validate_confirmation(:password, message: "does not match password")
    |> validate_password(opts)
  end

  @doc """
  Confirms the account by setting `confirmed_at`.
  """
  def confirm_changeset(user) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    change(user, confirmed_at: now)
  end

  @doc """
  Verifies the password.

  If there is no user or the user doesn't have a password, we call
  `Bcrypt.no_user_verify/0` to avoid timing attacks.
  """
  def valid_password?(%Hamsat.Accounts.User{hashed_password: hashed_password}, password)
      when is_binary(hashed_password) and byte_size(password) > 0 do
    Bcrypt.verify_pass(password, hashed_password)
  end

  def valid_password?(_, _) do
    Bcrypt.no_user_verify()
    false
  end

  @doc """
  Validates the current password otherwise adds an error to the changeset.
  """
  def validate_current_password(changeset, password) do
    if valid_password?(changeset.data, password) do
      changeset
    else
      add_error(changeset, :current_password, "is not valid")
    end
  end

  def home_location_changeset(user, attrs) do
    user
    |> cast(attrs, [:home_lat, :home_lon, :timezone, :time_format])
    |> validate_required([:home_lat, :home_lon, :timezone, :time_format])
    |> validate_home_location()
    |> validate_inclusion(:timezone, Tzdata.zone_list())
  end

  defp validate_home_location(changeset) do
    changeset
    |> validate_required([:home_lat, :home_lon])
    |> validate_number(:home_lat, greater_than_or_equal_to: -90, less_than_or_equal_to: 90)
    |> validate_number(:home_lon, greater_than_or_equal_to: -180, less_than_or_equal_to: 180)
  end

  def alert_preferences_changeset(user, alert) do
    # Reorder latest_modes, putting this alert's mode at the front of the list
    new_latest_modes = Enum.uniq([alert.mode | user.latest_modes])

    user
    |> change(
      latest_callsign: alert.callsign,
      latest_modes: new_latest_modes,
      latest_mhz_direction: alert.mhz_direction
    )
    |> format_callsign(:latest_callsign)
  end

  def match_preferences_changeset(user, params \\ %{}) do
    user
    |> cast(params, [
      :prefer_cw_mode,
      :prefer_ssb_mode,
      :prefer_data_mode,
      :prefer_fm_mode,
      :prefer_dx_el,
      :prefer_my_el
    ])
    |> validate_percentage(:prefer_cw_mode)
    |> validate_percentage(:prefer_ssb_mode)
    |> validate_percentage(:prefer_data_mode)
    |> validate_percentage(:prefer_fm_mode)
    |> validate_elevation(:prefer_dx_el)
    |> validate_elevation(:prefer_my_el)
  end

  defp validate_percentage(changeset, field) do
    changeset
    |> validate_number(field, greater_than_or_equal_to: 0)
    |> validate_number(field, less_than_or_equal_to: 100)
  end

  defp validate_elevation(changeset, field) do
    changeset
    |> validate_number(field, greater_than_or_equal_to: 0)
    |> validate_number(field, less_than_or_equal_to: 90)
  end
end
