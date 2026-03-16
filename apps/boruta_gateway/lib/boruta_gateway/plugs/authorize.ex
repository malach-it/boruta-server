defmodule BorutaGateway.Plug.Authorize do
  @moduledoc false

  import Plug.Conn

  alias Boruta.ClientsAdapter
  alias Boruta.Oauth.Authorization
  alias Boruta.Oauth.Scope
  alias Boruta.Oauth.Token
  alias BorutaGateway.Upstreams.Upstream

  @default_error_content_type "application/json"
  @default_forbidden_response Jason.encode!(%{
                                error: "FORBIDDEN",
                                message: "You are forbidden to access this resource."
                              })
  @default_unauthorized_response Jason.encode!(%{
                                   error: "UNAUTHORIZED",
                                   message: "You are unauthorized to access this resource."
                                 })

  def init(options), do: options

  def call(
        %Plug.Conn{
          assigns: %{
            upstream: %Upstream{authorize: false}
          }
        } = conn,
        _options
      ),
      do: conn

  def call(
        %Plug.Conn{
          assigns: %{
            current_request: current_request
          }
        },
        _options
      ),
      do: current_request

  def call(
        %Plug.Conn{} = conn,
        _options
      ) do
    case get_req_header(conn, "accept") do
      ["application/json"] -> handle_service_request(conn)
      _ -> handle_web_request(conn)
    end
  end

  def handle_service_request(
        %Plug.Conn{
          method: method,
          assigns: %{
            upstream: %Upstream{authorize: true, required_scopes: required_scopes} = upstream
          }
        } = conn
      ) do
    with [authorization_header] <- get_req_header(conn, "authorization"),
         [_header, value] <- Regex.run(~r/[B|b]earer (.+)/, authorization_header),
         {:ok, %Token{scope: scope} = token} <- Authorization.AccessToken.authorize(value: value),
         {:ok, _} <- validate_scopes(scope, required_scopes, method) do
      assign(conn, :token, token)
    else
      {:error, "required scopes are not present."} ->
        conn
        |> put_resp_content_type(upstream.error_content_type || @default_error_content_type)
        |> send_resp(:forbidden, upstream.forbidden_response || @default_forbidden_response)
        |> halt()

      _error ->
        conn
        |> put_resp_content_type(upstream.error_content_type || @default_error_content_type)
        |> send_resp(
          :unauthorized,
          upstream.unauthorized_response || @default_unauthorized_response
        )
        |> halt()
    end
  end

  def handle_web_request(
        %Plug.Conn{
          method: method,
          assigns: %{
            upstream: %Upstream{authorize: true, required_scopes: required_scopes}
          }
        } = conn
      ) do
    conn = fetch_session(conn)
    upstream = conn.assigns[:upstream]

    access_token =
      case get_session(conn, :token) do
        nil ->
          with [authorization_header] <- get_req_header(conn, "authorization"),
               [_header, value] <- Regex.run(~r/[B|b]earer (.+)/, authorization_header) do
            value
          else
            _ -> ""
          end

        token ->
          assign(conn, :token, token)
          token.value
      end

    with {:ok, %Token{scope: scope} = token} <-
           Authorization.AccessToken.authorize(value: access_token),
         {:ok, _} <- validate_scopes(scope, required_scopes, method) do
      assign(conn, :token, token)
    else
      _ ->
        state = SecureRandom.uuid()
        client = ClientsAdapter.public!()

        authorize_url =
          BorutaWeb.Router.Helpers.authorize_url(BorutaWeb.Endpoint, :authorize, %{
            client_id: client.id,
            redirect_uri:
              %URI{
                scheme: to_string(conn.scheme),
                host: conn.host,
                port: conn.port,
                path: "/callback"
              }
              |> URI.to_string(),
            scope: upstream
              |> Upstream.required_scopes(conn.method)
              |> Enum.join(" "),
            state: state,
            response_type: "code"
          })

        conn
        |> fetch_query_params()
        |> put_session(:current_request, conn)
        |> put_session(:current_state, state)
        |> put_resp_header("location", authorize_url)
        |> resp(302, "")
        |> halt()
    end
  end

  defp validate_scopes(_scope, required_scopes, _method) when required_scopes == %{},
    do: {:ok, []}

  defp validate_scopes(scope, required_scopes, method) do
    scopes = Scope.split(scope)
    default_scopes = Map.get(required_scopes, "*", [:not_authorized])

    case Enum.empty?(Map.get(required_scopes, method, default_scopes) -- scopes) do
      true -> {:ok, scopes}
      false -> {:error, "required scopes are not present."}
    end
  end
end
