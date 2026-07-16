defmodule BorutaAdminWeb.TokenController do
  use BorutaAdminWeb, :controller

  import BorutaAdminWeb.Authorization,
    only: [
      authorize: 2
    ]

  alias BorutaAdmin.Tokens

  plug(:authorize, ["tokens:read:all"])

  action_fallback(BorutaAdminWeb.FallbackController)

  def index(conn, params) do
    tokens = Tokens.list_tokens(params)
    scopes = Tokens.list_scopes(params)
    types = Tokens.list_types(params)
    type_counts = Tokens.type_counts(params)
    token_counts = Tokens.issued_token_counts(params)
    token_counts_time_scale_unit = Tokens.issued_token_count_time_scale_unit(params)
    previous_codes = Tokens.previous_codes(tokens.entries)

    render(conn, "index.json",
      conn: conn,
      tokens: tokens.entries,
      scopes: scopes,
      types: types,
      type_counts: type_counts,
      token_counts: token_counts,
      token_counts_time_scale_unit: token_counts_time_scale_unit,
      previous_codes: previous_codes,
      page_number: tokens.page_number,
      page_size: tokens.page_size,
      total_pages: tokens.total_pages,
      total_entries: tokens.total_entries
    )
  end

  def show(conn, %{"id" => id}) do
    with {:ok, token} <- Tokens.get_token(id) do
      previous_codes = Tokens.previous_codes([token])

      render(conn, "show.json", conn: conn, token: token, previous_codes: previous_codes)
    end
  end

  def revoke(conn, %{"id" => id}) do
    with {:ok, token} <- Tokens.revoke_access_token(id) do
      previous_codes = Tokens.previous_codes([token])

      render(conn, "show.json", conn: conn, token: token, previous_codes: previous_codes)
    end
  end
end
