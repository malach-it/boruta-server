defmodule Boruta.Oauth.IntrospectRequest do
  @moduledoc """
  TODO Introspect request
  """

  @type t :: %__MODULE__{
    client_id: String.t(),
    client_secret: String.t(),
    token: String.t()
  }
  defstruct client_id: "", client_secret: "", token: ""
end
