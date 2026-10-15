defmodule BorutaWeb.PresentationServerTest do
  use ExUnit.Case, async: false

  alias BorutaWeb.PresentationServer

  describe "presentation lifecycle" do
    test "removes a presentation after an authentication event" do
      code = unique_code()

      assert :ok = PresentationServer.start_presentation(code)
      PresentationServer.authenticated(code, "https://client.example/callback")

      assert_receive {:authenticated, "https://client.example/callback"}
      refute Map.has_key?(presentations(), code)
    end

    test "removes a presentation after a message event" do
      code = unique_code()

      assert :ok = PresentationServer.start_presentation(code)
      PresentationServer.message(code, "Credential issued")

      assert_receive {:message, "Credential issued"}
      refute Map.has_key?(presentations(), code)
    end

    test "removes a presentation when cancelled" do
      code = unique_code()

      assert :ok = PresentationServer.start_presentation(code)
      PresentationServer.cancel_presentation(code)

      refute Map.has_key?(presentations(), code)
    end
  end

  defp presentations do
    %{presentations: presentations} = :sys.get_state(PresentationServer)
    presentations
  end

  defp unique_code do
    "presentation-#{System.unique_integer([:positive])}"
  end
end
