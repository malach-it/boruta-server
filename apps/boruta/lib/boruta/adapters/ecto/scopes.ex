defmodule Boruta.Ecto.Scopes do
  @moduledoc false

  @behaviour Boruta.Oauth.Scopes

  import Ecto.Query, only: [from: 2]
  import Boruta.Config, only: [repo: 0]

  alias Boruta.Ecto
  alias Boruta.Oauth

  @impl Boruta.Oauth.Scopes
  def public do
    repo().all(
      from s in Ecto.Scope,
        where: s.public == true
    )
    |> Enum.map(&to_oauth_schema/1)
  end

  def to_oauth_schema(nil), do: nil

  def to_oauth_schema(%Ecto.Scope{} = scope) do
    struct(Oauth.Scope, Map.from_struct(scope))
  end
end
