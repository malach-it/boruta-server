defmodule Boruta.Oauth.Client do
  @moduledoc """
  OAuth client schema
  """

  defstruct id: nil, secret: nil, authorize_scope: nil, authorized_scopes: [], redirect_uris: []

  @type t :: %__MODULE__{
    id: any(),
    secret: String.t(),
    authorize_scope: boolean(),
    authorized_scopes: list(Boruta.Oauth.Scope.t()),
    redirect_uris: list(String.t())
  }
end
