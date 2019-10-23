defmodule Boruta.Oauth.Authorization.Client do
  @moduledoc """
  Client authorization
  """

  import Boruta.Config, only: [clients: 0]

  alias Boruta.Oauth.Client
  alias Boruta.Oauth.Error

  @doc """
  Authorize the client corresponding to the given params.

  ## Examples
      iex> authorize(id: "id", secret: "secret")
      {:ok, %Boruta.Oauth.Client{...}}
  """
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
    case clients().get_by(id: id, secret: secret) do
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
    case clients().get_by(id: id, redirect_uri: redirect_uri) do
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
