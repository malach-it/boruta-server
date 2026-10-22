defmodule BorutaIdentity.Accounts.ConsentApplication do
  @moduledoc """
  TODO ConsentApplication documentation
  """

  @callback consent_initialized(
              context :: any(),
              client :: Boruta.Oauth.Client.t(),
              scopes :: list(Boruta.Oauth.Scope.t()),
              template :: BorutaIdentity.IdentityProviders.Template.t()
            ) :: any()

  @callback consent_not_required(context :: any()) :: any()

  @callback consented(context :: any(), scope :: String.t()) :: any()

  @callback consent_failed(context :: any(), changeset :: Ecto.Changeset.t()) :: any()
end

defmodule BorutaIdentity.Accounts.Consents do
  @moduledoc false

  import BorutaIdentity.Accounts.Utils, only: [defwithclientidp: 2]
  import Ecto.Query, only: [from: 2]

  alias Boruta.ClientsAdapter
  alias Boruta.Ecto.Admin
  alias Boruta.Ecto.Clients
  alias Boruta.Oauth.Scope
  alias BorutaIdentity.Accounts.Consent
  alias BorutaIdentity.Accounts.User
  alias BorutaIdentity.IdentityProviders
  alias BorutaIdentity.IdentityProviders.ClientIdentityProvider
  alias BorutaIdentity.IdentityProviders.IdentityProvider
  alias BorutaIdentity.Repo

  @spec list_user_consents(Ecto.UUID.t()) :: list(Consent.t())
  def list_user_consents(user_id) do
    Repo.all(
      from consent in Consent,
        where: consent.user_id == ^user_id,
        order_by: [desc: consent.updated_at]
    )
  end

  @spec initialize_consent(
          context :: any(),
          client_id :: String.t(),
          user :: User.t(),
          scope :: String.t(),
          module :: atom()
        ) :: callback_result :: any()
  defwithclientidp initialize_consent(
                     context,
                     client_id,
                     user,
                     scope,
                     module
                   ) do
    client =
      case client_id do
        "did:" <> _key -> %{ClientsAdapter.public!() | name: client_id}
        _ -> Clients.get_client(client_id)
      end

    scopes = Scope.split(scope)

    case {client_idp.consentable, consented?(user, client_id, scopes)} do
      {true, false} ->
        scopes = Admin.get_scopes_by_names(scopes)

        module.consent_initialized(context, client, scopes, new_consent_template(client_idp))

      _ ->
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
          requested_scopes :: list(String.t()),
          params :: consent_params(),
          module :: atom()
        ) :: callback_result :: any()
  defwithclientidp consent(context, client_id, user, requested_scopes, params, module) do
    _client_idp = client_idp

    scopes = requested_scopes -- (requested_scopes -- params[:scopes])
    user_id = user.id

    consent =
      Repo.one(
        from co in Consent,
          where: co.user_id == ^user_id and co.client_id == ^client_id
      ) || %Consent{user_id: user.id, client_id: client_id}

    case consent
         |> Consent.changeset(%{scopes: scopes})
         |> Repo.insert_or_update() do
      {:ok, _consent} ->
        module.consented(context, params[:scopes])

      {:error, changeset} ->
        module.consent_failed(context, changeset)
    end
  end

  @spec consented?(user :: User.t(), client_id :: String.t(), scopes :: list(String.t())) ::
          boolean()
  def consented?(%User{}, _client_id, []), do: true

  def consented?(%User{id: user_id}, "did:" <> _key = client_id, scopes) do
    public_client_id = ClientsAdapter.public!().id

    case Repo.one(
           from cidp in ClientIdentityProvider,
             join: idp in assoc(cidp, :identity_provider),
             left_join: co in Consent,
             on: co.client_id == ^client_id and co.user_id == ^user_id,
             select: {idp.consentable, co.scopes},
             where: cidp.client_id == ^public_client_id
         ) do
      nil -> false
      {true, consented_scopes} -> Enum.empty?(scopes -- (consented_scopes || []))
      {false, _} -> true
    end
  end

  def consented?(_user, "did:" <> _key = client_id, _scopes) do
    case IdentityProviders.get_identity_provider_by_client_id(client_id) do
      %IdentityProvider{consentable: false} -> true
      _ -> false
    end
  end

  def consented?(%User{id: user_id}, client_id, scopes) do
    case Repo.one(
           from cidp in ClientIdentityProvider,
             join: idp in assoc(cidp, :identity_provider),
             left_join: co in Consent,
             on: co.client_id == ^client_id and co.user_id == ^user_id,
             select: {idp.consentable, co.scopes},
             where: cidp.client_id == ^client_id
         ) do
      nil -> false
      {true, consented_scopes} -> Enum.empty?(scopes -- (consented_scopes || []))
      {false, _} -> true
    end
  end

  def consented?(_, _, _), do: false

  defp new_consent_template(identity_provider) do
    IdentityProviders.get_identity_provider_template!(identity_provider.id, :new_consent)
  end
end
