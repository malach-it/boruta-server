defmodule BorutaAuth.Repo.Migrations.AddOauthTokensFullTextIndex do
  use Ecto.Migration

  def change do
    execute("CREATE EXTENSION IF NOT EXISTS pg_trgm", "")
    execute("DROP INDEX IF EXISTS oauth_tokens_full_text_search_index", "")

    execute(
      """
      CREATE INDEX IF NOT EXISTS oauth_tokens_sub_trgm_index
      ON oauth_tokens
      USING gin (coalesce(sub, '') gin_trgm_ops)
      """,
      "DROP INDEX IF EXISTS oauth_tokens_sub_trgm_index"
    )

    execute(
      """
      CREATE INDEX IF NOT EXISTS oauth_tokens_refresh_token_trgm_index
      ON oauth_tokens
      USING gin (coalesce(refresh_token, '') gin_trgm_ops)
      """,
      "DROP INDEX IF EXISTS oauth_tokens_refresh_token_trgm_index"
    )

    execute(
      """
      CREATE INDEX IF NOT EXISTS oauth_tokens_value_trgm_index
      ON oauth_tokens
      USING gin (coalesce(value, '') gin_trgm_ops)
      """,
      "DROP INDEX IF EXISTS oauth_tokens_value_trgm_index"
    )

    execute(
      """
      CREATE INDEX IF NOT EXISTS username_trgm_idx
      ON users
      USING gin (username gin_trgm_ops);
      """,
      "DROP INDEX IF EXISTS username_trgm_idx"
    )
  end
end
