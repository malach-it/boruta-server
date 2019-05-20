defmodule Boruta.Oauth.ClientCredentialsRequest do
  @behaviour Boruta.Oauth.Request

  defstruct client_id: "", client_secret: "", scope: ""
end
