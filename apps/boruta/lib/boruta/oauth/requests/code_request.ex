defmodule Boruta.Oauth.CodeRequest do
  alias Boruta.Coherence.User

  defstruct client_id: "", redirect_uri: "", user: %User{}
end
