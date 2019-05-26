defmodule Boruta.Oauth.Json.Schema do
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

  def client_credentials() do
    %{
      "type" => "object",
      "properties" => %{
        "grant_type" => %{"type" => "string", "pattern" => "client_credentials"},
        "client_id" => %{
          "type" => "string",
          "pattern" => "[0-9a-fA-F]{8}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{12}"
        },
        "client_secret" => %{"type" => "string"},
        "scope" => %{"type" => "string"},
      },
      "required" => ["grant_type", "client_id", "client_secret"]
    } |> Schema.resolve
  end

  def resource_owner_password_credentials() do
    %{
      "type" => "object",
      "properties" => %{
        "grant_type" => %{"type" => "string", "pattern" => "password"},
        "client_id" => %{
          "type" => "string",
          "pattern" => "[0-9a-fA-F]{8}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{12}"
        },
        "client_secret" => %{"type" => "string"},
        "username" => %{"type" => "string"},
        "password" => %{"type" => "string"},
        "scope" => %{"type" => "string"},
      },
      "required" => ["grant_type", "client_id", "client_secret", "username", "password"]
    } |> Schema.resolve
  end

  def token() do
    %{
      "type" => "object",
      "properties" => %{
        "response_type" => %{"type" => "string", "pattern" => "token"},
        "client_id" => %{
          "type" => "string",
          "pattern" => "[0-9a-fA-F]{8}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{12}"
        },
        "redirect_uri" => %{"type" => "string"}
      },
      "required" => ["response_type", "client_id", "redirect_uri"]
    } |> Schema.resolve
  end

  def grant_type() do
    %{
      "type" => "object",
      "properties" => %{
        "grant_type" => %{"type" => "string", "pattern" => "client_credentials|password"},
      },
      "required" => ["grant_type"]
    } |> Schema.resolve
  end

  def response_type() do
    %{
      "type" => "object",
      "properties" => %{
        "response_type" => %{"type" => "string", "pattern" => "token"},
      },
      "required" => ["response_type"]
    } |> Schema.resolve
  end
end
