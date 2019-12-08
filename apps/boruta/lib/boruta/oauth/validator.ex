defmodule Boruta.Oauth.Validator do
  @moduledoc """
  Utility to validate the request according to the given parameters.
  """

  # TODO find a way to difference query from body params
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
  @spec validate(action :: atom(), params :: map()) :: {:ok, params :: map()} | {:error, message :: String.t()}
  def validate(:token, %{"grant_type" => grant_type} = params)
  when grant_type in ["password", "client_credentials", "authorization_code", "refresh_token"] do
    case ExJsonSchema.Validator.validate(
      apply(Schema, String.to_atom(grant_type), []),
      params,
      error_formatter: BorutaFormatter
    ) do
      :ok -> {:ok, params}
      {:error, errors} ->
        {:error, "Request body validation failed. " <> Enum.join(errors, " ")}
    end
  end
  def validate(:token, %{"grant_type" => _} = params) do
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

  def validate(:authorize, %{"response_type" => response_type} = params)
  when response_type in ["token", "code"] do
    case ExJsonSchema.Validator.validate(
      apply(Schema, String.to_atom(response_type), []),
      params,
      error_formatter: BorutaFormatter
    ) do
      :ok -> {:ok, params}
      {:error, errors} ->
        {:error, "Query params validation failed. " <> Enum.join(errors, " ")}
    end
  end
  def validate(:authorize, %{"response_type" => _} = params) do
    case ExJsonSchema.Validator.validate(Schema.response_type, params, error_formatter: BorutaFormatter) do
      :ok -> {:ok, params}
      {:error, errors} ->
        {:error, "Query params validation failed. " <> Enum.join(errors, " ")}
    end
  end

  def validate(:introspect, params) do
    case ExJsonSchema.Validator.validate(Schema.introspect, params, error_formatter: BorutaFormatter) do
      :ok -> {:ok, params}
      {:error, errors} ->
        {:error, "Request validation failed. " <> Enum.join(errors, " ")}
    end
  end

  def validate(:revoke, params) do
    case ExJsonSchema.Validator.validate(Schema.revoke, params, error_formatter: BorutaFormatter) do
      :ok -> {:ok, params}
      {:error, errors} ->
        {:error, "Request validation failed. " <> Enum.join(errors, " ")}
    end
  end

  def validate(:token, _params) do
    {:error, "Request is not a valid OAuth request. Need a grant_type param."}
  end
  def validate(:authorize, _params) do
    {:error, "Request is not a valid OAuth request. Need a response_type param."}
  end
end
