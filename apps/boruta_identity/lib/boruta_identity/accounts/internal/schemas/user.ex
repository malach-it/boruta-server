defmodule BorutaIdentity.Accounts.Internal.User do
  @moduledoc false

  use Ecto.Schema

  import Ecto.Changeset

  alias BorutaIdentity.IdentityProviders.Backend

  @type t :: %__MODULE__{
          email: String.t(),
          password: String.t(),
          hashed_password: String.t(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  @derive {Inspect, except: [:password]}
  @primary_key {:id, Ecto.UUID, autogenerate: true}
  @foreign_key_type Ecto.UUID
  schema "internal_users" do
    field(:email, :string)
    field(:password, :string, virtual: true)
    field(:hashed_password, :string)

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
  def registration_changeset(user, attrs, %{backend: _backend} = opts) do
    user
    |> cast(attrs, [:email, :password])
    |> validate_required([:email, :password])
    |> validate_email()
    |> validate_password(opts)
  end

  defp validate_email(changeset) do
    changeset
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
    |> validate_length(:email, max: 160)
    |> unsafe_validate_unique(:email, BorutaIdentity.Repo)
    |> unique_constraint(:email)
  end

  defp validate_password(changeset, opts) do
    changeset
    |> validate_length(:password, min: 12, max: 80)
    # |> validate_format(:password, ~r/[a-z]/, message: "at least one lower case character")
    # |> validate_format(:password, ~r/[A-Z]/, message: "at least one upper case character")
    # |> validate_format(:password, ~r/[!?@#$%^&*_0-9]/, message: "at least one digit or punctuation character")
    |> maybe_hash_password(opts)
  end

  defp maybe_hash_password(changeset, opts) do
    hash_password? = Map.get(opts, :hash_password, true)
    backend = Map.get(opts, :backend)
    password = get_change(changeset, :password)

    if hash_password? && password && changeset.valid? do
      changeset
      |> put_change(
        :hashed_password,
        apply(Backend.password_hashing_module(backend), :hash_pwd_salt, [
          password,
          Backend.password_hashing_opts(backend)
        ])
      )
      |> delete_change(:password)
    else
      changeset
    end
  end

  def update_changeset(user, attrs, opts \\ %{}) do
    user
    |> cast(attrs, [:email, :password])
    |> validate_email()
    |> validate_password(opts)
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
  def password_changeset(user, attrs, opts \\ %{}) do
    user
    |> cast(attrs, [:password])
    |> validate_confirmation(:password, message: "does not match password")
    |> validate_password(opts)
  end

  def valid_password?(backend, %__MODULE__{hashed_password: hashed_password}, password)
      when is_binary(hashed_password) and byte_size(password) > 0 do
    apply(
      Backend.password_hashing_module(backend),
      :verify_pass,
      [password, hashed_password]
    )
  rescue
    _ -> false
  end

  def valid_password?(backend, _, _) do
    apply(
      Backend.password_hashing_module(backend),
      :no_user_verify,
      []
    )
    false
  rescue
    _ -> false
  end

  @doc """
  Validates the current password otherwise adds an error to the changeset.
  """
  def validate_current_password(backend, changeset, password) do
    if valid_password?(backend, changeset.data, password) do
      changeset
    else
      add_error(changeset, :current_password, "is not valid")
    end
  end
end
