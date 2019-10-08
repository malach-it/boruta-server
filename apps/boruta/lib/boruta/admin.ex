defmodule Boruta.Admin do
  @moduledoc """
  The Admin context.
  """

  defdelegate list_clients, to: Boruta.Admin.Clients
  defdelegate get_client!(id), to: Boruta.Admin.Clients
  defdelegate create_client(attrs), to: Boruta.Admin.Clients
  defdelegate update_client(client, attrs), to: Boruta.Admin.Clients
  defdelegate delete_client(client), to: Boruta.Admin.Clients

  defdelegate list_scopes, to: Boruta.Admin.Scopes
  defdelegate get_scope!(id), to: Boruta.Admin.Scopes
  defdelegate create_scope(attrs), to: Boruta.Admin.Scopes
  defdelegate update_scope(scope, attrs), to: Boruta.Admin.Scopes
  defdelegate delete_scope(scope), to: Boruta.Admin.Scopes

  defdelegate list_users, to: Boruta.Admin.Users
  defdelegate get_user!(id), to: Boruta.Admin.Users
  defdelegate update_user(user, attrs), to: Boruta.Admin.Users
  defdelegate delete_user(user), to: Boruta.Admin.Users
end
