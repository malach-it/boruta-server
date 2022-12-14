defmodule BorutaIdentity.Admin do
  @moduledoc """
  TODO Admin documentation
  """

  import Ecto.Query

  alias BorutaIdentity.Accounts.User
  alias BorutaIdentity.Accounts.UserAuthorizedScope
  alias BorutaIdentity.IdentityProviders.Backend
  alias BorutaIdentity.Repo
  alias NimbleCSV.RFC4180, as: CSV

  @type user_params ::
          %{
            :username => String.t(),
            :password => String.t(),
            optional(:metadata) => map()
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
    |> preload([:authorized_scopes, :backend])
    |> Repo.paginate(params)
  end

  @spec search_users(query :: String.t(), params :: map()) :: Scrivener.Page.t()
  @spec search_users(query :: String.t()) :: Scrivener.Page.t()
  def search_users(query, params \\ %{}) do
    from(u in User,
      where: fragment("username % ?", ^query),
      order_by: fragment("word_similarity(username, ?) DESC", ^query)
    )
    |> preload([:authorized_scopes, :backend])
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
        join: b in assoc(u, :backend),
        preload: [authorized_scopes: as, backend: b],
        where: u.id == ^id
      )
    )
  end

  @spec create_user(backend :: Backend.t(), params :: user_params()) ::
          {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def create_user(backend, params) do
    # TODO give the ability to provide authorized scopes at user creation
    apply(
      Backend.implementation(backend),
      :create_user,
      [backend, params]
    )
  end

  @spec create_raw_user(backend :: Backend.t(), params :: raw_user_params()) ::
          {:ok, User.t()} | {:error, Ecto.Changeset.t()}
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
                 "scope_id" => attrs["id"],
                 "user_id" => user.id
               }
             )

           Ecto.Multi.insert(multi, "scope_-#{SecureRandom.uuid()}", changeset)
         end)
         |> Repo.transaction() do
      {:ok, _result} ->
        {:ok, user |> Repo.reload() |> Repo.preload([:backend, :authorized_scopes])}

      {:error, _multi_name, %Ecto.Changeset{} = changeset, _changes} ->
        {:error, changeset}
    end
  end

  @type user_update_params :: %{
    optional(:metadata) => map()
  }

  @spec update_user(user :: User.t(), user_params :: user_update_params()) ::
          {:ok, user :: User.t()} | {:error, Ecto.Changeset.t()}
  def update_user(user, user_params) do
    user
    |> User.changeset(user_params)
    |> Repo.update()
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
        with :ok <- apply(Backend.implementation(user.backend), :delete_user, [user.uid]) do
          Repo.delete(user)
        end
    end
  end

  @spec delete_user_authorized_scopes_by_id(scope_id :: String.t()) :: {deleted :: integer(), nil}
  def delete_user_authorized_scopes_by_id(scope_id) do
    Repo.delete_all(from(s in UserAuthorizedScope, where: s.scope_id == ^scope_id))
  end
end
