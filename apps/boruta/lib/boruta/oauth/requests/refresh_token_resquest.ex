defmodule Boruta.Oauth.RefreshTokenRequest do
  @moduledoc """
  Refresh toekn request
  """

  @typedoc """
  Type representing a refresh token request as stated in [OAuth 2.0 RFC](https://tools.ietf.org/html/rfc6749#section-6).
  """
  @type t :: %__MODULE__{
    client_id: String.t(),
    client_secret: String.t(),
    refresh_token: String.t()
  }
  defstruct client_id: "", client_secret: "", refresh_token: "", scope: ""
end
