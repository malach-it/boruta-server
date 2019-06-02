defmodule Boruta.Oauth.CodeRequest do
  @moduledoc """
  TODO Code request
  """

  alias Boruta.Coherence.User

  defstruct client_id: "", redirect_uri: "", state: "", resource_owner: %User{}, scope: ""
end
