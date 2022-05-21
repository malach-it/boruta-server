defmodule BorutaIdentityWeb.TemplateView do
  use BorutaIdentityWeb, :view

  alias BorutaIdentity.RelyingParties.Template
  alias BorutaIdentityWeb.ErrorHelpers

  def render("template.html", %{
        conn: conn,
        template: %Template{layout: layout, content: content, relying_party: relying_party},
        assigns: assigns
      }) do
    context =
      context(%{}, assigns)
      |> Map.put(:messages, messages(conn))
      |> Map.put(:_csrf_token, Plug.CSRFProtection.get_csrf_token())
      |> Map.merge(errors(assigns))
      |> Map.merge(paths(conn, assigns))
      |> Map.merge(relying_party_configurations(relying_party))

    {:safe, Mustachex.render(layout.content, context, partials: %{inner_content: content})}
  end

  def context(context, %{current_user: current_user} = assigns) do
    current_user = Map.from_struct(current_user)

    %{current_user: current_user}
    |> Map.merge(context)
    |> context(Map.delete(assigns, :current_user))
  end

  def context(context, %{client: client} = assigns) do
    client = Map.from_struct(client)

    %{client: client}
    |> Map.merge(context)
    |> context(Map.delete(assigns, :client))
  end

  def context(context, %{scopes: scopes} = assigns) do
    scopes = Enum.map(scopes, &Map.from_struct/1)

    %{scopes: scopes}
    |> Map.merge(context)
    |> context(Map.delete(assigns, :scopes))
  end

  def context(context, %{}), do: context

  defp paths(conn, assigns) do
    %Plug.Conn{query_params: query_params} = conn
    request = Map.get(query_params, "request")

    %{
      choose_session_path:
        Routes.choose_session_path(BorutaIdentityWeb.Endpoint, :index, %{request: request}),
      create_user_reset_password_path:
        Routes.user_reset_password_path(BorutaIdentityWeb.Endpoint, :create, %{request: request}),
      create_user_confirmation_path:
        Routes.user_confirmation_path(BorutaIdentityWeb.Endpoint, :create, %{request: request}),
      create_user_consent_path: Routes.user_consent_path(conn, :consent, %{request: request}),
      create_user_registration_path:
        Routes.user_registration_path(BorutaIdentityWeb.Endpoint, :create, %{request: request}),
      create_user_session_path:
        Routes.user_session_path(BorutaIdentityWeb.Endpoint, :create, %{request: request}),
      delete_user_session_path:
        Routes.user_session_path(BorutaIdentityWeb.Endpoint, :delete, %{request: request}),
      edit_user_path: Routes.user_settings_path(BorutaIdentityWeb.Endpoint, :edit, %{request: request}),
      new_user_registration_path:
        Routes.user_registration_path(BorutaIdentityWeb.Endpoint, :new, %{request: request}),
      new_user_reset_password_path:
        Routes.user_reset_password_path(BorutaIdentityWeb.Endpoint, :new, %{request: request}),
      new_user_session_path:
        Routes.user_session_path(BorutaIdentityWeb.Endpoint, :new, %{request: request}),
      update_user_reset_password_path:
        Routes.user_reset_password_path(
          BorutaIdentityWeb.Endpoint,
          :update,
          Map.get(assigns, :token, ""),
          %{request: request}
        ),
      update_user_path: Routes.user_settings_path(BorutaIdentityWeb.Endpoint, :update, %{request: request})
    }
  end

  defp errors(%{errors: errors}) do
    formatted_errors = Enum.map(errors, &%{message: &1})

    %{valid?: false, errors: formatted_errors}
  end

  defp errors(%{changeset: changeset}) do
    formatted_errors =
      changeset
      |> ErrorHelpers.error_messages()
      |> Enum.map(fn message -> %{message: message} end)

    %{valid?: false, errors: formatted_errors}
  end

  defp errors(_assigns), do: %{errors: [], valid?: true}

  defp messages(conn) do
    get_flash(conn)
    |> Enum.map(fn {type, value} ->
      %{
        "type" => type,
        "content" => value
      }
    end)
  end

  defp relying_party_configurations(relying_party) do
    %{
      registrable?: relying_party.registrable,
      user_editable?: relying_party.user_editable,
    }
  end
end
