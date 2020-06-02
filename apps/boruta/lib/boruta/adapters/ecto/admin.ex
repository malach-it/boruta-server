defmodule Boruta.Ecto.Admin do
  # TODO move to Boruta.Oauth.Admin
  @moduledoc """
  The Ecto.Admin context.
  """

  defdelegate list_clients, to: Boruta.Ecto.Admin.Clients
  defdelegate get_client!(id), to: Boruta.Ecto.Admin.Clients
  defdelegate create_client(attrs), to: Boruta.Ecto.Admin.Clients
  defdelegate update_client(client, attrs), to: Boruta.Ecto.Admin.Clients
  defdelegate delete_client(client), to: Boruta.Ecto.Admin.Clients

  defdelegate list_scopes, to: Boruta.Ecto.Admin.Scopes
  defdelegate get_scope!(id), to: Boruta.Ecto.Admin.Scopes
  defdelegate get_scopes_by_ids(ids), to: Boruta.Ecto.Admin.Scopes
  defdelegate create_scope(attrs), to: Boruta.Ecto.Admin.Scopes
  defdelegate update_scope(scope, attrs), to: Boruta.Ecto.Admin.Scopes
  defdelegate delete_scope(scope), to: Boruta.Ecto.Admin.Scopes
end
