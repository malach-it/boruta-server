defmodule Boruta.Oauth.Validator do
  alias ExJsonSchema.Validator.Error.BorutaFormatter
  alias Boruta.Oauth.Json.Schema

  def validate(%{"grant_type" => "password"} = params) do
    case ExJsonSchema.Validator.validate(Schema.resource_owner_password_credentials, params, error_formatter: BorutaFormatter) do
      :ok ->
        params
      {:error, errors} ->
        {:error, "Request body validation failed. " <> Enum.join(errors, " ")}
    end
  end
  def validate(%{"grant_type" => "client_credentials"} = params) do
    case ExJsonSchema.Validator.validate(Schema.client_credentials, params, error_formatter: BorutaFormatter) do
      :ok ->
        params
      {:error, errors} ->
        {:error, "Request body validation failed. " <> Enum.join(errors, " ")}
    end
  end
  def validate(params) do
    case ExJsonSchema.Validator.validate(Schema.grant_type, params, error_formatter: BorutaFormatter) do
      :ok ->
        params
      {:error, errors} ->
        {:error, "Request body validation failed. " <> Enum.join(errors, " ")}
    end
  end
end
