defmodule BorutaWeb.Pow.Routes do
  @moduledoc false

  alias BorutaWeb.Router.Helpers, as: Routes

  use Pow.Phoenix.Routes
  use BorutaWeb, :controller

  def after_sign_in_path(conn) do
    case get_session(conn, :oauth_request) do
      nil ->
        # TODO default after_sign_in_path configuration
        "/admin"
      params ->
        Routes.oauth_path(conn, :authorize, %{
          response_type: params["response_type"],
          client_id: params["client_id"],
          redirect_uri: params["redirect_uri"],
          scope: params["scope"],
          state: params["state"],
          code_challenge: params["code_challenge"],
          code_challenge_method: params["code_challenge_method"]
        })
    end
  end
end
