defmodule BorutaWeb.Oauth.TokenController do
  @behaviour Boruta.Oauth.TokenApplication
  @behaviour Boruta.Openid.DirectPostApplication

  use BorutaWeb, :controller
  import Boruta.Config, only: [issuer: 0]

  alias Boruta.CodesAdapter
  alias Boruta.Oauth
  alias Boruta.Oauth.Error
  alias Boruta.Oauth.Token
  alias Boruta.Oauth.TokenResponse
  alias Boruta.Openid
  alias BorutaWeb.OauthView

  @required_dids Enum.take_random([
    "did:key:z2dmzD81cgPx8Vki7JbuuMmFYrWPgYoytykUZ3eyqht1j9KboogM6iTSurwvMuv7MfgTyWTWuh94P1PvJc1XXuBsdNmKcDhj8aam1mCN3iPKxC2ofkahGp9HfRNWQVGmEYPF4ACP1K3XMeL6DXJKgr2i9W7yR9nW2EyfEhVDwN1PFfVvJp",
    "did:key:z2dmzD81cgPx8Vki7JbuuMmFYrWPgYoytykUZ3eyqht1j9Kbot7oiEsQLYB8wbaSN1tiMgSqcW7XBsvNRX5mKkmq23yRy1ghvNGENjAWYT3TT8LBUCj6vAogTUaa5suYVbfCES9xUpdDVtW2fQJhx4CsyPeeAUAyqGsjwiDi6aTnRKDhac",
    "did:key:z2dmzD81cgPx8Vki7JbuuMmFYrWPgYoytykUZ3eyqht1j9Kbq7vQ4hgvZMM99iyYEy2xodSjoNANrfqcLfgJjexuzEqwHt7AsyLDG1wyJ7XMrgwHpNKDCLLP8hMkLodGrZKMEqxzmquM1uDFGGbHTxFAVUFdtyG1jqjLYvaruwdmFk8gGL",
    "did:key:z2dmzD81cgPx8Vki7JbuuMmFYrWPgYoytykUZ3eyqht1j9KbpyccjxAQmUXi9ydaB4YWkqchFZJW1vJL4uVkBGjE97WD9jTsE336aKeW2qjQqHh6DgBm79BpKZWVQn6TnXQfFWgiafDUeubRgHSgAdZpFwhPBp8rriAoKfP23kzCZ62vwN",
    "did:key:z2dmzD81cgPx8Vki7JbuuMmFYrWPgYoytykUZ3eyqht1j9Kbs4xtdjTyw3AtAUw7sMVk3x6nqc2xQSNHwTHhUTiGhQxLHiWx9sB7Bcmx3UyWJzQwFsoKFrpBmgGAKPgJJ2nJrBn8rDKFT9vsfqAsLQzWEj3hAitXuqXMD75wwBrB9Dce1J",
    "did:key:z2dmzD81cgPx8Vki7JbuuMmFYrWPgYoytykUZ3eyqht1j9KbrXz29RMxHug85XVRA8u7RnUqxNpodjdfkXkSJVoDfEhwU9gkmAoPjZKJqEAjfsbUMugQF5vd2PyCVm8U1mHMds9Fa888N1ukxDky8QyagMSCbGt4nR1fp8x9i75TykLJ5A",
    "did:key:z2dmzD81cgPx8Vki7JbuuMmFYrWPgYoytykUZ3eyqht1j9KbpQxALBcXjsAH6FvbhJ3dsQPCZ8muRzwUVghkib6EgqRcbRSmH1svbCcn3uNaaH5WG9cPtm2D7B7qKmnX5CcmHzswSnd3kjoerWPoPv98gR9CihgdwzLYk9MjL4MJqre7ek",
    "did:key:z2dmzD81cgPx8Vki7JbuuMmFYrWPgYoytykUZ3eyqht1j9Kbo1SSEXfgo5LgqK2Wnxqcsc1M4sBmNZfKUtGToyeUUgxbJSzsmsA2BATFbm3oNfKaiZKLX8Z7j476ngqomieBb2PDrFHo5kUxDrbzUpz5jvn1hDz4AHVg8sL2Cfjd7SdpgU",
  ], 3)

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
      code_id: code_id
    }

    direct_post_params =
      case params do
        %{"response" => response} -> Map.put(direct_post_params, :response, response)
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
  def direct_post_success(conn, response) do
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

    case response.id_token do
      nil ->
        redirect(conn, external: callback_uri)
      id_token ->
        {:ok, %{"kid" => kid}} = Joken.peek_header(id_token)
        case Enum.empty?(@required_dids -- [kid | subject_chain(response.code)]) do
          true ->
            params = %{
              "client_id" => kid,
              "response_type" => "vp_token",
              "client_metadata" => "{}",
              "scope" => response.code.scope,
              "state" => response.code.state,
              "code" => response.code.value,
              "redirect_uri" => response.redirect_uri
            }
            redirect_uri = issuer() <> Routes.authorize_path(conn, :authorize, params)

            redirect(conn, external: redirect_uri)
          false ->
            params = %{
              "client_id" => kid,
              "response_type" => "code",
              "client_metadata" => "{}",
              "scope" => response.code.scope,
              "state" => response.code.state,
              "code" => response.code.value,
              "redirect_uri" => response.redirect_uri
            }
            redirect_uri = issuer() <> Routes.authorize_path(conn, :authorize, params)

            redirect(conn, external: redirect_uri)
        end
    end
  end

  defp subject_chain(token, acc \\ [])

  defp subject_chain(%Token{previous_code: nil, sub: sub}, acc), do: [sub | acc]

  defp subject_chain(%Token{previous_code: value, sub: sub}, acc) do
    [sub | acc ++ subject_chain(CodesAdapter.get_by(value: value))]
  end

  defp subject_chain(nil, _acc), do: {:error, "Previous code not found."}
end
