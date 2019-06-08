defmodule Boruta.Oauth.Validator do
  @moduledoc """
  Utility to validate the request according to the given parameters.
  """

  # TODO fid a way to difference query from body params
  # TODO unit test
  alias Boruta.Oauth.Json.Schema
  alias ExJsonSchema.Validator.Error.BorutaFormatter

  @doc """
  Validates given OAuth parameters.
  ## Examples
      iex> validate(%{
        "grant_type" => "client_credentials",
        "client_id" => "client_id",
        "client_secret" => "client_secret"
      })
      {:ok, %{
        "grant_type" => "client_credentials",
        "client_id" => "client_id",
        "client_secret" => "client_secret"
      }}

      iex> validate(%{})
      {:error, "Request is not a valid OAuth request. Need a grant_type or a response_type param."}
  """
  @spec validate(params :: Map.t()) :: {:ok, params :: Map.t()} | {:error, message :: String.t()}
  def validate(%{"grant_type" => "password"} = params) do
    case ExJsonSchema.Validator.validate(
      Schema.resource_owner_password_credentials,
      params,
      error_formatter: BorutaFormatter
    ) do
      :ok -> {:ok, params}
      {:error, errors} ->
        {:error, "Request body validation failed. " <> Enum.join(errors, " ")}
    end
  end
  def validate(%{"grant_type" => "client_credentials"} = params) do
    case ExJsonSchema.Validator.validate(
      Schema.client_credentials,
      params,
      error_formatter: BorutaFormatter
    ) do
      :ok -> {:ok, params}
      {:error, errors} ->
        {:error, "Request body validation failed. " <> Enum.join(errors, " ")}
    end
  end
  def validate(%{"grant_type" => "authorization_code"} = params) do
    case ExJsonSchema.Validator.validate(
      Schema.authorization_code,
      params,
      error_formatter: BorutaFormatter
    ) do
      :ok -> {:ok, params}
      {:error, errors} ->
        {:error, "Request body validation failed. " <> Enum.join(errors, " ")}
    end
  end
  def validate(%{"grant_type" => _} = params) do
    case ExJsonSchema.Validator.validate(
      Schema.grant_type,
      params,
      error_formatter: BorutaFormatter
    ) do
      :ok -> {:ok, params}
      {:error, errors} ->
        {:error, "Request body validation failed. " <> Enum.join(errors, " ")}
    end
  end

  def validate(%{"response_type" => "token"} = params) do
    case ExJsonSchema.Validator.validate(Schema.token, params, error_formatter: BorutaFormatter) do
      :ok -> {:ok, params}
      {:error, errors} ->
        {:error, "Query params validation failed. " <> Enum.join(errors, " ")}
    end
  end
  def validate(%{"response_type" => "code"} = params) do
    case ExJsonSchema.Validator.validate(Schema.code, params, error_formatter: BorutaFormatter) do
      :ok -> {:ok, params}
      {:error, errors} ->
        {:error, "Query params validation failed. " <> Enum.join(errors, " ")}
    end
  end
  def validate(%{"response_type" => "introspect"} = params) do
    case ExJsonSchema.Validator.validate(Schema.introspect, params, error_formatter: BorutaFormatter) do
      :ok -> {:ok, params}
      {:error, errors} ->
        {:error, "Request validation failed. " <> Enum.join(errors, " ")}
    end
  end
  def validate(%{"response_type" => _} = params) do
    case ExJsonSchema.Validator.validate(Schema.response_type, params, error_formatter: BorutaFormatter) do
      :ok -> {:ok, params}
      {:error, errors} ->
        {:error, "Query params validation failed. " <> Enum.join(errors, " ")}
    end
  end

  def validate(_params) do
    {:error, "Request is not a valid OAuth request. Need a grant_type or a response_type param."}
  end
end
