defmodule Boruta.Oauth.ImplicitRequest do
  @moduledoc """
  TODO Implicit request
  """

  alias Boruta.Coherence.User

  defstruct client_id: "", redirect_uri: "", state: "", resource_owner: %User{}
end
