defmodule BorutaIdentity.Accounts.User do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias BorutaIdentity.Accounts.Consent
  alias BorutaIdentity.Accounts.UserAuthorizedScope
  alias BorutaIdentity.Repo

  @type t :: %__MODULE__{
          username: String.t(),
          password: String.t(),
          confirmed_at: NaiveDateTime.t(),
          authorized_scopes: Ecto.Association.NotLoaded.t() | list(UserAuthorizedScope.t()),
          consents: Ecto.Association.NotLoaded.t() | list(Consent.t()),
          last_login_at: DateTime.t(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  @derive {Inspect, except: [:password]}
  @primary_key {:id, Ecto.UUID, autogenerate: true}
  @foreign_key_type Ecto.UUID
  schema "users" do
    # TODO add email field
    field(:username, :string)
    field(:provider, :string)
    field(:uid, :string)
    field(:password, :string, virtual: true)
    field(:confirmed_at, :utc_datetime_usec)
    field(:last_login_at, :utc_datetime_usec)

    has_many(:authorized_scopes, UserAuthorizedScope)
    has_many(:consents, Consent, on_replace: :delete)

    timestamps()
  end

  def implementation_changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, [:provider, :uid, :username])
    |> validate_required([:provider, :uid, :username])
  end

  def login_changeset(user) do
    user
    |> change(last_login_at: DateTime.utc_now())
    |> validate_required([:provider])
  end

  @doc """
  Confirms the account by setting `confirmed_at`.
  """
  def confirm_changeset(user) do
    now = DateTime.utc_now()
    change(user, confirmed_at: now)
  end

  def consent_changeset(user, attrs) do
    user
    |> Repo.preload(:consents)
    |> cast(attrs, [])
    |> cast_assoc(:consents, with: &Consent.changeset/2)
  end

  def confirmed?(%__MODULE__{confirmed_at: nil}), do: false
  def confirmed?(%__MODULE__{confirmed_at: _confirmed_at}), do: true
end
