defmodule BorutaIdentity.Accounts.Wallet do
  alias BorutaIdentity.Accounts.User
  alias BorutaIdentity.Repo

  @account_type "wallet"

  def account_type, do: @account_type

  def domain_user!(resource_owner, backend) do
    impl_user_params = %{
      uid: resource_owner.sub,
      username: resource_owner.sub,
      backend_id: backend.id,
      account_type: @account_type
    }

    metadata = resource_owner.extra_claims
    {replace, impl_user_params} =
      case metadata do
        %{} = metadata ->
          metadata = Enum.map(metadata, fn {key, value} ->
            {key, %{"value" => value, "display" => [], "status" => "valid"}}
          end)
          |> Enum.into(%{})

          {[:username, :metadata, :group], Map.put(impl_user_params, :metadata, metadata)}

        _ ->
          {[:username, :group], impl_user_params}
      end

    User.implementation_changeset(impl_user_params, backend)
    |> Repo.insert!(
      on_conflict: {:replace, replace},
      returning: true,
      conflict_target: [:backend_id, :uid]
    )
    |> Repo.preload([:authorized_scopes, :consents, :backend, :organizations])
  end

  def delete_user(_uid), do: :ok
end
