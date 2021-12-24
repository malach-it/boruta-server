defmodule BorutaIdentity.Accounts.Internal.Registrations do
  @moduledoc false

  alias BorutaIdentity.Accounts.Deliveries
  alias BorutaIdentity.Accounts.User
  alias BorutaIdentity.Repo

  def register(user_params, confirmation_url_fun) do
    case create_user(user_params, confirmation_url_fun) do
      {:ok, %{create_user: user}} ->
        {:ok, user}

      {:error, :create_user, changeset, _changes} ->
        {:error, changeset}

      {:error, :deliver_confirmation_mail, reason, %{create_user: user}} ->
        changeset =
          user
          |> Map.delete(:__meta__)
          |> Ecto.Changeset.change()
          |> Ecto.Changeset.add_error(:confirmation_email, reason)

        {:error, changeset}
    end
  end

  defp create_user(user_params, confirmation_url_fun) do
    Ecto.Multi.new()
    |> Ecto.Multi.insert(:create_user, user_changeset(user_params))
    |> Ecto.Multi.run(:deliver_confirmation_mail, fn _repo, %{create_user: user} ->
      Deliveries.deliver_user_confirmation_instructions(
        user,
        confirmation_url_fun
      )
    end)
    |> Repo.transaction()
  end

  defp user_changeset(user_params) do
    %User{}
    |> User.registration_changeset(user_params)
  end
end
