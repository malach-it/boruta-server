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
          state: params["state"]
        })
    end
  end
end
