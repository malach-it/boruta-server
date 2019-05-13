defmodule BorutaWeb.OauthController do
  use BorutaWeb, :controller

  alias BorutaWeb.OauthValidationPlug
  alias BorutaWeb.OauthSchema
  alias BorutaWeb.OauthView
  alias Authable.Model.Token

  plug OauthValidationPlug, OauthSchema

  action_fallback BorutaWeb.FallbackController

  def token(conn, params) do
    with %Token{} = token <- Authable.OAuth2.authorize(%{
      "grant_type" => "client_credentials",
      "client_id" => params["client_id"],
      "client_secret" => params["client_secret"],
      "scope" => params["scope"] || "" # TODO make it optional in Authable
    }) do
      conn
      |> put_view(OauthView)
      |> render("token.json", token: token)
    end
  end
end
