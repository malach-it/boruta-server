defmodule Boruta.Support.User do
  @moduledoc false

  defstruct id: SecureRandom.uuid(), email: "test@host", password: "password"
end
