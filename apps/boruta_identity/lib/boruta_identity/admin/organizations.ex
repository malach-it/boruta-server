defmodule BorutaIdentity.Admin.Organizations do
  @moduledoc false

  import Ecto.Query

  alias BorutaIdentity.Organizations.Organization
  alias BorutaIdentity.Repo

  @spec list_organizations() :: Scrivener.Page.t()
  @spec list_organizations(params :: map()) :: Scrivener.Page.t()
  def list_organizations(params \\ %{}) do
    from(o in Organization)
    |> Repo.paginate(params)
  end

  @spec search_organizations(query :: String.t(), params :: map()) :: Scrivener.Page.t()
  @spec search_organizations(query :: String.t()) :: Scrivener.Page.t()
  def search_organizations(query, params \\ %{}) do
    from(o in Organization,
      where: fragment("name % ?", ^query),
      order_by: fragment("word_similarity(name, ?) DESC", ^query)
    )
    |> Repo.paginate(params)
  end
end
