defmodule Boruta.Oauth.Authorization.AccessToken do
  @moduledoc false

  import Ecto.Query, only: [from: 2]
  import Boruta.Config, only: [repo: 0]

  alias Boruta.Oauth.Error
  alias Boruta.Oauth.Token

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
    with %Token{} = token <- repo().one(
      from t in Token,
      left_join: c in assoc(t, :client),
      left_join: u in assoc(t, :resource_owner),
      where: t.type == "access_token" and t.value == ^value,
      preload: [client: c, resource_owner: u]
    ),
      :ok <- Token.expired?(token) do
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
            error_description: "Provided access token is incorrect."
          }
        }
    end
  end
  def authorize(refresh_token: refresh_token) do
    with %Token{} = token <- repo().one(
      from t in Token,
      left_join: c in assoc(t, :client),
      left_join: u in assoc(t, :resource_owner),
      where: t.type == "access_token" and t.refresh_token == ^refresh_token,
      preload: [client: c, resource_owner: u]
    ),
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
