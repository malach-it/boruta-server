defmodule BorutaAdmin.Tokens do
  @moduledoc """
  Token administration helpers.
  """

  import Ecto.Query
  import Boruta.Ecto.OauthMapper, only: [to_oauth_schema: 1]

  alias Boruta.Ecto.Token
  alias Boruta.AccessTokensAdapter
  alias Boruta.AgentTokensAdapter
  alias Boruta.CodesAdapter
  alias Boruta.Oauth
  alias BorutaAuth.Repo
  alias BorutaIdentity.Accounts.User

  @default_page_size 12

  def list_tokens(params \\ %{}) do
    from(t in Token,
      left_join: c in assoc(t, :client),
      preload: [client: c]
    )
    |> filter_by_client(params)
    |> filter_by_type(params)
    |> filter_by_scope(params)
    |> search(params)
    |> order(params)
    |> Scrivener.paginate(%Scrivener.Config{
      caller: self(),
      module: Repo,
      page_number: page_number(params),
      page_size: page_size(params),
      options: []
    })
  end

  def list_scopes(params \\ %{}) do
    scopes =
      Token
      |> filter_by_client(params)
      |> filter_by_type(params)
      |> select([t], t.scope)
      |> Repo.all()

    requested_scopes =
      Token
      |> filter_by_client(params)
      |> filter_by_type(params)
      |> select([t], t.requested_scope)
      |> Repo.all()

    (scopes ++ requested_scopes)
    |> Enum.flat_map(&Oauth.Scope.split/1)
    |> Enum.uniq()
    |> Enum.sort()
  end

  def list_requested_scopes(params \\ %{}) do
    Token
    |> filter_by_client(params)
    |> filter_by_type(params)
    |> select([t], t.requested_scope)
    |> Repo.all()
    |> Enum.flat_map(&Oauth.Scope.split/1)
    |> Enum.uniq()
    |> Enum.sort()
  end

  def type_counts(params \\ %{}) do
    from(t in Token,
      select: {t.type, count(t.id)},
      group_by: t.type
    )
    |> filter_by_client(params)
    |> filter_by_type(params)
    |> filter_by_scope(params)
    |> search(params)
    |> Repo.all()
    |> Enum.into(%{})
  end

  def list_types(params \\ %{}) do
    Token
    |> filter_by_client(params)
    |> filter_by_scope(params)
    |> select([t], t.type)
    |> distinct(true)
    |> Repo.all()
    |> Enum.reject(&is_nil/1)
    |> Enum.sort()
  end

  def previous_codes(tokens) when is_list(tokens) do
    tokens
    |> Enum.map(fn %Token{id: id} = token -> {id, previous_codes_for_token(token)} end)
    |> Enum.into(%{})
  end

  def revoke_access_token(id) do
    with %Token{} = token <- Repo.get(Token, id),
         :ok <- ensure_revocable_token(token),
         {:ok, _token} <- revoke_token(token),
         %Token{} = token <- Repo.get(Token, id) do
      {:ok, token}
    else
      nil -> {:error, :not_found}
      error -> error
    end
  end

  defp filter_by_client(queryable, %{"client_id" => client_id})
       when is_binary(client_id) and client_id != "" do
    from(t in queryable, where: t.client_id == ^client_id)
  end

  defp filter_by_client(queryable, %{client_id: client_id})
       when is_binary(client_id) and client_id != "" do
    filter_by_client(queryable, %{"client_id" => client_id})
  end

  defp filter_by_client(queryable, _params), do: queryable

  defp filter_by_type(queryable, %{"type" => type}) when is_binary(type) and type != "" do
    from(t in queryable, where: t.type == ^type)
  end

  defp filter_by_type(queryable, %{type: type}) when is_binary(type) and type != "" do
    filter_by_type(queryable, %{"type" => type})
  end

  defp filter_by_type(queryable, _params), do: queryable

  defp filter_by_scope(queryable, %{"scope" => scope}) when is_binary(scope) and scope != "" do
    from(t in queryable,
      where:
        fragment("? = ANY(string_to_array(coalesce(?, ''), ' '))", ^scope, t.scope) or
          fragment("? = ANY(string_to_array(coalesce(?, ''), ' '))", ^scope, t.requested_scope)
    )
  end

  defp filter_by_scope(queryable, %{scope: scope}) when is_binary(scope) and scope != "" do
    filter_by_scope(queryable, %{"scope" => scope})
  end

  defp filter_by_scope(queryable, _params), do: queryable

  defp search(queryable, %{"q" => query}) when is_binary(query) and query != "" do
    from(t in queryable,
      left_join: u in User,
      as: :user,
      on: fragment("?::text = ?", u.id, t.sub),
      where:
        fragment("coalesce(?, '') % ?", t.sub, ^query) or
          fragment("coalesce(?, '') % ?", t.refresh_token, ^query) or
          fragment("coalesce(?, '') % ?", t.value, ^query) or
          fragment("coalesce(?, '') % ?", u.username, ^query)
    )
  end

  defp search(queryable, %{q: query}) when is_binary(query) and query != "" do
    search(queryable, %{"q" => query})
  end

  defp search(queryable, _params), do: queryable

  defp order(queryable, %{"q" => query}) when is_binary(query) and query != "" do
    from([t, user: u] in queryable,
      order_by: [
        desc:
          fragment(
            "greatest(word_similarity(coalesce(?, ''), ?), word_similarity(coalesce(?, ''), ?), word_similarity(coalesce(?, ''), ?), word_similarity(coalesce(?, ''), ?))",
            t.sub,
            ^query,
            t.refresh_token,
            ^query,
            t.value,
            ^query,
            u.username,
            ^query
          ),
        desc: t.inserted_at
      ]
    )
  end

  defp order(queryable, %{q: query}) when is_binary(query) and query != "" do
    order(queryable, %{"q" => query})
  end

  defp order(queryable, _params) do
    from(t in queryable, order_by: [desc: t.inserted_at])
  end

  defp previous_codes_for_token(%Token{} = token) do
    token
    |> do_previous_codes([])
    |> Enum.reverse()
  end

  defp do_previous_codes(%Token{previous_code: previous_code}, acc)
       when is_binary(previous_code) and previous_code != "" do
    case Repo.get_by(Token, value: previous_code) do
      %Token{} = previous_token -> do_previous_codes(previous_token, acc ++ [previous_token])
      _ -> acc
    end
  end

  defp do_previous_codes(_token, acc), do: acc

  defp ensure_revocable_token(%Token{
         type: "access_token",
         client_id: client_id,
         revoked_at: nil,
         expires_at: expires_at
       })
       when is_binary(client_id) and is_integer(expires_at) do
    if expires_at > :os.system_time(:second), do: :ok, else: {:error, :bad_request}
  end

  defp ensure_revocable_token(%Token{
         type: "agent_token",
         client_id: client_id,
         revoked_at: nil,
         expires_at: expires_at
       })
       when is_binary(client_id) and is_integer(expires_at) do
    if expires_at > :os.system_time(:second), do: :ok, else: {:error, :bad_request}
  end

  defp ensure_revocable_token(%Token{type: "code", revoked_at: nil, expires_at: expires_at})
       when is_integer(expires_at) do
    if expires_at > :os.system_time(:second), do: :ok, else: {:error, :bad_request}
  end

  defp ensure_revocable_token(_token), do: {:error, :bad_request}

  defp revoke_token(%Token{type: "access_token"} = token) do
    token
    |> to_oauth_schema()
    |> AccessTokensAdapter.revoke()
  end

  defp revoke_token(%Token{type: "agent_token"} = token) do
    token
    |> to_oauth_schema()
    |> AgentTokensAdapter.revoke()
  end

  defp revoke_token(%Token{type: "code"} = token) do
    token
    |> to_oauth_schema()
    |> CodesAdapter.revoke()
  end

  defp page_number(%{"page" => page}), do: positive_integer(page, 1)
  defp page_number(%{page: page}), do: positive_integer(page, 1)
  defp page_number(_params), do: 1

  defp page_size(%{"page_size" => page_size}), do: positive_integer(page_size, @default_page_size)
  defp page_size(%{page_size: page_size}), do: positive_integer(page_size, @default_page_size)
  defp page_size(_params), do: @default_page_size

  defp positive_integer(value, _default) when is_integer(value) and value > 0, do: value

  defp positive_integer(value, default) when is_binary(value) do
    case Integer.parse(value) do
      {integer, _rest} when integer > 0 -> integer
      _ -> default
    end
  end

  defp positive_integer(_value, default), do: default
end
