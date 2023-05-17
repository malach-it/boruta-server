defmodule BorutaAdminWeb.KeyPairView do
  use BorutaAdminWeb, :view
  alias BorutaAdminWeb.KeyPairView

  def render("index.json", %{key_pairs: key_pairs}) do
    %{data: render_many(key_pairs, KeyPairView, "key_pair.json")}
  end

  def render("show.json", %{key_pair: key_pair}) do
    %{data: render_one(key_pair, KeyPairView, "key_pair.json")}
  end

  def render("key_pair.json", %{key_pair: key_pair}) do
    %{id: key_pair.id,
      public_key: key_pair.public_key,
      is_default: key_pair.is_default}
  end
end
