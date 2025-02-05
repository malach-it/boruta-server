defmodule BorutaFederation.FederationEntities do
  @moduledoc false

  import Ecto.Query
  import Boruta.Config, only: [issuer: 0]

  alias BorutaFederation.FederationEntities.ClientFederationEntity
  alias BorutaFederation.FederationEntities.FederationEntity
  alias BorutaFederation.Repo

  @spec list_entities() :: entity_list :: list(FederationEntity.t())
  def list_entities do
    Repo.all(FederationEntity)
  end

  @spec get_entity(sub :: String.t()) :: federation_entity :: FederationEntity.t() | nil
  def get_entity(sub) do
    id = String.replace_prefix(sub, issuer() <> "/federation/federation_entities/", "")

    case Ecto.UUID.cast(id) do
      {:ok, _} ->
        Repo.get(FederationEntity, id)

      _ ->
        nil
    end
  end

  @spec get_entity_by_id(id :: Ecto.UUID.t()) :: federation_entity :: FederationEntity.t() | nil
  def get_entity_by_id(id) do
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
    with {_, _} <-
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

  def create_example_tree(nodes \\ [], count \\ 10)
  def create_example_tree(_nodes, 0), do: :ok

  def create_example_tree([], count) do
    with {:ok, node} <-
           create_entity(%{
             organization_name: SecureRandom.hex(),
             authorities: []
           }) do
      create_example_tree([node], count - 1)
    end
  end

  def create_example_tree(nodes, count) do
    authority_entities =
      Enum.map(
        0..Enum.random(1..10),
        fn _i ->
          entity = Enum.random(nodes)
        end
      ) |> Enum.uniq()

    authorities =
      Enum.map(authority_entities, fn entity ->
        %{
          "issuer" => issuer(),
          "sub" => issuer() <> "/federation/federation_entities/" <> entity.id
        }
      end)

    with {:ok, node} <-
           create_entity(%{
             organization_name: SecureRandom.hex(),
             authorities: authorities
           }) do
      create_example_tree([node | nodes], count - 1)
    end
  end
end
