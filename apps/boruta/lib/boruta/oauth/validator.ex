defmodule Boruta.Oauth.Validator do
  alias ExJsonSchema.Validator.Error.BorutaFormatter

  def validate(params, {:query_params, schema}) do
    case ExJsonSchema.Validator.validate(schema, params, error_formatter: BorutaFormatter) do
      :ok ->
        params
      {:error, errors} ->
        {:error, "Query params validation failed. " <> Enum.join(errors, " ")}
    end
  end
  def validate(params, {:body_params, schema}) do
    case ExJsonSchema.Validator.validate(schema, params, error_formatter: BorutaFormatter) do
      :ok ->
        params
      {:error, errors} ->
        {:error, "Body params validation failed. " <> Enum.join(errors, " ")}
    end
  end
end
