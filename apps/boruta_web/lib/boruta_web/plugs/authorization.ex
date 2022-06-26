defmodule BorutaWeb.Authorization do
  @moduledoc false

  require Logger

  use BorutaWeb, :controller

  alias BorutaWeb.ErrorView

  def require_authenticated(conn, _opts \\ []) do
    with [authorization_header] <- get_req_header(conn, "authorization"),
         [_authorization_header, token] <- Regex.run(~r/Bearer (.+)/, authorization_header),
         {:ok, %{"active" => true} = payload} <-
           introspect(token) do
      conn
      |> assign(:token, token)
      |> assign(:introspected_token, payload)
    else
      e ->
        Logger.debug("User unauthorized : #{inspect(e)}")

        conn
        |> put_status(:unauthorized)
        |> put_view(ErrorView)
        |> render("401.json")
        |> halt()
    end
  end

  def authorize(conn, [_h | _t] = scopes) do
    current_scopes = String.split(conn.assigns[:introspected_token]["scope"], " ")

    case Enum.empty?(scopes -- current_scopes) do
      true ->
        conn

      false ->
        conn
        |> put_status(:forbidden)
        |> put_view(ErrorView)
        |> render("403.json")
        |> halt()
    end
  end

  def authorize(conn, _opts) do
    conn
    |> put_status(:forbidden)
    |> put_view(ErrorView)
    |> render("403.json")
    |> halt()
  end

  # TODO cache token introspection
  def introspect(token) do
    oauth2_config = Application.get_env(:boruta_web, BorutaWeb.Authorization)[:oauth2]
    client_id = oauth2_config[:client_id]
    client_secret = oauth2_config[:client_secret]
    site = oauth2_config[:site]

    with {:ok, %Finch.Response{body: body}} <-
           Finch.build(
             :post,
             "#{site}/oauth/introspect",
             [
               {"accept", "application/json"},
               {"content-type", "application/x-www-form-urlencoded"},
               {"authorization", "Basic " <> Base.encode64("#{client_id}:#{client_secret}")}
             ],
             URI.encode_query(%{token: token})
           )
           |> Finch.request(FinchHttp) do
         Jason.decode(body)
    end
  end
end
