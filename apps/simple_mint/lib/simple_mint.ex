defmodule SimpleMint do
  @moduledoc false
  # TODO unit test and refactor

  defmodule Response do
    @moduledoc false
    defstruct body: nil
  end
  @moduledoc """
  Documentation for `SimpleMint`.
  """

  @doc """
  Hello world.

  ## Examples

      iex> SimpleMint.hello()
      :world

  """
  def hello do
    :world
  end

  def post(uri, data, opts) do
    %URI{scheme: scheme, host: host, port: port, path: path} = URI.parse(uri)
    with {:ok, conn} <- Mint.HTTP.connect(String.to_atom(scheme), host, port),
         {:ok, conn, _request_ref} <- Mint.HTTP.request(conn, "POST", path, opts[:headers] || [], Jason.encode!(data)) do
      receive do
        message ->
          case Mint.HTTP.stream(conn, message) do
            :unknown -> {:ok, handle_message(message)}
            {:ok, conn, responses} -> {:ok, handle_responses(conn, responses)}
          end
      after
        opts[:timeout] || 30_000 -> {:error, :timeout}
      end
    end
  end

  def handle_responses(_conn, responses) do
    Enum.reduce(responses, %Response{}, fn
      ({:data, _request_ref, body}, response) ->
        case Jason.decode(body) do
          {:ok, data} -> %{response|body: data}
          {:error, reason} -> %{response|body: {:error, reason}}
        end
      _, response -> response
    end)
  end

  def handle_message({_ref, {_status, _headers, body}}) do
    response = %Response{}
    case Jason.decode(body) do
      {:ok, data} -> %{response|body: data}
      {:error, reason} -> %{response|body: {:error, reason}}
    end
  end
end
