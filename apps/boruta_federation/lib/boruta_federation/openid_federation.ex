defmodule BorutaFederation.OpenidFederationApplication do
  @callback resolve_success(context :: any, federation_entity_statement :: String.t()) :: any()
  @callback resolve_failure(context :: any, error :: Boruta.Oauth.Error.t()) :: any()
end

defmodule BorutaFederation.OpenidFederation do
  alias Boruta.Oauth.Error
  alias BorutaFederation.FederationEntities
  alias BorutaFederation.TrustChains

  @type resolve_params :: %{
          sub: String.t(),
          anchor: String.t()
        }

  @spec resolve(context :: any(), resolve_params :: resolve_params(), module :: atom()) :: any()
  def resolve(context, resolve_params, module) do
    case FederationEntities.get_entity(resolve_params[:sub]) do
      nil ->
        error = %Error{
          status: :not_found,
          error: :not_found,
          error_description: "Federation entity could not be found."
        }
        module.resolve_failure(context, error)

      entity ->
        case TrustChains.generate_statement(entity) do
          {:ok, statement} ->
            module.resolve_success(context, statement)

          {:error, error} ->
            error = %Error{
              status: :bad_request,
              error: :unknown_error,
              error_description: "Could not generate federation entity statement #{error}."
            }

            module.resolve_failure(context, error)
        end
    end
  end
end
