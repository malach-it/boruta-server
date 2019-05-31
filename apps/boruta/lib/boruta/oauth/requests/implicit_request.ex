defmodule Boruta.Oauth.ImplicitRequest do
  alias Boruta.Coherence.User

  defstruct client_id: "", redirect_uri: "", resource_owner: %User{}
end
