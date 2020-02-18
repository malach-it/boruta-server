defmodule Boruta.Oauth.RefreshTokenRequest do
  @moduledoc """
  Refresh token request
  """

  @typedoc """
  Type representing a refresh token request as stated in [OAuth 2.0 RFC](https://tools.ietf.org/html/rfc6749#section-1.5).
  """
  @type t :: %__MODULE__{
    client_id: String.t(),
    client_secret: String.t(),
    refresh_token: String.t(),
    scope: String.t(),
    grant_type: String.t()
  }
  defstruct client_id: "", client_secret: "", refresh_token: "", scope: "", grant_type: "refresh_token"
end
