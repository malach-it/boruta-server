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
    authenticable: [
      # BorutaIdentity.Accounts.Sessions
      :initialize_session,
      # BorutaIdentity.Accounts.Sessions
      :create_session,
      # BorutaIdentity.Accounts.Sessions
      :delete_session
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
    ]
  }

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "relying_parties" do
    field(:name, :string)
    field(:type, :string, default: "internal")
    field(:registrable, :boolean, default: false)
    field(:authenticable, :boolean, default: true, virtual: true)
    field(:reset_password, :boolean, default: true, virtual: true)

    has_many(:client_relying_parties, ClientRelyingParty)
    has_many(:templates, Template, on_replace: :delete_if_exists)

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
    |> Repo.preload(:templates)
    |> cast(attrs, [:name, :type, :registrable])
    |> validate_required([:name, :type])
    |> validate_inclusion(:type, @types)
    |> unique_constraint(:name)
    |> fill_default_templates()
    |> cast_assoc(:templates, with: &Template.assoc_changeset/2)
  end

  defp fill_default_templates(changeset) do
    templates = fetch_field!(changeset, :templates)

    Enum.reduce(Template.template_types(), changeset, fn template_type, changeset ->
      template_type = Atom.to_string(template_type)

      case templates
           |> Enum.map(&Map.get(&1, :type))
           |> Enum.member?(template_type) do
        true ->
          changeset

        false ->
          template_changeset = Template.assoc_changeset(%Template{}, %{type: template_type})
          put_change(changeset, :templates, [template_changeset | templates])
      end
    end)
  end
end
