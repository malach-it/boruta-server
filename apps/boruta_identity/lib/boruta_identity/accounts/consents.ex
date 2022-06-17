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

  @callback consented(context :: any()) :: any()

  @callback consent_failed(context :: any(), changeset :: Ecto.Changeset.t()) :: any()
end

defmodule BorutaIdentity.Accounts.Consents do
  @moduledoc false

  import BorutaIdentity.Accounts.Utils, only: [defwithclientrp: 2]
  import Ecto.Query, only: [from: 2]

  alias Boruta.Ecto.Admin
  alias Boruta.Oauth.Scope
  alias BorutaIdentity.Accounts.Consent
  alias BorutaIdentity.Accounts.User
  alias BorutaIdentity.IdentityProviders
  alias BorutaIdentity.Repo

  @spec initialize_consent(
          context :: any(),
          client_id :: String.t(),
          user :: User.t(),
          scope :: String.t(),
          module :: atom()
        ) :: callback_result :: any()
  defwithclientrp initialize_consent(
                    context,
                    client_id,
                    user,
                    scope,
                    module
                  ) do
    client = Admin.get_client!(client_id)
    scopes = Scope.split(scope)

    case {client_rp.consentable, consented?(user, client_id, scopes)} do
      {true, false} ->
        scopes = Admin.get_scopes_by_names(scopes)

        module.consent_initialized(context, client, scopes, new_consent_template(client_rp))
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

  @spec consented?(user :: User.t(), client_id :: String.t(), scopes :: list(String.t())) :: boolean()
  def consented?(%User{}, _client_id, []), do: true

  def consented?(%User{id: user_id}, client_id, scopes) do
    case Repo.one(from c in Consent, where: c.user_id == ^user_id and c.client_id == ^client_id) do
      nil -> false
      consent -> Enum.empty?(scopes -- consent.scopes)
    end
  end

  def consented?(_, _, _), do: false

  defp new_consent_template(identity_provider) do
    IdentityProviders.get_identity_provider_template!(identity_provider.id, :new_consent)
  end
end
