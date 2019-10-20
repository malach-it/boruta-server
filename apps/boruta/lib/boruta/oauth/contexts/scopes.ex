defmodule Boruta.Oauth.Scopes do
  @moduledoc """
  Scope context
  """

  @callback public() :: list(Boruta.Oauth.Scope.t())
end
