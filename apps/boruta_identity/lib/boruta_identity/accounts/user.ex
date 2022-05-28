defmodule BorutaIdentity.Accounts.User do
  @moduledoc false

  use Ecto.Schema

  @type t :: %__MODULE__{
          email: String.t(),
          password: String.t(),
          confirmed_at: NaiveDateTime.t(),
          # authorized_scopes: Ecto.Association.NotLoaded.t() | list(UserAuthorizedScope.t()),
          # consents: Ecto.Association.NotLoaded.t() | list(Consent.t()),
          last_login_at: DateTime.t(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  @derive {Inspect, except: [:password]}
  @primary_key {:id, Ecto.UUID, autogenerate: true}
  @foreign_key_type :binary_id
  embedded_schema do
    field(:email, :string)
    field(:password, :string)
    field(:confirmed_at, :utc_datetime_usec)
    field(:last_login_at, :utc_datetime_usec)

    embeds_many(:authorized_scopes, UserAuthorizedScope)
    embeds_many(:consents, Consent, on_replace: :delete)

    timestamps()
  end
end
