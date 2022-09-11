defmodule BorutaIdentity.Accounts.Ldap do
  @moduledoc false

  # @behaviour BorutaIdentity.Accounts.Sessions

  @features [
    :authenticable
  ]

  def features, do: @features

  # @impl BorutaIdentity.Accounts.Sessions
  # def get_user(backend, user_params)

  # @impl BorutaIdentity.Accounts.Sessions
  # def domain_user!(user, backend)

  # @impl BorutaIdentity.Accounts.Sessions
  # def check_user_against(backend, user, authentication_params)
end
