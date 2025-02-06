defmodule BorutaIdentity.Accounts.Federated do
  @moduledoc false
  @behaviour BorutaIdentity.FederatedAccounts

  import Ecto.Query

  alias BorutaIdentity.Accounts.User
  alias BorutaIdentity.Repo

  @features [
    :destroyable
  ]

  def features, do: @features

  @account_type "federated"

  def account_type, do: @account_type

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
      |> URI.to_string()

    userinfo = get_resource!(userinfo_uri, access_token)

    federated_metadata =
      Enum.flat_map(federated_server["metadata_endpoints"] || [], fn endpoint ->
        response = get_resource!(endpoint["endpoint"], access_token)

        claims_from_response(endpoint, response)
      end)
      |> Enum.into(%{})

    impl_user_params = %{
      uid: to_string(userinfo["sub"] || userinfo["id"]),
      username: userinfo["email"] || "#{userinfo["sub"]}@#{federated_server["name"]}",
      federated_metadata: %{federated_server_name => Map.merge(userinfo, federated_metadata)},
      account_type: @account_type,
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

  def delete_user(_uid), do: :ok

  defp get_resource!(url, access_token) do
    case Finch.build(:get, url, [
           {"accept", "application/json"},
           {"authorization", "Bearer #{access_token}"}
         ])
         |> Finch.request(BorutaIdentity.Finch) do
      {:ok, %Finch.Response{status: 200, body: body}} ->
        Jason.decode!(body)

      {:ok, %Finch.Response{status: status, body: body}} ->
        raise "GET #{url} failed with status #{status} - #{inspect(body)}"

      error ->
        raise inspect(error)
    end
  end

  defp claims_from_response(endpoint, body) do
    endpoint["claims"]
    |> String.split(" ")
    |> Enum.map(fn claim ->
      {String.replace(claim, ".", "-"),
       %{
         "value" =>
           get_in(
             body,
             String.split(claim, ".")
             |> Enum.map(fn
               ":all" -> Access.all()
               claim -> claim
             end)
           )
       }}
    end)
  end
end
