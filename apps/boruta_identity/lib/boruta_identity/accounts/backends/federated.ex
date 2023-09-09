defmodule BorutaIdentity.Accounts.Federated do
  @moduledoc false
  @behaviour BorutaIdentity.FederatedAccounts

  alias BorutaIdentity.Accounts.User
  alias BorutaIdentity.Repo

  @impl BorutaIdentity.FederatedAccounts
  def domain_user!(federated_server_name, access_token, backend) do
    federated_server =
      Enum.find(backend.federated_servers, fn %{"name" => name} ->
        name == federated_server_name
      end)

    base_url = URI.parse(federated_server["base_url"])

    userinfo =
      case Finch.build(
             :get,
             URI.to_string(%{base_url | path: federated_server["userinfo_path"]}),
             [
               {"accept", "application/json"},
               {"authorization", "Bearer #{access_token}"}
             ]
           )
           |> Finch.request(BorutaIdentity.Finch) do
        {:ok, %Finch.Response{status: 200, body: body}} ->
          Jason.decode!(body)

        error ->
          raise inspect(error)
      end

    impl_user_params = %{
      uid: userinfo["sub"],
      username: userinfo["email"] || "#{userinfo["sub"]}@#{federated_server["name"]}",
      backend_id: backend.id
    }

    # TODO store origin federated server
    User.implementation_changeset(impl_user_params, backend)
    |> Repo.insert!(
      on_conflict: {:replace, [:username]},
      returning: true,
      conflict_target: [:backend_id, :uid]
    )
    |> Repo.preload([:authorized_scopes, :consents, :backend, :organizations])
  end
end
