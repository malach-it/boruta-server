defmodule BorutaIdentity.Accounts.Ldap.User do
  @moduledoc false

  defstruct uid: nil, dn: nil, username: nil, backend: nil, metadata: nil

  @type t :: %__MODULE__{
    uid: String.t() | nil,
    dn: String.t() | nil,
    username: String.t() | nil,
    backend: BorutaIdentity.IdentityProviders.Backend.t() | nil,
    metadata: map() | nil
  }
end
