defmodule BorutaIdentity.Accounts.Federated do
  @moduledoc false
  @behaviour BorutaIdentity.FederatedAccounts

  import Ecto.Query

  alias BorutaIdentity.Accounts.User
  alias BorutaIdentity.Repo

  @impl BorutaIdentity.FederatedAccounts
  def domain_user!(federated_server_name, access_token, backend) do
    federated_server =
      Enum.find(backend.federated_servers, fn %{"name" => name} ->
        name == federated_server_name
      end)

    base_url = URI.parse(federated_server["base_url"])

    userinfo_uri =
      case URI.parse(federated_server["userinfo_path"]) do
        %URI{host: host} = uri when not is_nil(host) ->
          uri

        %URI{path: path} ->
          %{base_url | path: path}
      end

    userinfo =
      case Finch.build(
             :get,
             URI.to_string(userinfo_uri),
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
      uid: userinfo["sub"] || userinfo["id"],
      username: userinfo["email"] || "#{userinfo["sub"]}@#{federated_server["name"]}",
      metadata: userinfo,
      backend_id: backend.id
    }

    # TODO store origin federated server
    changeset = User.implementation_changeset(impl_user_params, backend)
    new_metadata = Ecto.Changeset.get_field(changeset, :metadata)
    new_username = Ecto.Changeset.get_field(changeset, :username)

    Repo.insert!(changeset,
      # TODO federated metadata will erase existing metadata
      on_conflict: from(u in User, update: [
        set: [username: ^new_username, metadata: fragment("? || ?", u.metadata, ^new_metadata)]
      ]),
      returning: true,
      conflict_target: [:backend_id, :uid]
    )
    |> Repo.preload([:authorized_scopes, :consents, :backend, :organizations])
  end
end
