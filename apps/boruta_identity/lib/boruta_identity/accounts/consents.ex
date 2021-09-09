defmodule BorutaIdentity.Accounts.Consents do
  alias Boruta.Oauth.Request
  alias Boruta.Oauth.Scope
  alias BorutaIdentity.Accounts.Consent
  alias BorutaIdentity.Accounts.User
  alias BorutaIdentity.Repo

  @spec consent(user :: User.t(), attrs :: map()) ::
          {:ok, user :: User.t()} | {:error, changeset :: Ecto.Changeset.t()}
  def consent(user, attrs) do
    user
    |> User.consent_changeset(%{"consents" => [attrs]})
    |> Repo.update()
  end

  def consented?(user, conn) do
    with {:ok, %{client_id: client_id, scope: scope}} <-
           Request.authorize_request(conn, user),
         true <- scopes_consented?(user, client_id, Scope.split(scope)) do
      true
    else
      _ -> false
    end
  end

  defp scopes_consented?(%User{}, _client_id, []), do: true

  defp scopes_consented?(%User{} = user, client_id, scopes) do
    %User{consents: consents} = Repo.preload(user, :consents)

    Enum.any?(consents, fn %Consent{client_id: consent_client_id, scopes: consent_scopes} ->
      consent_client_id == client_id &&
        Enum.empty?(scopes -- consent_scopes)
    end)
  end

  defp scopes_consented?(_, _, _), do: false
end
