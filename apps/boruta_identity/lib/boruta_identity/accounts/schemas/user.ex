defmodule BorutaIdentity.Accounts.User do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias BorutaIdentity.Accounts.Consent
  alias BorutaIdentity.Accounts.UserAuthorizedScope
  alias BorutaIdentity.IdentityProviders.Backend
  alias BorutaIdentity.Repo

  @type t :: %__MODULE__{
          username: String.t(),
          password: String.t(),
          confirmed_at: NaiveDateTime.t() | nil,
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
    field(:uid, :string)
    field(:password, :string, virtual: true)
    field(:confirmed_at, :utc_datetime_usec)
    field(:last_login_at, :utc_datetime_usec)
    field(:metadata, :map, default: %{})

    has_many(:authorized_scopes, UserAuthorizedScope)
    has_many(:consents, Consent, on_replace: :delete)
    belongs_to(:backend, Backend)

    timestamps()
  end

  def implementation_changeset(attrs, backend) do
    %__MODULE__{}
    |> cast(attrs, [:backend_id, :uid, :username, :metadata])
    |> metadata_template_filter(backend)
    |> validate_required([:backend_id, :uid, :username])
  end

  def changeset(user, attrs \\ %{}) do
    user
    |> cast(attrs, [:metadata])
  end

  def login_changeset(user) do
    user
    |> change(last_login_at: DateTime.utc_now())
    |> validate_required([:backend_id])
  end

  @doc """
  Confirms the account by setting `confirmed_at`.
  """
  def confirm_changeset(user) do
    now = DateTime.utc_now()
    change(user, confirmed_at: now)
  end

  @doc """
  Reset confirmation of the account by unsetting `confirmed_at`.
  """
  def unconfirm_changeset(user) do
    change(user, confirmed_at: nil)
  end

  def consent_changeset(user, attrs) do
    user
    |> Repo.preload(:consents)
    |> cast(attrs, [])
    |> cast_assoc(:consents, with: &Consent.changeset/2)
  end

  def confirmed?(%__MODULE__{confirmed_at: nil}), do: false
  def confirmed?(%__MODULE__{confirmed_at: _confirmed_at}), do: true

  def metadata_filter(metadata, %Backend{
        metadata_fields: metadata_fields
      }) do
    Enum.reduce(metadata, %{}, fn {key, value}, acc ->
      attribute_names =
        Enum.map(metadata_fields, fn %{"attribute_name" => attribute_name} -> attribute_name end)

      case Enum.member?(attribute_names, key) do
        true ->
          Map.put(acc, key, value)

        false ->
          acc
      end
    end)
  end

  defp metadata_template_filter(
         %Ecto.Changeset{changes: %{metadata: %{} = metadata}} = changeset,
         backend
       )
       when not (map_size(metadata) == 0) do
    put_change(changeset, :metadata, metadata_filter(metadata, backend))
  end

  defp metadata_template_filter(changeset, _backend), do: changeset
end
