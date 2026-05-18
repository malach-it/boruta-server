defmodule BorutaIdentityWeb.TemplateViewTest do
  use BorutaIdentityWeb.ConnCase, async: true

  alias BorutaIdentityWeb.TemplateView

  describe "context/2" do
    test "sets presentation QR code when deeplink can be encoded" do
      context = TemplateView.context(%{}, %{presentation_deeplink: "openid://presentation"})

      assert is_binary(context.base64_presentation_qr_code)
      refute context.presentation_qr_code_error?
      assert context.presentation_deeplink == "openid://presentation"
    end

    test "does not raise when presentation deeplink is too large for a QR code" do
      presentation_deeplink = String.duplicate("a", 4_000)

      context = TemplateView.context(%{}, %{presentation_deeplink: presentation_deeplink})

      assert is_nil(context.base64_presentation_qr_code)
      assert context.presentation_qr_code_error?
      assert context.presentation_deeplink == presentation_deeplink
    end
  end
end
