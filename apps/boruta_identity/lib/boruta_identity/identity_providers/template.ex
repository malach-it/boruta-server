defmodule BorutaIdentity.IdentityProviders.Template do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias BorutaIdentity.IdentityProviders.IdentityProvider

  @type t :: %__MODULE__{
          id: String.t() | nil,
          type: String.t(),
          layout: t(),
          default: boolean(),
          content: String.t(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  @template_types [
    :layout,
    :new_session,
    :choose_session,
    :new_totp_registration,
    :new_totp_authentication,
    :new_webauthn_registration,
    :new_webauthn_authentication,
    :new_registration,
    :new_consent,
    :new_reset_password,
    :edit_reset_password,
    :new_confirmation_instructions,
    :edit_user,
    :credential_offer
  ]
  @type template_type ::
          :layout
          | :new_session
          | :choose_session
          | :new_consent
          | :new_totp_registration
          | :new_totp_authentication
          | :new_webauthn_registration
          | :new_webauthn_authentication
          | :new_registration
          | :new_reset_password
          | :edit_reset_password
          | :new_confirmation_instructions
          | :edit_user
          | :credential_offer

  @default_templates %{
    layout:
      :code.priv_dir(:boruta_identity)
      |> Path.join("templates/layouts/app.mustache")
      |> File.read!(),
    new_session:
      :code.priv_dir(:boruta_identity)
      |> Path.join("templates/sessions/new.mustache")
      |> File.read!(),
    choose_session:
      :code.priv_dir(:boruta_identity)
      |> Path.join("templates/choose_session/index.mustache")
      |> File.read!(),
    new_totp_registration:
      :code.priv_dir(:boruta_identity)
      |> Path.join("templates/mfa/totp/registration.mustache")
      |> File.read!(),
    new_totp_authentication:
      :code.priv_dir(:boruta_identity)
      |> Path.join("templates/mfa/totp/authentication.mustache")
      |> File.read!(),
    new_webauthn_registration:
      :code.priv_dir(:boruta_identity)
      |> Path.join("templates/mfa/webauthn/registration.mustache")
      |> File.read!(),
    new_webauthn_authentication:
      :code.priv_dir(:boruta_identity)
      |> Path.join("templates/mfa/webauthn/authentication.mustache")
      |> File.read!(),
    new_registration:
      :code.priv_dir(:boruta_identity)
      |> Path.join("templates/registrations/new.mustache")
      |> File.read!(),
    new_consent:
      :code.priv_dir(:boruta_identity)
      |> Path.join("templates/consents/new.mustache")
      |> File.read!(),
    new_reset_password:
      :code.priv_dir(:boruta_identity)
      |> Path.join("templates/reset_passwords/new.mustache")
      |> File.read!(),
    edit_reset_password:
      :code.priv_dir(:boruta_identity)
      |> Path.join("templates/reset_passwords/edit.mustache")
      |> File.read!(),
    new_confirmation_instructions:
      :code.priv_dir(:boruta_identity)
      |> Path.join("templates/confirmations/new.mustache")
      |> File.read!(),
    edit_user:
      :code.priv_dir(:boruta_identity)
      |> Path.join("templates/settings/edit_user.mustache")
      |> File.read!(),
    credential_offer:
      :code.priv_dir(:boruta_identity)
      |> Path.join("templates/settings/credential_offer.mustache")
      |> File.read!()
  }

  @foreign_key_type :binary_id
  @primary_key {:id, :binary_id, autogenerate: true}
  schema "identity_provider_templates" do
    field(:content, :string)
    field(:type, :string)

    field(:default, :boolean, virtual: true, default: false)
    field(:layout, :any, virtual: true, default: nil)

    belongs_to(:identity_provider, IdentityProvider)

    timestamps()
  end

  def template_types, do: @template_types

  @spec default_content(type :: template_type()) :: template_content :: String.t()
  def default_content(type) when type in @template_types, do: @default_templates[type]

  @spec default_template(type :: template_type()) :: %__MODULE__{} | nil
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
    |> cast(attrs, [:type, :content, :identity_provider_id])
    |> validate_required([:type, :identity_provider_id, :content])
    |> validate_inclusion(:type, Enum.map(@template_types, &Atom.to_string/1))
    |> foreign_key_constraint(:identity_provider_id)
    |> put_default()
  end

  @doc false
  def assoc_changeset(template, attrs) do
    template
    |> cast(attrs, [:type, :content])
    |> validate_required([:type, :content])
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
