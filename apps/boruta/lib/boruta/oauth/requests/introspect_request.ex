defmodule Boruta.Oauth.IntrospectRequest do
  @moduledoc """
  Introspect request
  """

  @typedoc """
  Type representing an introspect request as stated in [Introspect RFC](https://tools.ietf.org/html/rfc7662#section-2.1).
  """
  @type t :: %__MODULE__{
    client_id: String.t(),
    client_secret: String.t(),
    token: String.t()
  }
  defstruct client_id: "", client_secret: "", token: ""
end
