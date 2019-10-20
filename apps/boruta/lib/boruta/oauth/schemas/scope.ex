defmodule Boruta.Oauth.Scope do
  @moduledoc """
  Schema defining an independent OAuth scope
  """
  defstruct id: nil, name: nil, public: nil

  @type t :: %__MODULE__{
    id: any(),
    name: String.t(),
    public: boolean()
  }

  @doc """
  Splits an OAuth scope string into individual scopes as string
  ## Examples
      iex> scope("a:scope another:scope")
      ["a:scope", "another:scope"]
  """
  @spec split(oauth_scope :: String.t() | nil) :: list(String.t())
  def split(nil), do: []
  def split(scope) do
    Enum.filter(
      String.split(scope, " "),
      fn (scope) -> scope != "" end # remove empty strings
    )
  end
end
