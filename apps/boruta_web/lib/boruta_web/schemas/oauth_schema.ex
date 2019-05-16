defmodule BorutaWeb.OauthSchema do
  alias ExJsonSchema.Schema

  def authorize(:query_params) do
    %{
      "type" => "object",
      "properties" => %{
        "response_type" => %{"type" => "string", "pattern" => "token"},
        "client_id" => %{
          "type" => "string",
          "pattern" => "[0-9a-fA-F]{8}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{12}"
        },
        "redirect_uri" => %{"type" => "string"},
        "scope" => %{"type" => "string"},
        "state" => %{"type" => "string"}
      },
      "required" => ["response_type", "client_id", "redirect_uri"]
    } |> Schema.resolve
  end
  def authorize(:body_params) do
    %{} |> Schema.resolve
  end

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
