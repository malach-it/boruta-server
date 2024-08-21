defmodule BorutaIdentity.IdentityProviders.IdentityProvider do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias BorutaIdentity.IdentityProviders.Backend
  alias BorutaIdentity.IdentityProviders.ClientIdentityProvider
  alias BorutaIdentity.IdentityProviders.Template
  alias BorutaIdentity.Repo

  @type t :: %__MODULE__{
          name: String.t(),
          backend_id: String.t(),
          backend: Backend.t(),
          registrable: boolean(),
          totpable: boolean(),
          enforce_totp: boolean(),
          confirmable: boolean(),
          authenticable: boolean(),
          reset_password: boolean(),
          client_identity_providers:
            list(ClientIdentityProvider.t()) | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  @features %{
    authenticable: [
      # BorutaIdentity.Accounts.Sessions
      :initialize_session,
      # BorutaIdentity.Accounts.FederatedSessions
      :create_federated_session,
      # BorutaIdentity.Totp
      :initialize_totp,
      # BorutaIdentity.Accounts.Sessions
      :create_session,
      # BorutaIdentity.Accounts.Sessions
      :delete_session,
      # BorutaIdentity.Accounts.Consents
      :initialize_consent,
      # BorutaIdentity.Accounts.ChooseSessions
      :initialize_choose_session
    ],
    totpable: [
      # BorutaIdentity.Totp
      :initialize_totp_registration,
      # BorutaIdentity.Totp
      :register_totp,
      # BorutaIdentity.Totp
      :initialize_totp,
      # BorutaIdentity.Totp
      :authenticate_totp
    ],
    webauthnable: [
      # BorutaIdentity.Totp
      :initialize_webauthn_registration,
      # BorutaIdentity.Webauthn
      :register_webauthn,
      # BorutaIdentity.Webauthn
      :initialize_webauthn,
      # BorutaIdentity.Webauthn
      :authenticate_webauthn
    ],
    registrable: [
      # BorutaIdentity.Accounts.Registrations
      :initialize_registration,
      # BorutaIdentity.Accounts.Registrations
      :register
    ],
    user_editable: [
      # BorutaIdentity.Accounts.Settings
      :initialize_edit_user,
      # BorutaIdentity.Accounts.Settings
      :update_user
    ],
    confirmable: [
      # BorutaIdentity.Accounts.Confirmations
      :initialize_confirmation_instructions,
      # BorutaIdentity.Accounts.Confirmations
      :send_confirmation_instructions,
      # BorutaIdentity.Accounts.Confirmations
      :confirm_user
    ],
    reset_password: [
      # BorutaIdentity.Accounts.ResetPasswords
      :initialize_password_instructions,
      # BorutaIdentity.Accounts.ResetPasswords
      :send_reset_password_instructions,
      # BorutaIdentity.Accounts.ResetPasswords
      :initialize_password_reset,
      # BorutaIdentity.Accounts.ResetPasswords
      :reset_password
    ],
    consentable: [
      # BorutaIdentity.Accounts.Consents
      :consent
    ]
  }

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "identity_providers" do
    field(:name, :string)
    field(:choose_session, :boolean, default: true)
    field(:totpable, :boolean, default: false)
    field(:enforce_totp, :boolean, default: false)
    field(:webauthnable, :boolean, default: false)
    field(:enforce_webauthn, :boolean, default: false)
    field(:registrable, :boolean, default: false)
    field(:user_editable, :boolean, default: false)
    field(:confirmable, :boolean, default: false)
    field(:consentable, :boolean, default: false)
    field(:authenticable, :boolean, default: true, virtual: true)
    field(:reset_password, :boolean, default: true, virtual: true)

    has_many(:client_identity_providers, ClientIdentityProvider)
    has_many(:templates, Template, on_replace: :delete_if_exists)
    belongs_to(:backend, Backend)

    timestamps()
  end

  @spec template(identity_provider :: t(), type :: atom()) :: Template.t() | nil
  def template(%__MODULE__{templates: templates} = identity_provider, type)
      when is_list(templates) do
    case Enum.find(templates, fn
           %Template{type: template_type} -> Atom.to_string(type) == template_type
         end) do
      nil ->
        template = Template.default_template(type)

        template &&
          %{
            template
            | identity_provider_id: identity_provider.id,
              identity_provider: identity_provider
          }

      template ->
        %{template | identity_provider: identity_provider}
    end
  end

  # TODO rename to backend
  @spec implementation(client_identity_provider :: %__MODULE__{}) :: implementation :: atom()
  def implementation(%__MODULE__{backend: backend}) do
    Backend.implementation(backend)
  end

  @spec check_feature(identity_provider :: t(), action_name :: atom()) ::
          :ok | {:error, reason :: String.t()}
  def check_feature(identity_provider, requested_action_name) do
    backend_features = apply(Backend.implementation(identity_provider.backend), :features, [])

    with {feature_name, _actions} <-
           Enum.find(@features, fn {_feature_name, actions} ->
             Enum.member?(actions, requested_action_name)
           end),
         {:ok, true} <- identity_provider |> Map.from_struct() |> Map.fetch(feature_name),
         true <- Enum.member?(backend_features, feature_name) do
      :ok
    else
      false -> {:error, "Feature is not enabled for identity provider backend implementation."}
      {:ok, false} -> {:error, "Feature is not enabled for client identity provider."}
      nil -> {:error, "This provider does not support this feature."}
    end
  end

  @doc false
  def changeset(identity_provider, attrs) do
    identity_provider
    |> Repo.preload(:templates)
    |> cast(attrs, [
      :id,
      :name,
      :choose_session,
      :totpable,
      :enforce_totp,
      :webauthnable,
      :enforce_webauthn,
      :registrable,
      :user_editable,
      :consentable,
      :confirmable,
      :backend_id
    ])
    |> unique_constraint(:id, name: :relying_parties_pkey)
    |> validate_required([:name, :backend_id])
    |> unique_constraint(:name)
    |> cast_assoc(:templates, with: &Template.assoc_changeset/2)
  end

  @doc false
  def delete_changeset(identity_provider) do
    changeset = change(identity_provider)

    case Repo.preload(identity_provider, :client_identity_providers) do
      %__MODULE__{client_identity_providers: []} ->
        changeset

      %__MODULE__{client_identity_providers: client_identity_providers} ->
        client_ids =
          Enum.map(client_identity_providers, fn %ClientIdentityProvider{client_id: client_id} ->
            client_id
          end)

        add_error(
          changeset,
          :client_identity_providers,
          "identity provider is associated with client(s) #{Enum.join(client_ids, ", ")}"
        )
    end
  end
end
