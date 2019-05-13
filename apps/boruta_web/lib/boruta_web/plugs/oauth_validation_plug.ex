defmodule BorutaWeb.OauthValidationPlug do
  alias ExJsonSchema.Validator
  alias ExJsonSchema.Validator.Error.BorutaFormatter

  use BorutaWeb, :controller

  def init(schema), do: schema

  def call(%Plug.Conn{
    :private => %{phoenix_action: action},
    :query_params => query_params,
    :body_params => body_params} = conn, schema) do
    conn = conn
    |> validate(schema, action, :query_params, query_params)
    |> validate(schema, action, :body_params, body_params)

    case conn.assigns[:validation_errors] do
      nil ->
        conn
      errors ->
        conn
        |> render_error(errors)
    end
  end

  defp validate(conn, schema, action, type, params) do
    case Validator.validate(
      apply(schema, action, [:"#{type}"]),
      params,
      error_formatter: BorutaFormatter
    ) do
      :ok ->
        conn
      {:error, errors} ->
        validation_errors = conn.assigns[:validation_errors] || []

        conn
        |> assign(
          :validation_errors,
          validation_errors ++
            Enum.map(errors, fn (error) -> format(error, type) end)
        )
    end
  end

  defp render_error(conn, errors) do
    error_description = List.first(errors)

    conn
    |> put_status(:unprocessable_entity)
    |> put_view(BorutaWeb.OauthView)
    |> render("error.json", error: "invalid_request", error_description: error_description)
    |> halt
  end

  defp format(error, :query_params) do
    "Query params validation failed. #{error}"
  end
  defp format(error, :body_params) do
    "Request body validation failed. #{error}"
  end
end
