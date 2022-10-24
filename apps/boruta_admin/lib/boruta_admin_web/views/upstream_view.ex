defmodule BorutaAdminWeb.UpstreamView do
  use BorutaAdminWeb, :view
  alias BorutaAdminWeb.UpstreamView

  def render("index.json", %{upstreams: upstreams}) do
    %{data: render_many(upstreams, UpstreamView, "upstream.json")}
  end

  def render("show.json", %{upstream: upstream}) do
    %{data: render_one(upstream, UpstreamView, "upstream.json")}
  end

  def render("upstream.json", %{upstream: upstream}) do
    %{
      id: upstream.id,
      scheme: upstream.scheme,
      host: upstream.host,
      port: upstream.port,
      uris: upstream.uris,
      strip_uri: upstream.strip_uri,
      authorize: upstream.authorize,
      required_scopes: upstream.required_scopes,
      pool_size: upstream.pool_size,
      pool_count: upstream.pool_count,
      max_idle_time: upstream.max_idle_time,
      error_content_type: upstream.error_content_type,
      forbidden_response: upstream.forbidden_response,
      unauthorized_response: upstream.unauthorized_response,
      forwarded_token_signature_alg: upstream.forwarded_token_signature_alg,
      forwarded_token_secret: upstream.forwarded_token_secret
    }
  end
end
