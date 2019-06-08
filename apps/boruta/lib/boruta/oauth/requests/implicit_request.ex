defmodule Boruta.Oauth.ImplicitRequest do
  @moduledoc """
  Implicit request
  """

  alias Boruta.Coherence.User

  @typedoc """
  Type representing an implicit request as stated in [OAuth 2.0 RFC](https://tools.ietf.org/html/rfc6749#section-4.2.1).

  Note : `resource_owner` is an addition that must be provided by the application layer.
  """
  @type t :: %__MODULE__{
    client_id: String.t(),
    redirect_uri: String.t(),
    state: String.t(),
    scope: String.t(),
    resource_owner: any()
  }
  defstruct client_id: "", redirect_uri: "", state: "", scope: "", resource_owner: %User{}
end
