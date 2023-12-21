defmodule BorutaIdentity.Organizations.Organization do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias BorutaIdentity.Accounts.EmailTemplate

  @type t :: %__MODULE__{
    id: String.t(),
    name: String.t(),
    label: String.t() | nil,
    inserted_at: DateTime.t(),
    updated_at: DateTime.t()
  }

  @primary_key {:id, Ecto.UUID, autogenerate: true}
  @foreign_key_type Ecto.UUID
  schema "organizations" do
    field(:name, :string)
    field(:label, :string)

    has_many(:email_templates, EmailTemplate)
    timestamps()
  end

  @doc false
  def changeset(organization, attrs) do
    organization
    |> cast(attrs, [:name, :label])
    |> validate_required([:name])
  end

  @spec email_template(organization :: t(), type :: atom()) :: EmailTemplate.t() | nil
  def email_template(%__MODULE__{email_templates: email_templates} = organization, type)
      when is_list(email_templates) do
    case Enum.find(email_templates, fn
           %EmailTemplate{type: template_type} -> Atom.to_string(type) == template_type
         end) do
      nil ->
        template = EmailTemplate.default_template(type)

        template &&
          %{
            template
            | organization_id: organization.id,
              organization: organization
          }

      template ->
        %{template | organization: organization}
    end
  end
end
