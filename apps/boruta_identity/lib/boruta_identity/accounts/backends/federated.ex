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

    federated_metadata =
      Enum.flat_map(federated_server["metadata_endpoints"] || [], fn endpoint ->
        case Finch.build(
               :get,
               endpoint["endpoint"],
               [
                 {"accept", "application/json"},
                 {"authorization", "Bearer #{access_token}"}
               ]
             )
             |> Finch.request(BorutaIdentity.Finch) do
          {:ok, %Finch.Response{status: 200, body: body}} ->
            body = Jason.decode!(body)

            endpoint["claims"]
            |> String.split(" ")
            |> Enum.map(fn claim ->
              {String.replace(claim, ".", "-"),
               get_in(
                 body,
                 String.split(claim, ".")
                 |> Enum.map(fn
                   ":all" -> Access.all()
                   claim -> claim
                 end)
               )}
            end)

          error ->
            raise inspect(error)
        end
      end)
      |> Enum.into(%{})

    impl_user_params = %{
      uid: to_string(userinfo["sub"] || userinfo["id"]),
      username: userinfo["email"] || "#{userinfo["sub"]}@#{federated_server["name"]}",
      federated_metadata: %{federated_server_name => Map.merge(userinfo, federated_metadata)},
      backend_id: backend.id
    }

    # TODO store origin federated server
    changeset = User.implementation_changeset(impl_user_params, backend)
    new_metadata = Ecto.Changeset.get_field(changeset, :federated_metadata)
    new_username = Ecto.Changeset.get_field(changeset, :username)

    Repo.insert!(changeset,
      on_conflict:
        from(u in User,
          update: [
            set: [
              username: ^new_username,
              federated_metadata: fragment("? || ?", u.federated_metadata, ^new_metadata)
            ]
          ]
        ),
      returning: true,
      conflict_target: [:backend_id, :uid]
    )
    |> Repo.preload([:authorized_scopes, :consents, :backend, :organizations])
  end
end
