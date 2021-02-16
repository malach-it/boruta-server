defmodule SimpleMintTest do
  use ExUnit.Case
  doctest SimpleMint

  test "greets the world" do
    assert SimpleMint.hello() == :world
  end
end
