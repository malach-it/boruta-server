defmodule BorutaIdentity.RelyingParties.Template do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias BorutaIdentity.RelyingParties.RelyingParty

  @template_types [:new_registration]

  @default_templates %{
    new_registration:
      :code.priv_dir(:boruta_identity)
      |> Path.join("templates/registrations/new.mustache")
      |> File.read!()
  }

  def template_types, do: @template_types

  def default_template(type) when type in @template_types, do: @default_templates[type]

  @foreign_key_type :binary_id
  @primary_key {:id, :binary_id, autogenerate: true}
  schema "relying_party_templates" do
    field(:content, :string)
    field(:type, :string)

    belongs_to(:relying_party, RelyingParty)

    timestamps()
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
          content: default_template(changeset |> fetch_change!(:type) |> String.to_atom())
        )
    end
  end
end
