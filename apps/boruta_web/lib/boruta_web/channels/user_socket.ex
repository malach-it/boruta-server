defmodule BorutaWeb.UserSocket do
  use Phoenix.Socket

  alias Boruta.Oauth.Authorization
  alias BorutaWeb.Authorization

  ## Channels
  channel "metrics:*", BorutaWeb.MetricsChannel

  @dialyzer {:no_match, connect: 3}
  def connect(%{"token" => token}, socket, _connect_info) do
    case Authorization.introspect(token) do
      {:ok, %SimpleMint.Response{body: %{"active" => true, "sub" => sub}} = _response} ->
        {:ok, assign(socket, :user_id, sub)}
      {:error, _reason} -> :error
    end
  end
  def connect(_params, _socket, _connect_info) do
    :error
  end

  def id(socket), do: "user_socket:#{socket.assigns.user_id}"
end
