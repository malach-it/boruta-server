defmodule BorutaIdentity.Accounts.ChooseSessionApplication do
  @moduledoc """
  TODO ConsentApplication documentation
  """

  @callback choose_session_initialized(
              context :: any(),
              template :: BorutaIdentity.IdentityProviders.Template.t()
            ) :: any()

  @callback choose_session_not_required(context :: any()) :: any()
end

defmodule BorutaIdentity.Accounts.ChooseSessions do
  @moduledoc false

  import BorutaIdentity.Accounts.Utils, only: [defwithclientrp: 2]

  alias BorutaIdentity.IdentityProviders

  @spec initialize_choose_session(context :: any(), client_id :: String.t(), module :: atom()) ::
          callback_result :: any()
  defwithclientrp initialize_choose_session(context, client_id, module) do
    case client_rp.choose_session do
      true ->
        module.choose_session_initialized(context, new_choose_session_template(client_rp))
      false ->
        module.choose_session_not_required(context)
    end
  end

  defp new_choose_session_template(identity_provider) do
    IdentityProviders.get_identity_provider_template!(identity_provider.id, :choose_session)
  end
end
