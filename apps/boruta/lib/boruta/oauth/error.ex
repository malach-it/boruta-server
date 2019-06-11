defmodule Boruta.Oauth.Error do
  @moduledoc """
  Boruta OAuth errors

  Intended to follow [OAuth 2.0 errors](https://tools.ietf.org/html/rfc6749#section-5.2). Additionnal errors are provided as purpose.
  """
  @type t :: [
    status: :bad_request | :unauthorized,
    error: :invalid_request | :invalid_client | :invalid_scope | :invalid_code | :invalid_resource_owner,
    error_description: String.t(),
    format: :query | :fragment | nil,
    redirect_uri: String.t() | nil
  ]
  defstruct status: :status, error: :error, error_description: "", format: nil, redirect_uri: nil
end
