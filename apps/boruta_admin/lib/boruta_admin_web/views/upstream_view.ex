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
      required_scopes: upstream.required_scopes
    }
  end
end
