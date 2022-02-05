defmodule BorutaWeb.Token do
  @moduledoc false

  use Joken.Config

  def application_signer do
    Joken.Signer.create(
      "HS512",
      Application.get_env(:boruta_web, BorutaWeb.Endpoint)[:secret_key_base]
    )
  end
end
