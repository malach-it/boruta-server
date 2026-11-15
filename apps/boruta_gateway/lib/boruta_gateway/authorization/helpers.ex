defmodule BorutaGateway.Authorization.Helpers do
  @moduledoc false
  @default_error_content_type "application/json"
  @default_forbidden_response Jason.encode!(%{
                                error: "FORBIDDEN",
                                message: "You are forbidden to access this resource."
                              })
  @default_unauthorized_response Jason.encode!(%{
                                   error: "UNAUTHORIZED",
                                   message: "You are unauthorized to access this resource."
                                 })
  def validate_scopes(_scopes, required_scopes, _method) when required_scopes == %{},
    do: {:ok, []}

  def validate_scopes(scopes, required_scopes, method) do
    default_scopes = Map.get(required_scopes, "*", [:not_authorized])
    requested_scopes = Enum.uniq(Map.get(required_scopes, method, default_scopes))

    case Enum.empty?(requested_scopes -- scopes) do
      true -> {:ok, requested_scopes}
      false -> {:error, "required scopes are not present."}
    end
  end

  def forbidden(upstream) do
    {:forbidden, upstream.error_content_type || @default_error_content_type,
     upstream.forbidden_response || @default_forbidden_response}
  end

  def unauthorized(upstream, challenge) do
    {:unauthorized, upstream.error_content_type || @default_error_content_type,
     upstream.unauthorized_response || @default_unauthorized_response, challenge}
  end
end
