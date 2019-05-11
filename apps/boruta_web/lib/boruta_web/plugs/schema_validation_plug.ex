defmodule SchemaValidationPlug do
  alias ExJsonSchema.Validator

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
      validation_errors ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(BorutaWeb.JsonSchemaView)
        |> render("error.json", errors: %{validation_errors: validation_errors})
        |> halt
    end
  end

  defp validate(conn, schema, action, type, params) do
    case Validator.validate(apply(schema, action, [:"#{type}"]), params) do
      :ok ->
        conn
      {:error, errors} ->
        validation_errors = conn.assigns[:validation_errors] || %{}

        conn
        |> assign(:validation_errors, Enum.into(validation_errors, %{:"#{type}" => errors}))
    end
  end
end
