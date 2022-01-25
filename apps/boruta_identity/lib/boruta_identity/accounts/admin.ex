defmodule BorutaIdentity.Accounts.AdminApplication do
  @moduledoc """
  TODO AdminApplication documentation
  """

  @callback user_list(context :: any(), users :: list(BorutaIdentity.Accounts.User.t())) :: any()
end

defmodule BorutaIdentity.Accounts.Admin do
  @moduledoc false

  alias BorutaIdentity.Accounts.User
  alias BorutaIdentity.RelyingParties
  alias BorutaIdentity.RelyingParties.RelyingParty

  @callback list_users(relying_party_id :: String.t()) :: list(User.t())

  @spec list_users(context :: any(), relying_party_id :: String.t(), module :: atom()) :: users :: list(User.t())
  def list_users(context, relying_party_id, module) do
    with %RelyingParty{} = relying_party <- RelyingParties.get_relying_party!(relying_party_id),
         client_impl <- RelyingParty.implementation(relying_party) do

      users = apply(client_impl, :list_users, [relying_party.id])

      module.user_list(context, users)
    else
      _ -> []
    end
  end
end
