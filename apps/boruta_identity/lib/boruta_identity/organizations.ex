defmodule BorutaIdentity.Organizations do
  @moduledoc false

  import Ecto.Query

  alias BorutaIdentity.Organizations.Organization
  alias BorutaIdentity.Repo

  @type organization_params :: %{
          name: String.t(),
          label: String.t() | nil
        }

  @spec list_organizations() :: Scrivener.Page.t()
  @spec list_organizations(params :: map()) :: Scrivener.Page.t()
  def list_organizations(params \\ %{}) do
    from(o in Organization)
    |> Repo.paginate(Map.merge(params, %{"page_size" => 500}))
  end

  # @spec search_organizations(query :: String.t(), params :: map()) :: Scrivener.Page.t()
  # @spec search_organizations(query :: String.t()) :: Scrivener.Page.t()
  # def search_organizations(query, params \\ %{}) do
  #   from(o in Organization,
  #     where: fragment("name % ?", ^query),
  #     order_by: fragment("word_similarity(name, ?) DESC", ^query)
  #   )
  #   |> Repo.paginate(params)
  # end

  @spec create_organization(organization_params :: organization_params()) ::
          {:ok, organization :: Organization.t()} | {:error, changeset :: Ecto.Changeset.t()}
  def create_organization(organization_params) do
    Organization.changeset(%Organization{}, organization_params)
    |> Repo.insert()
  end

  @spec delete_organization(organization_id :: String.t()) ::
          {:ok, organization :: Organization.t()} | {:error, changeset :: Ecto.Changeset.t()}
  def delete_organization(organization_id) do
    case get_organization(organization_id) do
      nil ->
        {:error, :not_found}

      organization ->
        Repo.delete(organization)
    end
  end

  @spec get_organization(organization_id :: String.t()) :: organization :: Organization.t() | nil
  def get_organization(organization_id) do
    case Ecto.UUID.cast(organization_id) do
      {:ok, _} ->
        Repo.get(Organization, organization_id)

      _ ->
        nil
    end
  end

  @spec update_organization(
          organization :: Organization.t(),
          organization_params :: organization_params()
        ) :: {:ok, organization :: Organization.t()} | {:error, changeset :: Ecto.Changeset.t()}
  def update_organization(organization, organization_params) do
    Organization.changeset(organization, organization_params)
    |> Repo.update()
  end
end
