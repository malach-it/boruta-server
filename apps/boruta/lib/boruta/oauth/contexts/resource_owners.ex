defmodule Boruta.Oauth.ResourceOwners do
  @moduledoc """
  Resource owner context
  """
  @callback get_by(
    [username: String.t(), password: String.t()]
  ) :: resource_owner :: struct() | nil
  @callback authorized_scopes(resource_owner :: struct()) :: list(Boruta.Oauth.Scope.t())
  @callback persisted?(resource_owner :: struct()) :: boolean()
end
