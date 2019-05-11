defmodule BorutaWeb.JsonSchemaView do
  use BorutaWeb, :view

  def render("error.json", %{validation_errors: errors}) do
    Enum.reduce(errors, [], &serialize/2)
  end

  defp serialize({:query_params, errors}, acc) do
    Enum.reduce(errors, acc, fn (error, acc) ->
      [%{
        error: "Query params validation failed",
        message: elem(error, 0)} | acc]
    end)
  end
  defp serialize({:body_params, errors}, acc) do
    Enum.reduce(errors, acc, fn (error, acc) ->
      [%{
        error: "Body params validation failed",
        message: elem(error, 0),
        path: elem(error, 1)} | acc]
    end)
  end
end
