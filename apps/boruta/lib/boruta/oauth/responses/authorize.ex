defmodule Boruta.Oauth.AuthorizeResponse do
  @moduledoc """
  Authorize response
  """

  defstruct type: nil, redirect_uri: nil, value: nil, expires_in: nil, state: nil

  @type t :: %__MODULE__{
    type: String.t(),
    redirect_uri: String.t(),
    value: String.t(),
    expires_in: integer(),
    state: String.t()
  }

  alias Boruta.Oauth.AuthorizeResponse
  alias Boruta.Oauth.Token

  @spec from_token(token :: Boruta.Oauth.Token.t()) :: t()
  def from_token(%Token{
    type: type,
    expires_at: expires_at,
    value: value,
    redirect_uri: redirect_uri,
    state: state
  }) do
    {:ok, expires_at} = DateTime.from_unix(expires_at)
    expires_in =  DateTime.diff(expires_at, DateTime.utc_now)

    %AuthorizeResponse{
      type: type,
      redirect_uri: redirect_uri,
      value: value,
      expires_in: expires_in,
      state: state
    }
  end
end
