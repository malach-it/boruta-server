defmodule BorutaIdentity.Accounts.Internal do
  @moduledoc """
  Internal database `Accounts` implementation.
  """
  @behaviour BorutaIdentity.Accounts

  alias BorutaIdentity.Accounts.Internal

  @impl BorutaIdentity.Accounts
  defdelegate register(user_params, confirmation_url_fun), to: Internal.Registrations
end
