defmodule BorutaIdentity.RelyingParties.RelyingParty do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias BorutaIdentity.RelyingParties.ClientRelyingParty

  @type t :: %__MODULE__{
          name: String.t(),
          type: String.t(),
          client_relying_parties: list(ClientRelyingParty.t()) | Ecto.AssociationNotLoaded.t(),
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
    authenticable: [
      # BorutaIdentity.Accounts.Sessions
      :create_session,
      # BorutaIdentity.Accounts.Sessions
      :delete_session
    ],
    reset_password: [
      # BorutaIdentity.Accounts.ResetPasswords
      :send_reset_password_instructions,
      # BorutaIdentity.Accounts.ResetPasswords
      :initialize_password_reset,
      # BorutaIdentity.Accounts.ResetPasswords
      :reset_password,
    ]
  }

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "relying_parties" do
    field(:name, :string)
    field(:type, :string)
    field(:registrable, :boolean, default: false)
    field(:authenticable, :boolean, default: true, virtual: true)
    field(:reset_password, :boolean, default: true, virtual: true)

    has_many(:client_relying_parties, ClientRelyingParty)

    timestamps()
  end

  @spec implementation(client_relying_party :: %__MODULE__{}) :: implementation :: atom()
  def implementation(%__MODULE__{type: type}) do
    Map.fetch!(@implementations, type)
  end

  @spec check_feature(relying_party :: t(), action_name :: atom()) ::
          :ok | {:error, reason :: String.t()}
  def check_feature(relying_party, requested_action_name) do
    with {feature_name, _action_name} <-
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
    |> cast(attrs, [:name, :type, :registrable])
    |> validate_required([:name, :type])
    |> validate_inclusion(:type, @types)
  end
end
