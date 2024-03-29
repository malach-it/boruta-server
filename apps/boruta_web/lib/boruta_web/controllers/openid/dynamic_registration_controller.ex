defmodule BorutaWeb.Openid.DynamicRegistrationController do
  @behaviour Boruta.Openid.DynamicRegistrationApplication

  alias Boruta.Ecto
  alias Boruta.Oauth
  alias Boruta.Openid
  alias BorutaAuth.KeyPairs.KeyPair
  alias BorutaIdentity.IdentityProviders
  alias BorutaIdentity.IdentityProviders.Backend
  alias BorutaIdentity.IdentityProviders.IdentityProvider
  alias BorutaWeb.OpenidView

  use BorutaWeb, :controller

  def register_client(conn, params) do
    registration_params =
      Enum.map(params, fn {key, value} ->
        {String.to_atom(key), value}
      end)
      |> Enum.into(%{})
      |> Map.put(:id_token_signature_alg, "RS256")

    Openid.register_client(conn, registration_params, __MODULE__)
  end

  @impl Boruta.Openid.DynamicRegistrationApplication
  def client_registered(conn, %Oauth.Client{id: client_id} = client) do
    with %Backend{id: backend_id} <- Backend.default!(),
         {:ok, %IdentityProvider{id: identity_provider_id}} <-
           IdentityProviders.create_identity_provider(%{
             name: "Created with dynamic registration for client #{client_id}",
             backend_id: backend_id
           }),
         {:ok, client} <- insert_global_key_pair(client),
         {:ok, _client_identity_provider} <-
           IdentityProviders.upsert_client_identity_provider(client_id, identity_provider_id) do
      conn
      |> put_view(OpenidView)
      |> put_status(:created)
      |> render("client.json", client: client)
    else
      {:error, changeset} ->
        registration_failure(conn, changeset)
    end
  end

  @impl Boruta.Openid.DynamicRegistrationApplication
  def registration_failure(conn, changeset) do
    conn
    |> put_view(OpenidView)
    |> put_status(:bad_request)
    |> render("registration_error.json", changeset: changeset)
  end

  defp insert_global_key_pair(%Oauth.Client{id: client_id}) do
    %KeyPair{public_key: public_key, private_key: private_key} = KeyPair.default!()

    client = BorutaAuth.Repo.get!(Ecto.Client, client_id)

    Ecto.Admin.regenerate_client_key_pair(client, public_key, private_key)
  end
end
