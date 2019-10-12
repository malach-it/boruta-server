defmodule Boruta.Oauth.Authorization.Client do
  @moduledoc false

  import Boruta.Config, only: [repo: 0]

  alias Boruta.Oauth.Client
  alias Boruta.Oauth.Error

  @spec authorize(
    [id: String.t(), secret: String.t()] |
    [id: String.t(), redirect_uri: String.t()]
  ) ::
    {:ok, %Client{}}
    | {:error,
      %Error{
        :error => :invalid_client,
        :error_description => String.t(),
        :format => nil,
        :redirect_uri => nil,
        :status => :unauthorized
      }}
  def authorize(id: id, secret: secret) do
    case repo().get_by(Client, id: id, secret: secret) do
      %Client{} = client ->
        {:ok, client}
      nil ->
        {:error,
          %Error{
            status: :unauthorized,
            error: :invalid_client,
            error_description: "Invalid client_id or client_secret."
          }
        }
    end
  end
  def authorize(id: id, redirect_uri: redirect_uri) do
    case repo().get_by(Client, id: id, redirect_uri: redirect_uri) do
      %Client{} = client ->
        {:ok, client}
      nil ->
        {:error,
          %Error{
            status: :unauthorized,
            error: :invalid_client,
            error_description: "Invalid client_id or redirect_uri."
          }
        }
    end
  end
end
