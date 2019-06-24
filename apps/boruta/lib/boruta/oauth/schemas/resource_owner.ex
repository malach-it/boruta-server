defmodule Boruta.Oauth.ResourceOwner do
  @moduledoc """
  Resource owner behaviour

  Implement this behaviour for OAuth resource owners. It will be used in flows interacting with resource owners in two manners :
  - by identifying them from the parameters given during the request lifecycle in implicit or code grants
  - by challenging the couple email/password given by the client in resource owner password credentials

  In order to do that resource owners must have an Ecto schema with `id`, `password_hash` entries and following callback. Providing a resource owner during request can be done by assigning `current_user` in `Plug.Conn` struct.

  They will be then linked to the provided token.
  """

  @doc """
  Check user password against password hash
  """
  @callback checkpw(password :: String.t(), password_hash :: String.t()) :: boolean()
end
