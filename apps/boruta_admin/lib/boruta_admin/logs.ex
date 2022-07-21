defmodule BorutaAdmin.Logs do
  @moduledoc false

  alias BorutaAuth.LogRotate

  @spec read(date :: Date.t()) :: File.Stream.t()
  def read(date) do
    File.stream!(LogRotate.path(date))
  end
end
