defmodule BorutaIdentity.RelyingParties.Template do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias BorutaIdentity.RelyingParties.RelyingParty

  @type t :: %__MODULE__{
          id: String.t() | nil,
          type: String.t(),
          default: boolean(),
          content: String.t(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  @template_types [
    :new_session,
    :new_registration,
    :new_reset_password,
    :edit_reset_password,
    :new_confirmation_instructions
  ]
  @type template_type ::
          :new_session
          | :new_registration
          | :new_reset_password
          | :edit_reset_password
          | :new_confirmation_instructions

  @default_templates %{
    new_session:
      :code.priv_dir(:boruta_identity)
      |> Path.join("templates/sessions/new.mustache")
      |> File.read!(),
    new_registration:
      :code.priv_dir(:boruta_identity)
      |> Path.join("templates/registrations/new.mustache")
      |> File.read!(),
    new_confirmation_instructions:
      :code.priv_dir(:boruta_identity)
      |> Path.join("templates/confirmations/new.mustache")
      |> File.read!(),
    new_reset_password:
      :code.priv_dir(:boruta_identity)
      |> Path.join("templates/reset_passwords/new.mustache")
      |> File.read!(),
    edit_reset_password:
      :code.priv_dir(:boruta_identity)
      |> Path.join("templates/reset_passwords/edit.mustache")
      |> File.read!()
  }

  @foreign_key_type :binary_id
  @primary_key {:id, :binary_id, autogenerate: true}
  schema "relying_party_templates" do
    field(:content, :string)
    field(:type, :string)

    field(:default, :boolean, virtual: true, default: false)

    belongs_to(:relying_party, RelyingParty)

    timestamps()
  end

  def template_types, do: @template_types

  @spec default_content(type :: template_type()) :: template_content :: String.t()
  def default_content(type) when type in @template_types, do: @default_templates[type]

  @spec default_template(type :: atom()) :: template :: t() | nil
  def default_template(type) when type in @template_types do
    %__MODULE__{
      default: true,
      type: Atom.to_string(type),
      content: default_content(type)
    }
  end

  def default_template(_type), do: nil

  @doc false
  def changeset(template, attrs) do
    template
    |> cast(attrs, [:type, :content, :relying_party_id])
    |> validate_required([:relying_party_id])
    |> foreign_key_constraint(:relying_party_id)
  end

  @doc false
  def assoc_changeset(template, attrs) do
    template
    |> cast(attrs, [:type, :content])
    |> validate_required([:type])
    |> validate_inclusion(:type, Enum.map(@template_types, &Atom.to_string/1))
    |> put_default()
  end

  defp put_default(changeset) do
    case fetch_change(changeset, :content) do
      {:ok, content} when not is_nil(content) ->
        changeset

      _ ->
        change(
          changeset,
          content: default_template(changeset |> fetch_field!(:type) |> String.to_atom())
        )
    end
  end
end
