defmodule BorutaIdentity.Accounts.User do
  @moduledoc false

  defmodule CoseKey do
    @moduledoc false

    @behaviour Ecto.Type

    def type, do: :binary
    def cast(bin), do: {:ok, Base.decode64!(bin) |> :erlang.binary_to_term()}
    def load(bin), do: {:ok, Base.decode64!(bin) |> :erlang.binary_to_term()}
    def dump(bin), do: {:ok, :erlang.term_to_binary(bin) |> Base.encode64()}
    def equal?(a, b), do: a == b
    def embed_as(_a), do: :self
  end

  use Ecto.Schema
  import Ecto.Changeset

  alias BorutaIdentity.Accounts.Consent
  alias BorutaIdentity.Accounts.UserAuthorizedScope
  alias BorutaIdentity.Accounts.UserRole
  alias BorutaIdentity.IdentityProviders.Backend
  alias BorutaIdentity.Organizations.OrganizationUser
  alias BorutaIdentity.Repo

  @type t :: %__MODULE__{
          id: String.t() | nil,
          uid: String.t() | nil,
          username: String.t() | nil,
          password: String.t() | nil,
          metadata: map(),
          federated_metadata: map(),
          totp_secret: String.t() | nil,
          webauthn_challenge: String.t() | nil,
          confirmed_at: DateTime.t() | nil,
          authorized_scopes: Ecto.Association.NotLoaded.t() | list(UserAuthorizedScope.t()),
          consents: Ecto.Association.NotLoaded.t() | list(Consent.t()),
          backend: Ecto.Association.NotLoaded.t() | Backend.t(),
          backend_id: String.t() | nil,
          last_login_at: DateTime.t() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  def account_types, do: [
    BorutaIdentity.Accounts.Federated.account_type(),
    BorutaIdentity.Accounts.Internal.account_type(),
    BorutaIdentity.Accounts.Ldap.account_type()
  ]

  @derive {Inspect, except: [:password]}
  @primary_key {:id, Ecto.UUID, autogenerate: true}
  @foreign_key_type Ecto.UUID
  schema "users" do
    # TODO add email field
    field(:username, :string)
    field(:uid, :string)
    field(:group, :string)
    field(:password, :string, virtual: true)
    field(:confirmed_at, :utc_datetime_usec)
    field(:last_login_at, :utc_datetime_usec)
    field(:metadata, :map, default: %{})
    field(:federated_metadata, :map, default: %{})
    field(:totp_secret, :string)
    field(:totp_registered_at, :utc_datetime_usec)
    field(:webauthn_challenge, :string)
    field(:webauthn_identifier, :string)
    field(:webauthn_public_key, CoseKey)
    field(:webauthn_registered_at, :utc_datetime_usec)
    field(:account_type, :string)

    has_many(:authorized_scopes, UserAuthorizedScope)
    has_many(:roles, UserRole)
    has_many(:organizations, OrganizationUser)
    has_many(:consents, Consent, on_replace: :delete)
    belongs_to(:backend, Backend)

    timestamps()
  end

  def implementation_changeset(attrs, backend) do
    %__MODULE__{}
    |> cast(attrs, [
      :backend_id,
      :uid,
      :username,
      :group,
      :metadata,
      :federated_metadata,
      :account_type
    ])
    |> metadata_template_filter(backend)
    |> validate_required([:backend_id, :uid, :username, :account_type])
    |> validate_inclusion(:account_type, account_types())
    |> validate_group()
  end

  def changeset(user, attrs \\ %{}) do
    user
    |> cast(attrs, [:metadata, :group])
    |> validate_group()
  end

  def login_changeset(user) do
    user
    |> change(last_login_at: DateTime.utc_now())
    |> validate_required([:backend_id])
  end

  def confirm_changeset(user) do
    now = DateTime.utc_now()
    change(user, confirmed_at: now)
  end

  def unconfirm_changeset(user) do
    change(user, confirmed_at: nil)
  end

  def webauthn_challenge_changeset(user) do
    change(user, webauthn_challenge: SecureRandom.hex())
  end

  def webauthn_public_key_changeset(user, cose_key, identifier) do
    change(user,
      webauthn_public_key: cose_key,
      webauthn_registered_at: DateTime.utc_now(),
      webauthn_identifier: identifier
    )
  end

  def totp_changeset(user, totp_secret) do
    change(user, totp_secret: totp_secret, totp_registered_at: DateTime.utc_now())
  end

  def consent_changeset(user, attrs) do
    user
    |> Repo.preload(:consents)
    |> cast(attrs, [])
    |> cast_assoc(:consents, with: &Consent.changeset/2)
  end

  def confirmed?(%__MODULE__{confirmed_at: nil}), do: false
  def confirmed?(%__MODULE__{confirmed_at: _confirmed_at}), do: true

  @spec metadata_filter(metadata :: map(), backend :: Backend.t()) :: metadata :: map()
  def metadata_filter(metadata, %Backend{
        metadata_fields: metadata_fields
      }) do
    Enum.filter(metadata, fn {key, _value} ->
      attribute_names =
        Enum.map(metadata_fields, fn %{"attribute_name" => attribute_name} -> attribute_name end)

      Enum.member?(attribute_names, key)
    end)
    |> Enum.into(%{})
  end

  @spec user_metadata_filter(user :: t(), metadata :: map(), backend :: Backend.t()) ::
          metadata :: map()
  def user_metadata_filter(
        %__MODULE__{metadata: user_metadata},
        metadata,
        %Backend{metadata_fields: metadata_fields} = backend
      ) do
    metadata = metadata_filter(metadata, backend)

    metadata_fields
    |> Enum.map(fn field ->
      attribute_name = field["attribute_name"]
      user_editable = field["user_editable"]

      case Enum.find(metadata, fn {key, _value} ->
             attribute_name == key
           end) do
        {key, _value} = field ->
          case user_editable do
            true -> field
            _ -> {attribute_name, user_metadata[key]}
          end

        nil ->
          {attribute_name, user_metadata[attribute_name]}
      end
    end)
    |> Enum.reject(fn
      {_key, nil} -> true
      nil -> true
      _ -> false
    end)
    |> Enum.map(fn {key, value} ->
      {key, %{value: value, status: "valid"}}
    end)
    |> Enum.into(%{})
  end

  # TODO check metadata schema
  defp metadata_template_filter(
         %Ecto.Changeset{changes: %{metadata: %{} = metadata}} = changeset,
         backend
       )
       when not (map_size(metadata) == 0) do
    put_change(changeset, :metadata, metadata_filter(metadata, backend))
  end

  defp metadata_template_filter(changeset, _backend), do: changeset

  defp validate_group(changeset) do
    case Ecto.Changeset.get_change(changeset, :group) do
      nil ->
        changeset

      group ->
        groups = String.split(group, " ")

        case groups == Enum.uniq(groups) do
          true ->
            changeset

          false ->
            %{
              changeset
              | valid?: false,
                errors: [{:group, {"must be unique", []}} | changeset.errors]
            }
        end
    end
  end
end
