defmodule BorutaIdentity.Accounts.EmailTemplate do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias BorutaIdentity.IdentityProviders.Backend

  @type t :: %__MODULE__{
          id: String.t() | nil,
          type: String.t(),
          default: boolean(),
          txt_content: String.t(),
          html_content: String.t(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  @template_types [
    :confirmation_instructions,
    :reset_password_instructions
  ]

  @type template_type :: :confirmation_instructions | :reset_password_instructions

  @default_templates %{
    txt_confirmation_instructions:
      :code.priv_dir(:boruta_identity)
      |> Path.join("templates/emails/confirmation_instructions.txt.mustache")
      |> File.read!(),
    html_confirmation_instructions:
      :code.priv_dir(:boruta_identity)
      |> Path.join("templates/emails/confirmation_instructions.html.mustache")
      |> File.read!(),
    txt_reset_password_instructions:
      :code.priv_dir(:boruta_identity)
      |> Path.join("templates/emails/reset_password_instructions.txt.mustache")
      |> File.read!(),
    html_reset_password_instructions:
      :code.priv_dir(:boruta_identity)
      |> Path.join("templates/emails/reset_password_instructions.html.mustache")
      |> File.read!()
  }

  @foreign_key_type :binary_id
  @primary_key {:id, :binary_id, autogenerate: true}
  schema "email_templates" do
    field(:txt_content, :string, default: "")
    field(:html_content, :string, default: "")
    field(:type, :string)

    field(:default, :boolean, virtual: true, default: false)

    belongs_to(:backend, Backend)

    timestamps()
  end

  def template_types, do: @template_types

  @spec default_txt_content(type :: template_type()) :: template_content :: String.t()
  def default_txt_content(type) when type in @template_types, do: @default_templates[:"txt_#{type}"]

  @spec default_html_content(type :: template_type()) :: template_content :: String.t()
  def default_html_content(type) when type in @template_types, do: @default_templates[:"html_#{type}"]

  @spec default_template(type :: template_type()) :: %__MODULE__{} | nil
  def default_template(type) when type in @template_types do
    %__MODULE__{
      default: true,
      type: Atom.to_string(type),
      txt_content: default_txt_content(type),
      html_content: default_html_content(type)
    }
  end

  def default_template(_type), do: nil

  @doc false
  def changeset(template, attrs) do
    template
    |> cast(attrs, [:type, :txt_content, :html_content, :backend_id])
    |> validate_required([:type, :backend_id, :txt_content, :html_content])
    |> validate_inclusion(:type, Enum.map(@template_types, &Atom.to_string/1))
    |> foreign_key_constraint(:backend_id)
    |> put_default_txt()
    |> put_default_html()
  end

  @doc false
  def assoc_changeset(template, attrs) do
    template
    |> cast(attrs, [:type, :txt_content, :html_content])
    |> validate_required([:type, :txt_content, :html_content])
    |> validate_inclusion(:type, Enum.map(@template_types, &Atom.to_string/1))
    |> put_default_txt()
    |> put_default_html()
  end

  defp put_default_txt(changeset) do
    case fetch_change(changeset, :txt_content) do
      {:ok, content} when not is_nil(content) ->
        changeset

      _ ->
        change(
          changeset,
          txt_content: default_txt_content(changeset |> fetch_field!(:type) |> String.to_atom())
        )
    end
  end

  defp put_default_html(changeset) do
    case fetch_change(changeset, :html_content) do
      {:ok, content} when not is_nil(content) ->
        changeset

      _ ->
        change(
          changeset,
          html_content: default_html_content(changeset |> fetch_field!(:type) |> String.to_atom())
        )
    end
  end
end
