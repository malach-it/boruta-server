defmodule Boruta.TokenGenerator do
  @moduledoc false

  @behaviour Boruta.Oauth.TokenGenerator

  use Puid, bits: 512, charset: :alphanum

  alias Boruta.Oauth.Token

  @impl Boruta.Oauth.TokenGenerator
  def generate(_, %Token{}) do
    generate()
  end
end
