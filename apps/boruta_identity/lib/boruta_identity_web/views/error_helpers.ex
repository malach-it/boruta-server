defmodule BorutaIdentityWeb.ErrorHelpers do
  @moduledoc """
  Conveniences for translating and building error messages.
  """

  use Phoenix.HTML

  def error_messages(nil), do: []

  def error_messages(%Ecto.Changeset{} = changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
    |> Enum.map(&error_message/1)
  end

  def error_message({field, messages}) do
    message = Enum.flat_map(messages, fn
      errors when is_map(errors) ->
        Enum.map(errors, &error_message/1)
      message ->
        [message]
    end)
    |> Enum.join(", ")

    Phoenix.Naming.humanize(field) <> ": " <> message
  end

  def errors_tag(errors) do
    content_tag(
      :ul,
      Enum.map(errors, &error_tag/1)
    )
  end

  def error_tag({field, {_msg, _opts} = error}) do
    content_tag(
      :li,
      [
        content_tag(
          :strong,
          Phoenix.Naming.humanize(field) <> ":"
        ),
        content_tag(:span, " "),
        content_tag(:span, translate_error(error))
      ]
    )
  end

  def error_tag({field, ["" <> _first | _rest] = messages}) do
    content_tag(
      :li,
      [
        content_tag(
          :strong,
          Atom.to_string(field)
        ),
        content_tag(:span, " "),
        content_tag(:span, Enum.join(messages, ", "))
      ]
    )
  end

  def error_tag({field, errors}) when is_list(errors) do
    Enum.map(errors, fn
      %{} = errors ->
        [
          content_tag(
            :strong,
            Atom.to_string(field)
          ),
          content_tag(:span, " "),
          Enum.map(errors, fn error -> error_tag(error) end)
        ]
    end)
  end

  @doc """
  Generates tag for inlined form input errors.
  """
  def error_tag(form, field) do
    Enum.map(Keyword.get_values(form.errors, field), fn error ->
      content_tag(:span, translate_error(error))
    end)
  end

  @doc """
  Translates an error message using gettext.
  """
  def translate_error({msg, _opts}) do
    # When using gettext, we typically pass the strings we want
    # to translate as a static argument:
    #
    #     # Translate "is invalid" in the "errors" domain
    #     dgettext("errors", "is invalid")
    #
    #     # Translate the number of files with plural rules
    #     dngettext("errors", "1 file", "%{count} files", count)
    #
    # Because the error messages we show in our forms and APIs
    # are defined inside Ecto, we need to translate them dynamically.
    # This requires us to call the Gettext module passing our gettext
    # backend as first argument.
    #
    # Note we use the "errors" domain, which means translations
    # should be written to the errors.po file. The :count option is
    # set by Ecto and indicates we should also apply plural rules.
    msg
  end
end
