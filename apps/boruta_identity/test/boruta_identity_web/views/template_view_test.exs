defmodule BorutaIdentityWeb.TemplateViewTest do
  use BorutaIdentityWeb.ConnCase, async: true

  alias BorutaIdentityWeb.TemplateView

  describe "context/2" do
    test "exposes the redirect URI host", %{conn: conn} do
      {:ok, request, _claims} =
        Joken.encode_and_sign(
          %{
            "user_return_to" =>
              "/oauth/authorize?" <>
                URI.encode_query(%{
                  redirect_uri: "https://client.example:8443/callback?view=full"
                })
          },
          BorutaIdentityWeb.Token.application_signer()
        )

      conn = conn |> init_test_session(%{}) |> Map.put(:query_params, %{"request" => request})
      context = TemplateView.context(%{}, %{conn: conn})

      assert context.redirect_uri_host == "client.example"
      assert Mustachex.render("{{redirect_uri_host}}", context) == "client.example"
    end

    test "leaves redirect URI values empty without an authorization request", %{conn: conn} do
      conn = conn |> init_test_session(%{}) |> Map.put(:query_params, %{})
      context = TemplateView.context(%{}, %{conn: conn})

      assert is_nil(context.redirect_uri_host)
    end

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
