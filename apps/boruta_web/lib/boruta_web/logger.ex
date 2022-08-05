defmodule BorutaWeb.Logger do
  @moduledoc false

  require Logger

  def start do
    handlers = [
      {
        :boruta_web_requests,
        [:boruta_web, :endpoint, :stop],
        &__MODULE__.boruta_web_request_handler/4
      },
      {
        :authorization_authorize_success,
        [:authorization, :authorize, :success],
        &__MODULE__.authorization_authorize_success_handler/4
      },
      {
        :authorization_authorize_failure,
        [:authorization, :authorize, :failure],
        &__MODULE__.authorization_authorize_failure_handler/4
      },
      {
        :authorization_token_success,
        [:authorization, :token, :success],
        &__MODULE__.authorization_token_success_handler/4
      },
      {
        :authorization_token_failure,
        [:authorization, :token, :failure],
        &__MODULE__.authorization_token_failure_handler/4
      },
      {
        :authorization_introspect_success,
        [:authorization, :introspect, :success],
        &__MODULE__.authorization_introspect_success_handler/4
      },
      {
        :authorization_introspect_failure,
        [:authorization, :introspect, :failure],
        &__MODULE__.authorization_introspect_failure_handler/4
      },
      {
        :authorization_revoke_success,
        [:authorization, :revoke, :success],
        &__MODULE__.authorization_revoke_success_handler/4
      },
      {
        :authorization_revoke_failure,
        [:authorization, :revoke, :failure],
        &__MODULE__.authorization_revoke_failure_handler/4
      }
    ]

    for {handler_id, event_name, fun} <- handlers do
      :telemetry.attach(handler_id, event_name, fun, :ok)
    end
  end

  def boruta_web_request_handler(_, %{duration: duration}, %{conn: conn} = metadata, _) do
    case log_level(metadata[:options][:log], conn) do
      false ->
        :ok

      level ->
        Logger.log(
          level,
          fn ->
            %{method: method, request_path: path, status: status, state: state} = conn
            status = Integer.to_string(status)

            [
              "boruta_web",
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
          end,
          type: :request
        )
    end
  end

  def authorization_authorize_success_handler(
        _,
        _measurements,
        %{
          access_token: access_token,
          code: code,
          type: type,
          response_mode: response_mode,
          expires_in: expires_in,
          client_id: client_id,
          current_user: current_user
        },
        _
      ) do
    log_line = [
      "authorization",
      ?\s,
      "authorize",
      " - ",
      "success",
      log_attribute("client_id", client_id),
      log_attribute("sub", current_user && current_user.uid),
      log_attribute("type", type),
      log_attribute("response_mode", response_mode),
      log_attribute("access_token", access_token),
      log_attribute("code", code),
      log_attribute("expires_in", expires_in)
    ]

    Logger.log(:info, fn -> log_line end, type: :business)
  end

  def authorization_authorize_failure_handler(
        _,
        _measurements,
        %{
          status: status,
          error: error,
          error_description: error_description,
          client_id: client_id,
          current_user: current_user
        },
        _
      ) do
    log_line = [
      "authorization",
      ?\s,
      "authorize",
      " - ",
      "failure",
      log_attribute("client_id", client_id),
      log_attribute("sub", current_user && current_user.uid),
      log_attribute("status", status),
      log_attribute("error", error),
      log_attribute("error_description", ~s{"#{error_description}"})
    ]

    Logger.log(:info, fn -> log_line end, type: :business)
  end

  def authorization_token_success_handler(
        _,
        _measurements,
        %{
          client_id: client_id,
          sub: sub,
          access_token: access_token,
          token_type: token_type,
          expires_in: expires_in,
          refresh_token: refresh_token
        },
        _
      ) do
    log_line = [
      "authorization",
      ?\s,
      "token",
      " - ",
      "success",
      log_attribute("client_id", client_id),
      log_attribute("sub", sub),
      log_attribute("access_token", access_token),
      log_attribute("token_type", token_type),
      log_attribute("expires_in", expires_in),
      log_attribute("refresh_token", refresh_token)
    ]

    Logger.log(:info, fn -> log_line end, type: :business)
  end

  def authorization_token_failure_handler(
        _,
        _measurements,
        %{
          status: status,
          error: error,
          error_description: error_description
        },
        _
      ) do
    log_line = [
      "authorization",
      ?\s,
      "token",
      " - ",
      "failure",
      log_attribute("status", status),
      log_attribute("error", error),
      log_attribute("error_description", ~s{"#{error_description}"})
    ]

    Logger.log(:info, fn -> log_line end, type: :business)
  end

  def authorization_introspect_success_handler(
        _,
        _measurements,
        %{
          active: active,
          client_id: client_id,
          sub: sub,
          token: token
        },
        _
      ) do
    log_line = [
      "authorization",
      ?\s,
      "introspect",
      " - ",
      "success",
      log_attribute("client_id", client_id),
      log_attribute("sub", sub),
      log_attribute("access_token", token),
      log_attribute("active", active)
    ]

    Logger.log(:info, fn -> log_line end, type: :business)
  end

  def authorization_introspect_failure_handler(
        _,
        _measurements,
        %{
          status: status,
          error: error,
          error_description: error_description,
          token: token
        },
        _
      ) do
    log_line = [
      "authorization",
      ?\s,
      "introspect",
      " - ",
      "failure",
      log_attribute("access_token", token),
      log_attribute("status", status),
      log_attribute("error", error),
      log_attribute("error_description", ~s{"#{error_description}"})
    ]

    Logger.log(:info, fn -> log_line end, type: :business)
  end

  def authorization_revoke_success_handler(
        _,
        _measurements,
        %{
          token: token
        },
        _
      ) do
    log_line = [
      "authorization",
      ?\s,
      "revoke",
      " - ",
      "success",
      log_attribute("access_token", token)
    ]

    Logger.log(:info, fn -> log_line end, type: :business)
  end

  def authorization_revoke_failure_handler(
        _,
        _measurements,
        %{
          status: status,
          error: error,
          error_description: error_description,
          token: token
        },
        _
      ) do
    log_line = [
      "authorization",
      ?\s,
      "revoke",
      " - ",
      "failure",
      log_attribute("access_token", token),
      log_attribute("status", status),
      log_attribute("error", error),
      log_attribute("error_description", ~s{"#{error_description}"})
    ]

    Logger.log(:info, fn -> log_line end, type: :business)
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
