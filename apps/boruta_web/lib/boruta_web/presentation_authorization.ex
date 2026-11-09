defmodule BorutaWeb.PresentationAuthorization do
  @moduledoc false
  import Plug.Conn
  alias Boruta.Oauth
  @salt "presentation implicit authorization v1"

  def bind(conn, response) do
    if implicit?(response.code) do
      params = Map.take(conn.query_params, ~w(client_id redirect_uri state scope resource))

      params =
        Map.merge(params, %{
          "client_id" => response.client.id,
          "redirect_uri" => "http://localhost:4180/__implicit/callback",
          "scope" => response.code.scope,
          "state" => response.code.state,
          "response_type" => "token"
        })

      value =
        Plug.Crypto.encrypt(
          conn.secret_key_base,
          @salt,
          %{code: response.code.value, params: params},
          max_age: 300
        )

      conn
      |> clear_other_cookies(cookie_name(response.code.value))
      |> put_resp_cookie(cookie_name(response.code.value), value,
        http_only: true,
        secure: true,
        same_site: "Lax",
        max_age: 300,
        path: "/"
      )
    else
      conn
    end
  end

  defp clear_other_cookies(conn, current_name) do
    conn = fetch_cookies(conn)
    names = Map.keys(conn.req_cookies) ++ Map.keys(conn.resp_cookies)

    names
    |> Enum.uniq()
    |> Enum.reduce(conn, fn name, conn ->
      if name != current_name && String.starts_with?(name, "boruta_presentation_") do
        delete_resp_cookie(conn, name, path: "/", http_only: true, secure: true, same_site: "Lax")
      else
        conn
      end
    end)
  end

  def context(conn, code) do
    conn = fetch_cookies(conn)
    value = conn.cookies[cookie_name(code)]

    case value && Plug.Crypto.decrypt(conn.secret_key_base, @salt, value, max_age: 300) do
      {:ok, %{code: ^code, params: params}} ->
        {:ok, params}

      nil ->
        case Boruta.CodesAdapter.get_by(value: code) do
          %{} = token -> if implicit?(token), do: :error, else: {:ok, nil}
          _ -> {:ok, nil}
        end

      _ ->
        :error
    end
  end

  def complete(conn, code, params) do
    # Serialize completion for this code across connected gateway/issuer nodes.
    case :global.trans({{__MODULE__, code}, self()}, fn -> complete_locked(conn, code, params) end) do
      :aborted -> {:error, :invalid_presentation}
      result -> result
    end
  end

  defp complete_locked(conn, code, params) do
    with %Oauth.Token{} = token <- Boruta.CodesAdapter.get_by(value: code),
         :ok <- Oauth.Token.ensure_valid(token),
         true <- implicit?(token) && token.client.id == params["client_id"],
         %Oauth.ResourceOwner{} = owner <- token.resource_owner,
         true <- owner.sub == token.sub,
         {:ok, _revoked} <- Boruta.CodesAdapter.revoke(token) do
      conn = %{conn | query_params: params}
      Oauth.authorize(conn, owner, __MODULE__)
    else
      _ -> {:error, :invalid_presentation}
    end
  end

  def authorize_success(_conn, response),
    do: {:ok, Oauth.AuthorizeResponse.redirect_to_url(response)}

  def authorize_error(_conn, error), do: dbg(error) && {:error, :invalid_authorization}
  def resource_owner_error(_conn, _error), do: {:error, :invalid_resource_owner}

  def cookie_name(code),
    do: "boruta_presentation_" <> Base.url_encode64(:crypto.hash(:sha256, code), padding: false)

  defp implicit?(code) do
    types = String.split(code.response_type || "")
    List.first(types) == "vp_token"
  end
end
