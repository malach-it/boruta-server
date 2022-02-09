defmodule BorutaIdentity.Accounts.ConsentApplication do
  @moduledoc """
  TODO ConsentApplication documentation
  """

  @callback consent_initialized(
              context :: any(),
              client :: Boruta.Oauth.Client.t(),
              scopes :: list(Boruta.Oauth.Scope.t()),
              template :: BorutaIdentity.RelyingParties.Template.t()
            ) :: any()

  @callback invalid_relying_party(
              context :: any(),
              error :: BorutaIdentity.Accounts.RelyingPartyError.t()
            ) :: any()
end

defmodule BorutaIdentity.Accounts.Consents do
  @moduledoc false

  import BorutaIdentity.Accounts.Utils, only: [defwithclientrp: 2]

  alias Boruta.Ecto.Admin
  alias Boruta.Oauth.AuthorizationSuccess
  alias Boruta.Oauth.Request
  alias Boruta.Oauth.Scope
  alias BorutaIdentity.Accounts.Consent
  alias BorutaIdentity.Accounts.User
  alias BorutaIdentity.RelyingParties
  alias BorutaIdentity.Repo

  @spec initialize_consent(
          context :: any(),
          client_id :: String.t(),
          authorization :: Boruta.Oauth.AuthorizationSuccess.t(),
          module :: atom()
        ) :: callback_result :: any()
  defwithclientrp initialize_consent(
        context,
        client_id,
        %AuthorizationSuccess{client: client, scope: scope},
        module
      ) do
    scopes = Scope.split(scope) |> Admin.get_scopes_by_names()

    module.consent_initialized(context, client, scopes, new_consent_template(client_rp))
  end

  @spec consent(user :: User.t(), attrs :: map()) ::
          {:ok, user :: User.t()} | {:error, changeset :: Ecto.Changeset.t()}
  def consent(%User{} = user, attrs) do
    user
    |> User.consent_changeset(%{"consents" => [attrs]})
    |> Repo.update()
  end

  @spec consented?(user :: User.t(), conn :: Plug.Conn.t()) :: boolean()
  def consented?(user, conn) do
    with {:ok, %_request_type{client_id: client_id, scope: scope}} <-
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

  defp new_consent_template(relying_party) do
    RelyingParties.get_relying_party_template!(relying_party.id, :new_consent)
  end
end
