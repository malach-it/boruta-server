defmodule BorutaWeb.OpenidView do
  use BorutaWeb, :view

  def render("show.json", %{client: client}) do
    %{data: render_one(client, __MODULE__, "client.json")}
  end

  def render("client.json", %{client: client}) do
    %{
      client_id: client.id,
      client_secret: client.secret,
      client_secret_expires_at: 0
    }
  end

  def render("registration_error.json", %{changeset: changeset}) do
    %{
      error: "invalid_client_metadata",
      error_description: errors_full_message(changeset)
    }
  end

  defp errors_full_message(changeset) do
    Ecto.Changeset.traverse_errors(changeset, &translate_error/1)
    |> Enum.map_join(", ", fn {attribute, messages} ->
      "#{attribute} : #{Enum.join(messages, ", ")}"
    end)
  end
end
