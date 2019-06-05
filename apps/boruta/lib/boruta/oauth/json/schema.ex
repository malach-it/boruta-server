defmodule Boruta.Oauth.Json.Schema do
  @moduledoc """
  TODO OAuth json schemas
  """
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

  def client_credentials do
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

  def resource_owner_password_credentials do
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

  def authorization_code do
    %{
      "type" => "object",
      "properties" => %{
        "grant_type" => %{"type" => "string", "pattern" => "authorization_code"},
        "client_id" => %{
          "type" => "string",
          "pattern" => "[0-9a-fA-F]{8}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{12}"
        },
        "code" => %{"type" => "string"},
        "redirect_uri" => %{"type" => "string"}
      },
      "required" => ["grant_type", "code", "redirect_uri"]
    } |> Schema.resolve
  end

  def token do
    %{
      "type" => "object",
      "properties" => %{
        "response_type" => %{"type" => "string", "pattern" => "token"},
        "client_id" => %{
          "type" => "string",
          "pattern" => "[0-9a-fA-F]{8}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{12}"
        },
        "state" => %{"type" => "string"},
        "redirect_uri" => %{"type" => "string"}
      },
      "required" => ["response_type", "client_id", "redirect_uri"]
    } |> Schema.resolve
  end

  def code do
    %{
      "type" => "object",
      "properties" => %{
        "response_type" => %{"type" => "string", "pattern" => "code"},
        "client_id" => %{
          "type" => "string",
          "pattern" => "[0-9a-fA-F]{8}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{12}"
        },
        "state" => %{"type" => "string"},
        "redirect_uri" => %{"type" => "string"}
      },
      "required" => ["response_type", "client_id", "redirect_uri"]
    } |> Schema.resolve
  end

  def introspect do
    %{
      "type" => "object",
      "properties" => %{
        "client_id" => %{
          "type" => "string",
          "pattern" => "[0-9a-fA-F]{8}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{12}"
        },
        "client_secret" => %{"type" => "string"},
        "token" => %{"type" => "string"},
      },
      "required" => ["client_id", "client_secret", "token"]
    } |> Schema.resolve
  end

  def grant_type do
    %{
      "type" => "object",
      "properties" => %{
        "grant_type" => %{"type" => "string", "pattern" => "client_credentials|password|authorization_code"},
      },
      "required" => ["grant_type"]
    } |> Schema.resolve
  end

  def response_type do
    %{
      "type" => "object",
      "properties" => %{
        "response_type" => %{"type" => "string", "pattern" => "token|code"},
      },
      "required" => ["response_type"]
    } |> Schema.resolve
  end
end
