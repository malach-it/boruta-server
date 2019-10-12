defmodule Boruta.Oauth.Authorization.Code do
  @moduledoc false

  import Boruta.Config, only: [repo: 0]

  alias Boruta.Oauth.Error
  alias Boruta.Oauth.Token

  @spec authorize(%{
    value: String.t(),
    redirect_uri: String.t()
  }) ::
    {:error,
     %Error{
       :error => :invalid_code,
       :error_description => String.t(),
       :format => nil,
       :redirect_uri => nil,
       :status => :bad_request
     }}
    | {:ok, %Token{}}
  def authorize(%{value: value, redirect_uri: redirect_uri}) do
    with %Token{} = token <- repo().get_by(Token, type: "code", value: value, redirect_uri: redirect_uri),
      :ok <- Token.expired?(token) do
      {:ok, token}
    else
      {:error, error} ->
        {:error, %Error{status: :bad_request, error: :invalid_code, error_description: error}}
      nil ->
        {:error, %Error{status: :bad_request, error: :invalid_code, error_description: "Provided authorization code is incorrect."}}
    end
  end
end
