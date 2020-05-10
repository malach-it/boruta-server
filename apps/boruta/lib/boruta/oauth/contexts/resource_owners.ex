defmodule Boruta.Oauth.ResourceOwners do
  @moduledoc """
  Resource owner context
  """
  # TODO remove password from get_by and move it to a check_password/2 callback
  @callback get_by(
    [username: String.t(), password: String.t()] |
    [id: String.t()]
  ) :: resource_owner :: struct() | nil
  @callback authorized_scopes(resource_owner :: struct()) :: list(Boruta.Oauth.Scope.t())
  @callback persisted?(resource_owner :: struct()) :: boolean()
end
