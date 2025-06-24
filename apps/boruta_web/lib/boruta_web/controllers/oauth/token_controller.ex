defmodule BorutaWeb.Oauth.TokenController do
  @behaviour Boruta.Oauth.TokenApplication
  @behaviour Boruta.Openid.DirectPostApplication

  use BorutaWeb, :controller
  import Boruta.Config, only: [issuer: 0]

  alias Boruta.Oauth
  alias Boruta.Oauth.Error
  alias Boruta.Oauth.TokenResponse
  alias Boruta.Openid
  alias Boruta.Openid.DirectPostResponse
  alias BorutaWeb.OauthView
  alias BorutaWeb.PresentationServer

  def token(%Plug.Conn{} = conn, _params) do
    conn |> Oauth.token(__MODULE__)
  end

  @impl Boruta.Oauth.TokenApplication
  def token_success(conn, %TokenResponse{} = response) do
    # TODO get grant_type from response
    :telemetry.execute(
      [:authorization, :token, :success],
      %{},
      %{
        client_id: response.token.client.id,
        sub: response.token.sub,
        access_token: response.access_token,
        agent_token: response.agent_token,
        token_type: response.token_type,
        expires_in: response.expires_in,
        refresh_token: response.refresh_token
      }
    )

    conn
    |> put_view(OauthView)
    |> put_resp_header("pragma", "no-cache")
    |> put_resp_header("cache-control", "no-store")
    |> render("token.json", response: response)
  end

  @impl Boruta.Oauth.TokenApplication
  def token_error(conn, %Error{status: status, error: error, error_description: error_description}) do
    # TODO get client_id and grant_type from error
    :telemetry.execute(
      [:authorization, :token, :failure],
      %{},
      %{
        status: status,
        error: error,
        error_description: error_description
      }
    )

    conn
    |> put_status(status)
    |> put_view(OauthView)
    |> render("error.json", error: error, error_description: error_description)
  end

  def direct_post(conn, %{"code_id" => code_id} = params) do
    direct_post_params = %{
      code_id: code_id,
      metadata_policy: params["metadata_policy"]
    }

    direct_post_params =
      case params do
        %{"id_token" => id_token} -> Map.put(direct_post_params, :id_token, id_token)
        %{"vp_token" => vp_token} -> Map.put(direct_post_params, :vp_token, vp_token)
        %{} -> direct_post_params
      end

    direct_post_params =
      case params do
        %{"presentation_submission" => presentation_submission} ->
          Map.put(direct_post_params, :presentation_submission, presentation_submission)

        %{} ->
          direct_post_params
      end

    Openid.direct_post(conn, direct_post_params, __MODULE__)
  end

  @impl Boruta.Openid.DirectPostApplication
  def code_not_found(conn) do
    send_resp(conn, 404, "")
  end

  @impl Boruta.Openid.DirectPostApplication
  def authentication_failure(conn, %Error{
        redirect_uri: nil,
        status: status,
        error: error,
        error_description: error_description
      }) do
    conn
    |> put_status(status)
    |> put_view(OauthView)
    |> render("error.json", error: error, error_description: error_description)
  end

  def authentication_failure(conn, %Error{} = error) do
    redirect(conn, external: Error.redirect_to_url(error))
  end

  @impl Boruta.Openid.DirectPostApplication
  def direct_post_success(conn, %DirectPostResponse{vp_token: vp_token} = response)
      when not is_nil(vp_token) do
    query =
      %{
        code: response.code.value,
        state: response.state
      }
      |> URI.encode_query()

    callback_uri = URI.parse(response.redirect_uri)

    callback_uri =
      %{callback_uri | host: callback_uri.host || "", query: query}
      |> URI.to_string()

    redirect(conn, external: callback_uri)
  end

  def direct_post_success(
        conn,
        %DirectPostResponse{id_token: id_token, error: %Error{}} = response
      )
      when not is_nil(id_token) do
    {:ok, %{"kid" => kid}} = Joken.peek_header(id_token)

    params = %{
      "client_id" => kid,
      "response_type" => response.code.response_type,
      "client_metadata" => "{}",
      "scope" => response.code.scope,
      "state" => response.code.state,
      "code" => response.code.value,
      "redirect_uri" => response.redirect_uri
    }

    redirect_uri = issuer() <> Routes.authorize_path(conn, :authorize, params)

    redirect(conn, external: redirect_uri)
  end

  def direct_post_success(conn, %DirectPostResponse{id_token: id_token, code: code} = response)
      when not is_nil(id_token) do
    {:ok, %{"kid" => kid}} = Joken.peek_header(id_token)

    params = %{
      "client_id" => kid,
      "response_type" => String.split(response.code.response_type, " ") |> List.last(),
      "client_metadata" => "{}",
      "scope" => response.code.scope,
      "state" => response.code.state,
      "code" => response.code.value,
      "redirect_uri" => response.redirect_uri
    }

    redirect_uri = issuer() <> Routes.authorize_path(conn, :authorize, params)

    PresentationServer.authenticated(code.value, redirect_uri)

    query =
      %{
        code: response.code.value,
        state: response.state
      }
      |> URI.encode_query()

    callback_uri = URI.parse(response.redirect_uri)

    callback_uri =
      %{callback_uri | host: callback_uri.host || "", query: query}
      |> URI.to_string()

    redirect(conn, external: callback_uri)
  end
end
