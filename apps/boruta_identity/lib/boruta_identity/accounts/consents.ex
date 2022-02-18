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

  @callback consent_not_required(context :: any()) :: any()

  @callback consented(context :: any()) :: any()

  @callback consent_failed(context :: any(), changeset :: Ecto.Changeset.t()) :: any()

  @callback invalid_relying_party(
              context :: any(),
              error :: BorutaIdentity.Accounts.RelyingPartyError.t()
            ) :: any()
end

defmodule BorutaIdentity.Accounts.Consents do
  @moduledoc false

  import BorutaIdentity.Accounts.Utils, only: [defwithclientrp: 2]

  alias Boruta.Ecto.Admin
  alias Boruta.Oauth.Request
  alias Boruta.Oauth.Scope
  alias BorutaIdentity.Accounts.Consent
  alias BorutaIdentity.Accounts.User
  alias BorutaIdentity.RelyingParties
  alias BorutaIdentity.RelyingParties.RelyingParty
  alias BorutaIdentity.Repo

  @spec initialize_consent(
          context :: any(),
          client_id :: String.t(),
          scope :: String.t(),
          module :: atom()
        ) :: callback_result :: any()
  defwithclientrp initialize_consent(
                    context,
                    client_id,
                    scope,
                    module
                  ) do
    client = Admin.get_client!(client_id)
    scopes = Scope.split(scope) |> Admin.get_scopes_by_names()

    case client_rp.consentable do
      true ->
        module.consent_initialized(context, client, scopes, new_consent_template(client_rp))
      false ->
        module.consent_not_required(context)
    end
  end

  @type consent_params :: %{
          client_id: String.t(),
          scopes: list(String.t())
        }

  @spec consent(
          context :: any(),
          client_id :: String.t(),
          user :: User.t(),
          params :: consent_params(),
          module :: atom()
        ) :: callback_result :: any()
  def consent(context, _client_id, user, params, module) do
    case user
         |> User.consent_changeset(%{consents: [params]})
         |> Repo.update() do
      {:ok, _user} ->
        module.consented(context)

      {:error, changeset} ->
        module.consent_failed(context, changeset)
    end
  end

  @spec consented?(user :: User.t(), conn :: Plug.Conn.t()) :: boolean()
  def consented?(user, conn) do
    with {:ok, %_request_type{client_id: client_id, scope: scope}} <-
           Request.authorize_request(conn, user),
         %RelyingParty{consentable: true} <- RelyingParties.get_relying_party_by_client_id(client_id),
         true <- scopes_consented?(user, client_id, Scope.split(scope)) do
      true
    else
      %RelyingParty{consentable: false} -> true
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
