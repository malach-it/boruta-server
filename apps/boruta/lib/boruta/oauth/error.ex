defmodule Boruta.Oauth.Error do
  @moduledoc """
  Boruta OAuth errors

  Intended to follow [OAuth 2.0 errors](https://tools.ietf.org/html/rfc6749#section-5.2). Additionnal errors are provided as purpose.
  """

  alias Boruta.Oauth.CodeRequest
  alias Boruta.Oauth.Error
  alias Boruta.Oauth.TokenRequest

  @type t :: %__MODULE__{
    status: :bad_request | :unauthorized,
    error: :invalid_request | :invalid_client | :invalid_scope | :invalid_code | :invalid_resource_owner,
    error_description: String.t(),
    format: :query | :fragment | nil,
    redirect_uri: String.t() | nil
  }
  defstruct status: :status, error: :error, error_description: "", format: nil, redirect_uri: nil

  @spec with_format(error :: %Error{}, request :: %CodeRequest{} | %TokenRequest{}) :: Error.t()
  def with_format(%Error{} = error, %CodeRequest{redirect_uri: redirect_uri}) do
    %{error | format: :query, redirect_uri: redirect_uri}
  end
  def with_format(%Error{} = error, %TokenRequest{redirect_uri: redirect_uri}) do
    %{error | format: :fragment, redirect_uri: redirect_uri}
  end
  def with_format(error, _), do: error
end
