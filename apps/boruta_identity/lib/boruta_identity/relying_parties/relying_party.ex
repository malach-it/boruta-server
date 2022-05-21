defmodule BorutaIdentity.RelyingParties.RelyingParty do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias BorutaIdentity.RelyingParties.ClientRelyingParty
  alias BorutaIdentity.RelyingParties.Template
  alias BorutaIdentity.Repo

  @type t :: %__MODULE__{
          name: String.t(),
          type: String.t(),
          registrable: boolean(),
          confirmable: boolean(),
          authenticable: boolean(),
          reset_password: boolean(),
          client_relying_parties: list(ClientRelyingParty.t()) | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  @types [
    "internal"
  ]

  @implementations %{
    "internal" => BorutaIdentity.Accounts.Internal
  }

  @features %{
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
    authenticable: [
      # BorutaIdentity.Accounts.Sessions
      :initialize_session,
      # BorutaIdentity.Accounts.Sessions
      :create_session,
      # BorutaIdentity.Accounts.Sessions
      :delete_session,
      # BorutaIdentity.Accounts.Consents
      :initialize_consent,
      # BorutaIdentity.Accounts.ChooseSessions
      :initialize_choose_session
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
  schema "relying_parties" do
    field(:name, :string)
    field(:type, :string, default: "internal")
    field(:choose_session, :boolean, default: true)
    field(:registrable, :boolean, default: false)
    field(:user_editable, :boolean, default: false)
    field(:confirmable, :boolean, default: false)
    field(:consentable, :boolean, default: false)
    field(:authenticable, :boolean, default: true, virtual: true)
    field(:reset_password, :boolean, default: true, virtual: true)

    has_many(:client_relying_parties, ClientRelyingParty)
    has_many(:templates, Template, on_replace: :delete_if_exists)

    timestamps()
  end

  @spec template(relying_party :: t(), type :: atom()) :: Template.t() | nil
  def template(%__MODULE__{templates: templates} = relying_party, type) when is_list(templates) do
    case Enum.find(templates, fn
      %Template{type: template_type} -> Atom.to_string(type) == template_type
    end) do
      nil ->
        template = Template.default_template(type)
        template && %{template|relying_party_id: relying_party.id, relying_party: relying_party}
      template -> %{template|relying_party: relying_party}
    end
  end

  @spec implementation(client_relying_party :: %__MODULE__{}) :: implementation :: atom()
  def implementation(%__MODULE__{type: type}) do
    Map.fetch!(@implementations, type)
  end

  @spec check_feature(relying_party :: t(), action_name :: atom()) ::
          :ok | {:error, reason :: String.t()}
  def check_feature(relying_party, requested_action_name) do
    with {feature_name, _actions} <-
           Enum.find(@features, fn {_feature_name, actions} ->
             Enum.member?(actions, requested_action_name)
           end),
         {:ok, true} <- relying_party |> Map.from_struct() |> Map.fetch(feature_name) do
      :ok
    else
      {:ok, false} -> {:error, "Feature is not enabled for client relying party."}
      nil -> {:error, "This provider does not support this feature."}
    end
  end

  @doc false
  def changeset(relying_party, attrs) do
    relying_party
    |> Repo.preload(:templates)
    |> cast(attrs, [:name, :type, :choose_session, :registrable, :consentable, :confirmable])
    |> validate_required([:name, :type])
    |> validate_inclusion(:type, @types)
    |> unique_constraint(:name)
    |> cast_assoc(:templates, with: &Template.assoc_changeset/2)
  end

  @doc false
  def delete_changeset(relying_party) do
    changeset = change(relying_party)

    case Repo.preload(relying_party, :client_relying_parties) do
      %__MODULE__{client_relying_parties: []} ->
        changeset
      %__MODULE__{client_relying_parties: client_relying_parties} ->
        client_ids = Enum.map(client_relying_parties, fn %ClientRelyingParty{client_id: client_id} -> client_id end)
        add_error(changeset, :client_relying_parties, "Relying party is associated with client(s) #{Enum.join(client_ids, ", ")}")
    end
  end
end
