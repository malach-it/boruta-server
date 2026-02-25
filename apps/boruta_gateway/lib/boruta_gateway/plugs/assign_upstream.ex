defmodule BorutaGateway.Plug.AssignUpstream do
  @moduledoc false

  import Plug.Conn

  alias Boruta.ClientsAdapter
  alias BorutaGateway.Upstreams
  alias BorutaGateway.Upstreams.Upstream

  require Logger

  def init(options), do: options

  def call(
        %Plug.Conn{
          path_info: ["callback"]
        } = conn,
        _options
      ) do
    conn =
      conn
      |> fetch_query_params()
    client = ClientsAdapter.public!()

    with %{"code" => code} <- conn.query_params do
      Boruta.Oauth.token(
        %{
          conn |
          body_params: %{
            "client_id" => client.id,
            "client_secret" => client.secret,
            "code" => code,
            "redirect_uri" =>
            %URI{
              scheme: to_string(conn.scheme),
              host: conn.host,
              port: conn.port,
              path: "/callback"
            }
            |> URI.to_string(),
            "grant_type" => "authorization_code"
          }
        },
        __MODULE__
      )
    end
  end

  def token_success(conn, response) do
    conn =
      conn
      |> fetch_session()

    path = get_session(conn, :current_request).request_path
    conn
    |> put_session(:token, response.token)
    |> put_resp_header("location", path)
    |> resp(302, "")
    |> halt()
  end

  def token_error(conn, error) do
    dbg(error)

    conn
    |> send_resp(401, inspect(error))
    |> halt()
  end

  def call(
        %Plug.Conn{
          path_info: path_info
        } = conn,
        _options
      ) do
    conn = assign(conn, :node_name, "global")

    case Upstreams.match(path_info) do
      %Upstream{} = upstream ->
        conn = fetch_session(conn)

        case get_session(conn, :current_request) do
          nil ->
            assign(conn, :upstream, upstream)

          current_request ->
            assign(conn, :upstream, upstream)
        end

      nil ->
        conn
        |> send_resp(404, "No upstream has been found corresponding to the given request.")
        |> halt()
    end
  end
end
