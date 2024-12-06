defmodule BorutaWeb.OpenidView do
  use BorutaWeb, :view

  alias Boruta.Openid.UserinfoResponse

  def render("userinfo.json", %{response: response}) do
    UserinfoResponse.payload(response)
  end

  def render("jwks.json", %{keys: keys}) do
    %{
      keys: Enum.flat_map(keys, fn
        %{"kty" => "RSA"} = key -> Enum.map(["RS256", "RS384", "RS512"], fn alg -> Map.put(key, "alg", alg) end)
        %{"kty" => "P-256"} = key -> Enum.map(["ES256", "ES384", "ES512"], fn alg -> Map.put(key, "alg", alg) end)
        %{"kty" => "EC"} = key -> Enum.map(["ES256", "ES384", "ES512"], fn alg -> Map.put(key, "alg", alg) end)
      end)
    }
  end

  def render("jwk.json", %{client: %Boruta.Ecto.Client{id: client_id, public_key: public_key}}) do
    {_type, jwk} = public_key |> :jose_jwk.from_pem() |> :jose_jwk.to_map()

    %{
      keys: [Map.put(jwk, :kid, client_id)]
    }
  end

  def render("userinfo.jwt", %{response: response}) do
    UserinfoResponse.payload(response)
  end

  def render("show.json", %{client: client}) do
    %{data: render_one(client, __MODULE__, "client.json")}
  end

  def render("client.json", %{client: client}) do
    %{
      client_id: client.id,
      client_secret: client.secret,
      client_secret_expires_at: 0
    }
  end

  def render("registration_error.json", %{changeset: changeset}) do
    %{
      error: "invalid_client_metadata",
      error_description: errors_full_message(changeset)
    }
  end

  defp errors_full_message(changeset) do
    Ecto.Changeset.traverse_errors(changeset, &translate_error/1)
    |> Enum.map_join(", ", fn {attribute, messages} ->
      "#{attribute} : #{Enum.join(messages, ", ")}"
    end)
  end
end
