defmodule Boruta.Oauth.Error do
  defstruct status: :status, error: :error, error_description: "", format: :format, redirect_uri: ""
end
