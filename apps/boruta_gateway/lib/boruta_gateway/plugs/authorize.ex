defmodule BorutaGateway.Plug.Authorize do
  @moduledoc false

  import Plug.Conn

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
          method: method,
          assigns: %{
            upstream: %Upstream{authorize: true, required_scopes: required_scopes} = upstream
          }
        } = conn,
        _options
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

  def call(
        %Plug.Conn{
          assigns: %{
            upstream: %Upstream{authorize: false}
          }
        } = conn,
        _options
      ),
      do: conn

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
