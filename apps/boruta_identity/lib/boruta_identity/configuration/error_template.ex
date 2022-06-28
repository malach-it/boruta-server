defmodule BorutaIdentity.Configuration.ErrorTemplate do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: String.t() | nil,
          type: String.t(),
          default: boolean(),
          content: String.t(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  @template_types [
    400,
    403,
    404,
    500
  ]
  @type template_type :: integer()

  @default_templates %{
    400 =>
      :code.priv_dir(:boruta_identity)
      |> Path.join("templates/errors/400.mustache")
      |> File.read!(),
    403 =>
      :code.priv_dir(:boruta_identity)
      |> Path.join("templates/errors/403.mustache")
      |> File.read!(),
    404 =>
      :code.priv_dir(:boruta_identity)
      |> Path.join("templates/errors/404.mustache")
      |> File.read!(),
    500 =>
      :code.priv_dir(:boruta_identity)
      |> Path.join("templates/errors/500.mustache")
      |> File.read!()
  }

  @foreign_key_type :binary_id
  @primary_key {:id, :binary_id, autogenerate: true}
  schema "error_templates" do
    field(:content, :string)
    field(:type, :string)

    field(:default, :boolean, virtual: true, default: false)

    timestamps()
  end

  def template_types, do: @template_types

  @spec default_content(type :: template_type()) :: template_content :: String.t()
  def default_content(type) when type in @template_types, do: @default_templates[type]

  @spec default_template(type :: template_type()) :: %__MODULE__{} | nil
  def default_template(type) when type in @template_types do
    %__MODULE__{
      default: true,
      type: Integer.to_string(type),
      content: default_content(type)
    }
  end

  def default_template(_type), do: nil

  @doc false
  def changeset(template, attrs) do
    template
    |> cast(attrs, [:type, :content])
    |> validate_inclusion(:type, Enum.map(@template_types, &Integer.to_string/1))
    |> validate_required([:type, :content])
    |> put_default()
  end

  defp put_default(changeset) do
    case fetch_change(changeset, :content) do
      {:ok, content} when not is_nil(content) ->
        changeset

      _ ->
        change(
          changeset,
          content: default_template(changeset |> fetch_field!(:type) |> String.to_integer())
        )
    end
  end
end
