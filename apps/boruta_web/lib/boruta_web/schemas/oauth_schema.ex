defmodule BorutaWeb.OauthSchema do
  alias ExJsonSchema.Schema

  def token(:query_params) do
    %{
      "type" => "object",
      "properties" => %{
        "grant_type" => %{"type" => "string", "pattern" => "client_credentials"},
        "scope" => %{"type" => "string"}
      },
      "required" => ["grant_type"]
    } |> Schema.resolve
  end
  def token(:body_params) do
    %{
      "type" => "object",
      "properties" => %{
        "client_id" => %{
          "type" => "string",
          "pattern" => "[0-9a-fA-F]{8}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{12}"
        },
        "client_secret" => %{"type" => "string"}
      },
      "required" => ["client_secret", "client_id"]
    } |> Schema.resolve
  end
end
