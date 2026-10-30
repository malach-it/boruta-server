defmodule BorutaAuth.TokenGenerator do
  @moduledoc false
  @behaviour Boruta.Oauth.TokenGenerator

  @basic_prefix "basic-"

  alias Boruta.ClientsAdapter

  def generate_basic(params) do
    client = ClientsAdapter.public!()

    payload =
      params
      |> Enum.map(fn
        {:client, %{id: client_id}} ->
          {:client, client_id, client.secret}

        {:client_id, client_id} ->
          {:client, client_id, client.secret}

        {:sub, sub} ->
          {:sub, sub}

        {:resource_owner, resource_owner} ->
          {:resource_owner, resource_owner.sub, resource_owner.username}

        {:scope, scope} ->
          {:scope, scope}

        _ ->
          nil
      end)
      |> Enum.reject(&is_nil/1)
      |> Enum.sort()
      |> :erlang.term_to_binary()

    counter = floor(:os.system_time(:seconds) / client.access_token_ttl)

    @basic_prefix <>
      (:crypto.mac(:hmac, :sha256, payload, <<counter::size(64)>>)
       |> Base.encode16()
       |> String.downcase())
  end

  @impl true
  def generate(:access_token, %{authorization_details: [%{"format" => "basic_auth"}]} = token) do
    token
    |> Map.from_struct()
    |> generate_basic()
  end

  def generate(:access_token, token) do
    Boruta.TokenGenerator.generate(:access_token, token)
  end

  defdelegate generate(type, token), to: Boruta.TokenGenerator
  @impl true
  defdelegate secret(client), to: Boruta.TokenGenerator
  @impl true
  defdelegate tx_code_input_mode(), to: Boruta.TokenGenerator
  @impl true
  defdelegate tx_code_length(), to: Boruta.TokenGenerator
end
