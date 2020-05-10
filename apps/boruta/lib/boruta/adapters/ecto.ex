defmodule Boruta.EctoAdapter do
  @moduledoc false

  def access_tokens, do: Boruta.Ecto.AccessTokens
  def clients, do: Boruta.Ecto.Clients
  def codes, do: Boruta.Ecto.Codes
  def scopes, do: Boruta.Ecto.Scopes
end
