defmodule Boruta.Coherence.User do
  @moduledoc false

  @behaviour Boruta.Oauth.ResourceOwner

  use Ecto.Schema
  use Coherence.Schema

  @type t :: [
    email: String.t()
  ]
  @primary_key {:id, :binary_id, autogenerate: true}
  schema "users" do
    field(:name, :string)
    field(:email, :string)
    coherence_schema()

    timestamps()
  end

  @doc false
  @spec changeset(Ecto.Schema.t(), map()) :: Ecto.Changeset.t()
  def changeset(model, params \\ %{}) do
    model
    |> cast(params, ~w(name email)a ++ coherence_fields())
    |> validate_required([:name, :email])
    |> validate_format(:email, ~r/@/)
    |> unique_constraint(:email)
    |> validate_coherence(params)
  end

  @doc false
  def changeset(model, params, :password) do
    model
    |> cast(
      params,
      ~w(password password_confirmation reset_password_token reset_password_sent_at)a
    )
    |> validate_coherence_password_reset(params)
  end

  @doc false
  def changeset(model, params, :registration) do
    changeset = changeset(model, params)

    if Config.get(:confirm_email_updates) && Map.get(params, "email", false) && model.id do
      changeset
      |> put_change(:unconfirmed_email, get_change(changeset, :email))
      |> delete_change(:email)
    else
      changeset
    end
  end
end
