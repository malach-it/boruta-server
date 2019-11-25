defmodule Boruta.Oauth.Token do
  @moduledoc """
  Token schema. Representing both access tokens and codes.
  """

  alias Boruta.Oauth.Token

  defstruct [
    id: nil,
    type: nil,
    value: nil,
    state: nil,
    scope: nil,
    redirect_uri: nil,
    expires_at: nil,
    client: nil,
    resource_owner: nil,
    refresh_token: nil,
    inserted_at: nil
  ]

  @type t :: %__MODULE__{
    type:  String.t(),
    value: String.t(),
    state: String.t(),
    scope: String.t(),
    redirect_uri: String.t(),
    expires_at: integer(),
    client: Boruta.Oauth.Client.t(),
    resource_owner: struct(),
    refresh_token: String.t(),
    inserted_at: DateTime.t()
  }
  @doc """
  Determines if a token is expired

  ## Examples
      iex> expired?(%Boruta.Oauth.Token{expires_at: 1638316800}) # 1st january 2021
      :ok

      iex> expired?(%Boruta.Oauth.Token{expires_at: 0}) # 1st january 1970
      {:error, "Token expired."}
  """
  # TODO move this out of the schema
  @spec expired?(%Token{expires_at: integer()}) :: :ok | {:error, any()}
  def expired?(%Token{expires_at: expires_at}) do
    case :os.system_time(:seconds) <= expires_at do
      true -> :ok
      false -> {:error, "Token expired."}
    end
  end
end
