defmodule BorutaGateway.Authorization do
  @moduledoc false
  alias BorutaGateway.Authorization.{HttpBasic, OauthBearer, OauthSession}
  alias BorutaGateway.Upstreams.Upstream

  @callback authorize(binary(), binary(), Upstream.t(), binary()) :: tuple()

  def authorize(payload, method, upstream, scheme \\ "http")
  def authorize(_payload, _method, %Upstream{authorize: false}, _scheme), do: {:ok, nil}

  def authorize(payload, method, %Upstream{} = upstream, scheme) do
    case upstream.authorization_type do
      "http_basic" -> HttpBasic.authorize(payload, method, upstream, scheme)
      "oauth_bearer" -> OauthBearer.authorize(payload, method, upstream, scheme)
      "oauth_session" -> OauthSession.authorize(payload, method, upstream, scheme)
      _ -> BorutaGateway.Authorization.Helpers.unauthorized(upstream, nil)
    end
  end
end
