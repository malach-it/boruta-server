defmodule BorutaAdminWeb.ChangesetView do
  use BorutaWeb, :view

  @doc """
  Traverses and translates changeset errors.

  See `Ecto.Changeset.traverse_errors/2` and
  `BorutaWeb.ErrorHelpers.translate_error/1` for more details.
  """
  def translate_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      case opts[:count] do
        nil ->
          msg
        count ->
          String.replace(msg, "%{count}", to_string(count))
      end
    end)
  end

  def render("error.json", %{changeset: changeset}) do
    %{
      code: "UNPROCESSABLE_ENTITY",
      message: "Your request could not be processed.",
      errors: translate_errors(changeset)
    }
  end
end
