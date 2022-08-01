defmodule BorutaIdentity.Logger do
  @moduledoc false

  require Logger

  alias BorutaIdentityWeb.ErrorHelpers

  def start do
    handlers = [
      {
        :boruta_identity_requests,
        [:boruta_identity, :endpoint, :stop],
        &__MODULE__.boruta_identity_request_handler/4
      },
      {
        :authentication_log_in_success,
        [:authentication, :log_in, :success],
        &__MODULE__.authentication_log_in_success_handler/4
      },
      {
        :authentication_log_in_failure,
        [:authentication, :log_in, :failure],
        &__MODULE__.authentication_log_in_failure_handler/4
      },
      {
        :authentication_log_out_success,
        [:authentication, :log_out, :success],
        &__MODULE__.authentication_log_out_success_handler/4
      },
      {
        :registration_create_success,
        [:registration, :create, :success],
        &__MODULE__.registration_create_success_handler/4
      },
      {
        :registration_create_failure,
        [:registration, :create, :failure],
        &__MODULE__.registration_create_failure_handler/4
      },
      {
        :registration_confirm_success,
        [:registration, :confirm, :success],
        &__MODULE__.registration_confirm_success_handler/4
      },
      {
        :registration_confirm_failure,
        [:registration, :confirm, :failure],
        &__MODULE__.registration_confirm_failure_handler/4
      },
      {
        :registration_update_success,
        [:registration, :update, :success],
        &__MODULE__.registration_update_success_handler/4
      },
      {
        :registration_update_failure,
        [:registration, :update, :failure],
        &__MODULE__.registration_update_failure_handler/4
      },
      {
        :authorization_consent_success,
        [:authorization, :consent, :success],
        &__MODULE__.authorization_consent_success_handler/4
      },
      {
        :authorization_consent_failure,
        [:authorization, :consent, :failure],
        &__MODULE__.authorization_consent_failure_handler/4
      }
    ]

    for {handler_id, event_name, fun} <- handlers do
      :telemetry.attach(handler_id, event_name, fun, :ok)
    end
  end

  def boruta_identity_request_handler(_, %{duration: duration}, %{conn: conn} = metadata, _) do
    case log_level(metadata[:options][:log], conn) do
      false ->
        :ok

      level ->
        Logger.log(level, fn ->
          %{method: method, request_path: path, status: status, state: state} = conn
          status = Integer.to_string(status)

          [
            "boruta_identity",
            ?\s,
            method,
            ?\s,
            path,
            " - ",
            connection_type(state),
            ?\s,
            status,
            " in ",
            duration(duration)
          ]
        end)
    end
  end

  def authentication_log_in_success_handler(
        _,
        _measurements,
        %{sub: sub, provider: provider, client_id: client_id},
        _
      ) do
    Logger.log(:info, fn ->
      [
        "authentication",
        ?\s,
        "log_in",
        " - ",
        "success",
        log_attribute("client_id", client_id),
        log_attribute("sub", sub),
        log_attribute("provider", provider)
      ]
    end)
  end

  def authentication_log_in_failure_handler(
        _,
        _measurements,
        %{message: message, client_id: client_id},
        _
      ) do
    Logger.log(:info, fn ->
      [
        "authentication",
        ?\s,
        "log_in",
        " - ",
        "failure",
        log_attribute("client_id", client_id),
        log_attribute("message", ~s{"#{message}"})
      ]
    end)
  end

  def authentication_log_out_success_handler(
        _,
        _measurements,
        %{sub: sub, provider: provider, client_id: client_id},
        _
      ) do
    Logger.log(:info, fn ->
      [
        "authentication",
        ?\s,
        "log_out",
        " - ",
        "success",
        log_attribute("client_id", client_id),
        log_attribute("sub", sub),
        log_attribute("provider", provider)
      ]
    end)
  end

  def registration_create_success_handler(
        _,
        _measurements,
        %{sub: sub, provider: provider, client_id: client_id} = metadata,
        _
      ) do
    Logger.log(:info, fn ->
      [
        "registration",
        ?\s,
        "create",
        " - ",
        "success",
        log_attribute("client_id", client_id),
        log_attribute("sub", sub),
        log_attribute("provider", provider),
        log_attribute("message", metadata[:message])
      ]
    end)
  end

  def registration_create_failure_handler(
        _,
        _measurements,
        %{client_id: client_id, error: %Ecto.Changeset{} = changeset},
        _
      ) do
    message = ErrorHelpers.error_messages(changeset) |> Enum.join(", ")

    Logger.log(:info, fn ->
      [
        "registration",
        ?\s,
        "create",
        " - ",
        "failure",
        log_attribute("client_id", client_id),
        log_attribute("message", ~s{"#{message}"})
      ]
    end)
  end

  def registration_confirm_success_handler(
        _,
        _measurements,
        %{sub: sub, provider: provider, client_id: client_id, token: token},
        _
      ) do
    Logger.log(:info, fn ->
      [
        "registration",
        ?\s,
        "confirm",
        " - ",
        "success",
        log_attribute("client_id", client_id),
        log_attribute("sub", sub),
        log_attribute("provider", provider),
        log_attribute("token", token)
      ]
    end)
  end

  def registration_confirm_failure_handler(
        _,
        _measurements,
        %{client_id: client_id, message: message, token: token},
        _
      ) do
    Logger.log(:info, fn ->
      [
        "registration",
        ?\s,
        "confirm",
        " - ",
        "failure",
        log_attribute("client_id", client_id),
        log_attribute("message", ~s{"#{message}"}),
        log_attribute("token", token)
      ]
    end)
  end

  def registration_update_success_handler(
        _,
        _measurements,
        %{sub: sub, provider: provider, client_id: client_id},
        _
      ) do
    Logger.log(:info, fn ->
      [
        "registration",
        ?\s,
        "update",
        " - ",
        "success",
        log_attribute("client_id", client_id),
        log_attribute("sub", sub),
        log_attribute("provider", provider)
      ]
    end)
  end

  def registration_update_failure_handler(
        _,
        _measurements,
        %{sub: sub, provider: provider, client_id: client_id, error: message},
        _
      )
      when is_binary(message) do
    Logger.log(:info, fn ->
      [
        "registration",
        ?\s,
        "update",
        " - ",
        "failure",
        log_attribute("client_id", client_id),
        log_attribute("sub", sub),
        log_attribute("provider", provider),
        log_attribute("message", ~s{"#{message}"})
      ]
    end)
  end

  def registration_update_failure_handler(
        _,
        _measurements,
        %{
          sub: sub,
          provider: provider,
          client_id: client_id,
          error: %Ecto.Changeset{} = changeset
        },
        _
      ) do
    message = ErrorHelpers.error_messages(changeset) |> Enum.join(", ")

    Logger.log(:info, fn ->
      [
        "registration",
        ?\s,
        "update",
        " - ",
        "failure",
        log_attribute("client_id", client_id),
        log_attribute("sub", sub),
        log_attribute("provider", provider),
        log_attribute("message", ~s{"#{message}"})
      ]
    end)
  end

  def authorization_consent_success_handler(
        _,
        _measurements,
        %{sub: sub, provider: provider, client_id: client_id, scopes: scopes},
        _
      ) do
    Logger.log(:info, fn ->
      [
        "authorization",
        ?\s,
        "consent",
        " - ",
        "success",
        log_attribute("client_id", client_id),
        log_attribute("sub", sub),
        log_attribute("provider", provider),
        log_attribute("scope", ~s{"#{Enum.join(scopes, " ")}"})
      ]
    end)
  end

  def authorization_consent_failure_handler(
        _,
        _measurements,
        %{sub: sub, provider: provider, client_id: client_id, scopes: scopes, message: message},
        _
      ) do
    Logger.log(:info, fn ->
      [
        "authorization",
        ?\s,
        "consent",
        " - ",
        "success",
        log_attribute("client_id", client_id),
        log_attribute("sub", sub),
        log_attribute("provider", provider),
        log_attribute("scope", ~s{"#{Enum.join(scopes, " ")}"}),
        log_attribute("message", ~s{"#{message}"})
      ]
    end)
  end

  defp log_attribute(_key, nil), do: ""
  defp log_attribute(key, attribute), do: " #{key}=#{attribute}"

  # From Phoenix.Logger
  defp log_level(nil, _conn), do: :info
  defp log_level(level, _conn) when is_atom(level), do: level

  defp log_level({mod, fun, args}, conn) when is_atom(mod) and is_atom(fun) and is_list(args) do
    apply(mod, fun, [conn | args])
  end

  defp connection_type(:set_chunked), do: "chunked"
  defp connection_type(_), do: "sent"

  defp duration(duration) do
    duration = System.convert_time_unit(duration, :native, :microsecond)

    if duration > 1000 do
      [duration |> div(1000) |> Integer.to_string(), "ms"]
    else
      [Integer.to_string(duration), "µs"]
    end
  end
end
