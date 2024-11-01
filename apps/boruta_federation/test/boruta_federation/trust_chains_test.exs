defmodule BorutaFederation.TrustChainsTest do
  use BorutaFederation.DataCase

  import BorutaFederation.Factory

  alias BorutaFederation.TrustChains

  describe "generate_statement/1" do
    test "generates a statement" do
      entity = insert(:entity)

      assert {:ok, statement} = TrustChains.generate_statement(entity)
      assert statement
    end
  end
end
