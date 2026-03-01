defmodule BorutaWeb.Openid.CredentialController do
  @behaviour Boruta.Openid.CredentialApplication
  use BorutaWeb, :controller

  alias Boruta.Oauth.Error
  alias Boruta.Openid
  alias Boruta.Openid.CredentialResponse
  alias Boruta.Openid.DeferedCredentialResponse
  alias BorutaIdentity.Accounts.VerifiableCredentials
  alias BorutaWeb.OauthView
  alias BorutaWeb.PresentationServer

  def credential(conn, params) do
    Openid.credential(
      conn,
      params,
      VerifiableCredentials.public_credential_configuration(),
      __MODULE__
    )
  end

  def defered_credential(conn, _params) do
    Openid.defered_credential(conn, __MODULE__)
  end

  @impl Boruta.Openid.CredentialApplication
  def credential_created(conn, %CredentialResponse{} = response) do
    PresentationServer.message(response.token.previous_code, "Credential issued")

    conn
    |> put_view(OauthView)
    |> render("credential.json", credential_response: response)
  end

  def credential_created(conn, %DeferedCredentialResponse{} = response) do
    conn
    |> put_view(OauthView)
    |> render("defered_credential.json", credential_response: response)
  end

  @impl Boruta.Openid.CredentialApplication
  def credential_failure(conn, %Error{
        status: status,
        error: error,
        error_description: error_description
      }) do
    conn
    |> put_status(status)
    |> put_view(OauthView)
    |> render("error.json", error: error, error_description: error_description)
  end
end
