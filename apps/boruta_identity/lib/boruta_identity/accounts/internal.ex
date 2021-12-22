defmodule BorutaIdentity.Accounts.Internal do
  @moduledoc """
  Internal database `Accounts` implementation.
  """
  @behaviour BorutaIdentity.Accounts

  alias BorutaIdentity.Accounts.Internal

  @impl BorutaIdentity.Accounts
  defdelegate register(user_params), to: Internal.Registrations
end
