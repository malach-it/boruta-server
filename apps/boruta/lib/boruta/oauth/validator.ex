defmodule Boruta.Oauth.Validator do
  # TODO fid a way to difference query from body params
  # TODO return {:ok, params} on successful response
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
  def validate(%{"grant_type" => "authorization_code"} = params) do
    case ExJsonSchema.Validator.validate(Schema.authorization_code, params, error_formatter: BorutaFormatter) do
      :ok ->
        params
      {:error, errors} ->
        {:error, "Request body validation failed. " <> Enum.join(errors, " ")}
    end
  end
  def validate(%{"grant_type" => _} = params) do
    case ExJsonSchema.Validator.validate(Schema.grant_type, params, error_formatter: BorutaFormatter) do
      :ok ->
        params
      {:error, errors} ->
        {:error, "Request body validation failed. " <> Enum.join(errors, " ")}
    end
  end

  def validate(%{"response_type" => "token"} = params) do
    case ExJsonSchema.Validator.validate(Schema.token, params, error_formatter: BorutaFormatter) do
      :ok ->
        params
      {:error, errors} ->
        {:error, "Query params validation failed. " <> Enum.join(errors, " ")}
    end
  end
  def validate(%{"response_type" => "code"} = params) do
    case ExJsonSchema.Validator.validate(Schema.code, params, error_formatter: BorutaFormatter) do
      :ok ->
        params
      {:error, errors} ->
        {:error, "Query params validation failed. " <> Enum.join(errors, " ")}
    end
  end
  def validate(%{"response_type" => _} = params) do
    case ExJsonSchema.Validator.validate(Schema.response_type, params, error_formatter: BorutaFormatter) do
      :ok ->
        params
      {:error, errors} ->
        {:error, "Query params validation failed. " <> Enum.join(errors, " ")}
    end
  end

  def validate(_params) do
    {:error, "Request is not a valid OAuth request. Need a grant_type or a response_type param."}
  end
end
