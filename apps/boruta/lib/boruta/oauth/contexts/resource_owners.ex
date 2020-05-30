defmodule Boruta.Oauth.ResourceOwners do
  @moduledoc """
  Resource owner context
  """
  # TODO remove password from get_by and move it to a check_password/2 callback
  @doc """
  Returns a resource owner by (username, password) or (id). Returns nil for non matching results.
  """
  @callback get_by(
    [username: String.t(), password: String.t()] |
    [id: String.t()]
  ) :: resource_owner :: struct() | nil

  @doc """
  Returns a list of authorized scopes for a given resource owner. These scopes will be granted is requested for the user.
  """
  @callback authorized_scopes(resource_owner :: struct()) :: list(Boruta.Oauth.Scope.t())

  @doc """
  Returns true whenever the given resource owner is persisted.
  """
  @callback persisted?(resource_owner :: struct()) :: boolean()
end
