defmodule BorutaWeb.Plugs.RateLimit do
  @moduledoc false

  use BorutaWeb, :controller

  alias BorutaWeb.OauthView

  def init(options), do: options

  def call(conn, options) do
    remote_ip = :inet.ntoa(conn.remote_ip)

    # TODO fix rate limiting, the request is denied once but not for a duration
    case Hammer.check_rate("request:#{remote_ip}", options[:duration] || 1000, options[:limit] || 10) do
      {:allow, _count} ->
        conn
      {:deny, limit} ->
        conn
        |> put_status(:too_many_requests)
        |> put_view(OauthView)
        |> render("error.json", %{error: "too many requests", error_description: "Rate limit reached: #{limit}"})
        |> halt()
    end
  end
end
