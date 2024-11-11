defmodule BorutaFederation.FederationEntities do
  @moduledoc false

  import Ecto.Query

  alias BorutaFederation.FederationEntities.ClientFederationEntity
  alias BorutaFederation.FederationEntities.FederationEntity
  alias BorutaFederation.Repo

  @spec list_entities() :: entity_list :: list(FederationEntity.t())
  def list_entities do
    Repo.all(FederationEntity)
  end

  @spec get_entity(id :: Ecto.UUID.t()) :: federation_entity :: FederationEntity.t() | nil
  def get_entity(id) do
    case Ecto.UUID.cast(id) do
      {:ok, _} ->
        Repo.get(FederationEntity, id)

      _ ->
        nil
    end
  end

  @spec create_entity(
          create_params :: %{
            :organization_name => String.t(),
            optional(:type) => String.t(),
            optional(:key_pair_type) => map()
          }
        ) :: {:ok, entity :: FederationEntity.t()} | {:error, Ecto.Changeset.t()}
  def create_entity(params) do
    FederationEntity.create_changeset(%FederationEntity{}, params)
    |> Repo.insert()
  end

  @spec delete_entity(entity_id :: Ecto.UUID.t()) ::
          {:ok, entity :: FederationEntity.t()}
          | {:error, atom()}
          | {:error, Ecto.Changeset.t()}
          | {:error, reason :: String.t()}
  def delete_entity(entity_id) when is_binary(entity_id) do
    case get_entity(entity_id) do
      nil ->
        {:error, :not_found}

      entity ->
        Repo.delete(entity)
    end
  end

  @spec upsert_client_federation_entity(
          client_id :: String.t(),
          federation_entity_id :: String.t() | nil
        ) ::
          {:ok, client_federation_entity :: ClientFederationEntity.t() | nil}
          | {:error, changeset :: Ecto.Changeset.t()}
  def upsert_client_federation_entity(client_id, nil) do
    with {1, _} <-
           Repo.delete_all(from cfe in ClientFederationEntity, where: cfe.client_id == ^client_id) do
      {:ok, nil}
    end
  end

  def upsert_client_federation_entity(client_id, federation_entity_id) do
    %ClientFederationEntity{}
    |> ClientFederationEntity.changeset(%{
      client_id: client_id,
      federation_entity_id: federation_entity_id
    })
    |> Repo.insert(
      on_conflict: [set: [federation_entity_id: federation_entity_id]],
      conflict_target: :client_id
    )
  end

  @spec get_federation_entity_by_client_id(client_id :: String.t()) ::
          federation_entity :: FederationEntity.t() | nil
  def get_federation_entity_by_client_id(client_id) do
    case Ecto.UUID.cast(client_id) do
      {:ok, client_id} ->
        Repo.one(
          from(fe in FederationEntity,
            join: cfe in assoc(fe, :client_federation_entities),
            where: cfe.client_id == ^client_id
          )
        )

      :error ->
        nil
    end
  end
end
