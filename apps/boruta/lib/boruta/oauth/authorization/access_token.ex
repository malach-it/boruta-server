defmodule Boruta.Oauth.Authorization.AccessToken do
  @moduledoc """
  Access token authorization
  """

  import Boruta.Config, only: [access_tokens: 0]

  alias Boruta.Oauth.Error
  alias Boruta.Oauth.Token

  @doc """
  Authorize the access token corresponding to the given params.

  ## Examples
      iex> authorize(%{value: "value"})
      {:ok, %Boruta.Oauth.Token{...}}
  """
  @spec authorize(params ::
    [value: String.t()] |
    [refresh_token: String.t()]
  ) ::
    {:error,
     %Error{
       :error => :invalid_access_token,
       :error_description => String.t(),
       :format => nil,
       :redirect_uri => nil,
       :status => :unauthorized
     }}
    | {:ok, %Token{}}
  def authorize(value: value) do
    with %Token{} = token <- access_tokens().get_by(value: value),
      :ok <- Token.expired?(token),
      :ok <- Token.revoked?(token) do
      {:ok, token}
    else
      {:error, error} ->
        {:error,
          %Error{
            status: :bad_request,
            error: :invalid_access_token,
            error_description: error
          }
        }
      nil ->
        {:error,
          %Error{
            status: :bad_request,
            error: :invalid_access_token,
            error_description: "Provided access token is invalid."
          }
        }
    end
  end
  def authorize(refresh_token: refresh_token) do
    with %Token{} = token <- access_tokens().get_by(refresh_token: refresh_token),
      :ok <- Token.expired?(token) do
      {:ok, token}
    else
      {:error, error} ->
        {:error,
          %Error{
            status: :bad_request,
            error: :invalid_refresh_token,
            error_description: error
          }
        }
      nil ->
        {:error,
          %Error{
            status: :bad_request,
            error: :invalid_refresh_token,
            error_description: "Provided refresh token is incorrect."
          }
        }
    end
  end
end
