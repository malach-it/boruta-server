defmodule BorutaIdentity.Admin do
  @moduledoc """
  TODO Admin documentation
  """

  import Ecto.Query

  alias Boruta.Ecto.Admin
  alias BorutaIdentity.Accounts.User
  alias BorutaIdentity.Accounts.UserAuthorizedScope
  alias BorutaIdentity.Accounts.UserRole
  alias BorutaIdentity.IdentityProviders.Backend
  alias BorutaIdentity.Organizations.OrganizationUser
  alias BorutaIdentity.Repo
  alias NimbleCSV.RFC4180, as: CSV

  @type user_params ::
          %{
            optional(:username) => String.t(),
            optional(:password) => String.t(),
            optional(:group) => String.t(),
            optional(:metadata) => map(),
            optional(:roles) => list(map()),
            optional(:authorized_scopes) => list(map()),
            optional(:organizations) => list(map())
          }

  @type raw_user_params :: %{
          username: String.t(),
          hashed_password: String.t()
        }

  @callback delete_user(id :: String.t()) :: :ok | {:error, reason :: String.t()}
  @callback create_user(
              backend :: Backend.t(),
              params :: user_params()
            ) ::
              {:ok, User.t()} | {:error, changeset :: Ecto.Changeset.t()}

  @callback create_raw_user(
              backend :: Backend.t(),
              params :: user_params()
            ) ::
              {:ok, User.t()} | {:error, changeset :: Ecto.Changeset.t()}

  @spec list_users(params :: map()) :: Scrivener.Page.t()
  @spec list_users() :: Scrivener.Page.t()
  def list_users(params \\ %{}) do
    from(u in User)
    |> user_preloads()
    |> Repo.paginate(params)
  end

  @spec search_users(query :: String.t(), params :: map()) :: Scrivener.Page.t()
  @spec search_users(query :: String.t()) :: Scrivener.Page.t()
  def search_users(query, params \\ %{}) do
    from(u in User,
      where: fragment("username % ?", ^query),
      order_by: fragment("word_similarity(username, ?) DESC", ^query)
    )
    |> user_preloads()
    |> Repo.paginate(params)
  end

  @doc """
  Gets a single user.

  ## Examples

      iex> get_user(123)
      %User{}

      iex> get_user(456)
      nil

  """
  @spec get_user(id :: Ecto.UUID.t()) :: user :: User.t() | nil
  def get_user(id) do
    Repo.one(
      from(u in User,
        left_join: as in assoc(u, :authorized_scopes),
        left_join: r in assoc(u, :roles),
        left_join: o in assoc(u, :organizations),
        join: b in assoc(u, :backend),
        preload: [authorized_scopes: as, roles: r, backend: b, organizations: o],
        where: u.id == ^id
      )
    )
  end

  use BorutaIdentity.PostUserCreationHook

  @spec create_user(backend :: Backend.t(), params :: user_params()) ::
          {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  @decorate post_user_creation_hook([])
  def create_user(backend, params) do
    with {:ok, user} <-
           apply(
             Backend.implementation(backend),
             :create_user,
             [backend, params]
           ),
         {:ok, user} <- update_user_authorized_scopes(user, params[:authorized_scopes] || []),
         {:ok, user} <- update_user_organizations(user, params[:organizations] || []),
         {:ok, user} <- update_user_roles(user, params[:roles] || []) do
      {:ok, user}
    end
  end

  @spec create_raw_user(backend :: Backend.t(), params :: raw_user_params()) ::
          {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  @decorate post_user_creation_hook([])
  def create_raw_user(backend, params) do
    # TODO give the ability to provide authorized scopes at user creation
    apply(
      Backend.implementation(backend),
      :create_raw_user,
      [backend, params]
    )
  end

  @type import_users_opts :: %{
          optional(:username_header) => String.t(),
          optional(:password_header) => String.t(),
          optional(:hash_password) => boolean()
        }

  @spec import_users(backend :: Backend.t(), csv_path :: String.t(), opts :: import_users_opts()) ::
          import_result :: map()
  def import_users(backend, csv_path, opts \\ %{}) do
    opts =
      Map.merge(
        %{
          username_header: "username",
          password_header: "password",
          hash_password: false
        },
        opts
      )

    headers =
      File.stream!(csv_path)
      |> CSV.parse_stream(skip_headers: false)
      |> Enum.take(1)
      |> Enum.reduce(%{}, fn headers, _acc ->
        username_index =
          Enum.find_index(headers, fn header -> header == opts[:username_header] end)

        password_index =
          Enum.find_index(headers, fn header -> header == opts[:password_header] end)

        %{username: username_index, password: password_index}
      end)

    File.stream!(csv_path)
    |> CSV.parse_stream(skip_headers: true)
    |> Stream.map(fn row ->
      case opts[:hash_password] do
        true ->
          create_params = %{
            username: headers[:username] && Enum.at(row, headers[:username]),
            password: headers[:password] && Enum.at(row, headers[:password])
          }

          create_user(backend, create_params)

        false ->
          create_params = %{
            username: headers[:username] && Enum.at(row, headers[:username]),
            hashed_password: headers[:password] && Enum.at(row, headers[:password])
          }

          create_raw_user(backend, create_params)
      end
    end)
    |> Stream.with_index(1)
    |> Enum.reduce(
      %{success_count: 0, error_count: 0, errors: []},
      fn
        {{:ok, _user}, _line},
        %{
          success_count: success_count,
          error_count: error_count,
          errors: errors
        } ->
          %{
            success_count: success_count + 1,
            error_count: error_count,
            errors: errors
          }

        {{:error, changeset}, line},
        %{
          success_count: success_count,
          error_count: error_count,
          errors: errors
        } ->
          %{
            success_count: success_count,
            error_count: error_count + 1,
            errors: errors ++ [%{line: line, changeset: changeset}]
          }
      end
    )
    |> Enum.into(%{})
  end

  @spec update_user_authorized_scopes(user :: %User{}, scopes :: list(map())) ::
          {:ok, %User{}} | {:error, Ecto.Changeset.t()}
  def update_user_authorized_scopes(%User{id: user_id} = user, scopes) do
    Repo.delete_all(from(s in UserAuthorizedScope, where: s.user_id == ^user_id))

    case Enum.reduce(scopes, Ecto.Multi.new(), fn attrs, multi ->
           changeset =
             UserAuthorizedScope.changeset(
               %UserAuthorizedScope{},
               %{
                 "scope_id" => attrs["id"] || attrs[:scope_id],
                 "user_id" => user.id
               }
             )

           Ecto.Multi.insert(multi, "scope_-#{SecureRandom.uuid()}", changeset)
         end)
         |> Repo.transaction() do
      {:ok, _result} ->
        {:ok, user |> Repo.reload() |> user_preloads()}

      {:error, _multi_name, %Ecto.Changeset{} = changeset, _changes} ->
        {:error, changeset}
    end
  end

  @spec update_user_roles(user :: %User{}, roles :: list(map())) ::
          {:ok, %User{}} | {:error, Ecto.Changeset.t()}
  def update_user_roles(%User{id: user_id} = user, roles) do
    Repo.delete_all(from(s in UserRole, where: s.user_id == ^user_id))

    case Enum.reduce(roles, Ecto.Multi.new(), fn attrs, multi ->
           changeset =
             UserRole.changeset(
               %UserRole{},
               %{
                 "role_id" => attrs["id"] || attrs[:role_id],
                 "user_id" => user.id
               }
             )

           Ecto.Multi.insert(multi, "role_-#{SecureRandom.uuid()}", changeset)
         end)
         |> Repo.transaction() do
      {:ok, _result} ->
        {:ok, user |> Repo.reload() |> user_preloads()}

      {:error, _multi_name, %Ecto.Changeset{} = changeset, _changes} ->
        {:error, changeset}
    end
  end

  @spec update_user_organizations(user :: %User{}, organizations :: list(map())) ::
          {:ok, %User{}} | {:error, Ecto.Changeset.t()}
  def update_user_organizations(%User{id: user_id} = user, organizations) do
    Repo.delete_all(from(o in OrganizationUser, where: o.user_id == ^user_id))

    case Enum.reduce(organizations, Ecto.Multi.new(), fn attrs, multi ->
           changeset =
             OrganizationUser.changeset(
               %OrganizationUser{},
               %{
                 "organization_id" => attrs["id"] || attrs[:organization_id],
                 "user_id" => user.id
               }
             )

           Ecto.Multi.insert(multi, "organization_-#{SecureRandom.uuid()}", changeset)
         end)
         |> Repo.transaction() do
      {:ok, _result} ->
        {:ok, user |> Repo.reload() |> user_preloads()}

      {:error, _multi_name, %Ecto.Changeset{} = changeset, _changes} ->
        {:error, changeset}
    end
  end

  @spec update_user(user :: User.t(), user_params :: user_params()) ::
          {:ok, user :: User.t()} | {:error, Ecto.Changeset.t()}
  def update_user(user, user_params) do
    with {:ok, user} <-
           user
           |> User.changeset(user_params)
           |> Repo.update(),
         {:ok, user} <-
           update_user_authorized_scopes(
             user,
             user_params[:authorized_scopes] || user.authorized_scopes
           ),
         {:ok, user} <-
           update_user_organizations(
             user,
             user_params[:organizations] || user.organizations
           ) do
      update_user_roles(user, user_params[:roles] || user.roles)
    end
  end

  @spec delete_user(user_id :: Ecto.UUID.t()) ::
          {:ok, user :: User.t()}
          | {:error, atom()}
          | {:error, Ecto.Changeset.t()}
          | {:error, reason :: String.t()}
  def delete_user(user_id) when is_binary(user_id) do
    case get_user(user_id) do
      nil ->
        {:error, :not_found}

      user ->
        # TODO delete both provider and domain users in a transaction
        # TODO manage identity federated users
        with :ok <- apply(Backend.implementation(user.backend, user.account_type), :delete_user, [user.uid]) do
          Repo.delete(user)
        end
    end
  end

  @spec delete_user_authorized_scopes_by_id(scope_id :: String.t()) :: {deleted :: integer(), nil}
  def delete_user_authorized_scopes_by_id(scope_id) do
    Repo.delete_all(from(s in UserAuthorizedScope, where: s.scope_id == ^scope_id))
  end

  defp user_preloads(users) when is_list(users) do
    Repo.preload(users, [:backend, :authorized_scopes, :roles, :organizations])
  end

  defp user_preloads(%User{} = user) do
    Repo.preload(user, [:backend, :authorized_scopes, :roles, :organizations])
  end

  defp user_preloads(queryable) do
    preload(queryable, [:backend, :authorized_scopes, :roles, :organizations])
  end

  defdelegate list_organizations, to: BorutaIdentity.Organizations
  defdelegate list_organizations(params), to: BorutaIdentity.Organizations
  # defdelegate search_organizations(query), to: BorutaIdentity.Organizations
  # defdelegate search_organizations(query, params), to: BorutaIdentity.Organizations
  defdelegate get_organization(organization_id), to: BorutaIdentity.Organizations
  defdelegate create_organization(organization_params), to: BorutaIdentity.Organizations

  defdelegate update_organization(organization, organization_params),
    to: BorutaIdentity.Organizations

  defdelegate delete_organization(organization_id), to: BorutaIdentity.Organizations

  # --------- TODO refactor below functions
  alias BorutaIdentity.Accounts.Role

  def list_roles do
    Repo.all(
      from r in Role,
        left_join: rs in assoc(r, :role_scopes),
        preload: [role_scopes: rs]
    )
    |> Enum.map(fn %Role{role_scopes: role_scopes} = role ->
      scopes =
        role_scopes
        |> Enum.map(fn role_scope -> role_scope.scope_id end)
        |> Admin.get_scopes_by_ids()

      %{role | scopes: scopes}
    end)
  end

  @doc """
  Gets a single role.

  Raises `Ecto.NoResultsError` if the Role does not exist.

  ## Examples

      iex> get_role!(123)
      %Role{}

      iex> get_role!(456)
      ** (Ecto.NoResultsError)

  """
  def get_role!(id) do
    %Role{role_scopes: role_scopes} =
      role =
      Repo.one!(
        from r in Role,
          left_join: rs in assoc(r, :role_scopes),
          where: r.id == ^id,
          preload: [role_scopes: rs]
      )

    scopes =
      role_scopes
      |> Enum.map(fn role_scope -> role_scope.scope_id end)
      |> Admin.get_scopes_by_ids()

    %{role | scopes: scopes}
  end

  def create_role(attrs \\ %{}) do
    with {:ok, role} <-
           %Role{}
           |> Role.changeset(attrs)
           |> Repo.insert() do
      {:ok, get_role!(role.id)}
    end
  end

  def update_role(%Role{} = role, attrs) do
    with {:ok, role} <-
           role
           |> Role.changeset(attrs)
           |> Repo.update() do
      {:ok, get_role!(role.id)}
    end
  end

  def delete_role(%Role{} = role) do
    Repo.delete(role)
  end

  def change_role(%Role{} = role, attrs \\ %{}) do
    Role.changeset(role, attrs)
  end
end
