defmodule BorutaWeb.Integration.DirectPostTest do
  use BorutaWeb.ConnCase, async: false

  alias Boruta.VerifiableCredentials

  setup %{conn: conn} do
    client = Boruta.Factory.insert(:client, id_token_signature_alg: "RS512")

    code =
      Boruta.Factory.insert(:token,
        type: "code",
        redirect_uri: "http://redirect.uri",
        state: "state",
        sub:
          "did:jwk:eyJlIjoiQVFBQiIsImt0eSI6IlJTQSIsIm4iOiIxUGFQX2diWGl4NWl0alJDYWVndklfQjNhRk9lb3hsd1BQTHZmTEhHQTRRZkRtVk9mOGNVOE91WkZBWXpMQXJXM1BubndXV3kzOW5WSk94NDJRUlZHQ0dkVUNtVjdzaERIUnNyODYtMkRsTDdwd1VhOVF5SHNUajg0ZkFKbjJGdjloOW1xckl2VXpBdEVZUmxHRnZqVlRHQ3d6RXVsbHBzQjBHSmFmb3BVVEZieThXZFNxM2RHTEpCQjFyLVE4UXRabkF4eHZvbGh3T21Za0Jra2lkZWZtbTQ4WDdoRlhMMmNTSm0yRzd3UXlpbk9leV9VOHhEWjY4bWdUYWtpcVMyUnRqbkZEMGRucEJsNUNZVGU0czZvWktFeUZpRk5pVzRLa1IxR1Zqc0t3WTlvQzJ0cHlRMEFFVU12azlUOVZkSWx0U0lpQXZPS2x3RnpMNDljZ3daRHcifQ"
      )

    signer =
      Joken.Signer.create("RS256", %{"pem" => private_key_fixture()}, %{
        "kid" =>
          "did:jwk:eyJlIjoiQVFBQiIsImt0eSI6IlJTQSIsIm4iOiIxUGFQX2diWGl4NWl0alJDYWVndklfQjNhRk9lb3hsd1BQTHZmTEhHQTRRZkRtVk9mOGNVOE91WkZBWXpMQXJXM1BubndXV3kzOW5WSk94NDJRUlZHQ0dkVUNtVjdzaERIUnNyODYtMkRsTDdwd1VhOVF5SHNUajg0ZkFKbjJGdjloOW1xckl2VXpBdEVZUmxHRnZqVlRHQ3d6RXVsbHBzQjBHSmFmb3BVVEZieThXZFNxM2RHTEpCQjFyLVE4UXRabkF4eHZvbGh3T21Za0Jra2lkZWZtbTQ4WDdoRlhMMmNTSm0yRzd3UXlpbk9leV9VOHhEWjY4bWdUYWtpcVMyUnRqbkZEMGRucEJsNUNZVGU0czZvWktFeUZpRk5pVzRLa1IxR1Zqc0t3WTlvQzJ0cHlRMEFFVU12azlUOVZkSWx0U0lpQXZPS2x3RnpMNDljZ3daRHcifQ",
        "typ" => "openid4vci-proof+jwt"
      })

    {:ok, id_token, _claims} =
      VerifiableCredentials.Token.generate_and_sign(
        %{
          "iss" =>
            "did:jwk:eyJlIjoiQVFBQiIsImt0eSI6IlJTQSIsIm4iOiIxUGFQX2diWGl4NWl0alJDYWVndklfQjNhRk9lb3hsd1BQTHZmTEhHQTRRZkRtVk9mOGNVOE91WkZBWXpMQXJXM1BubndXV3kzOW5WSk94NDJRUlZHQ0dkVUNtVjdzaERIUnNyODYtMkRsTDdwd1VhOVF5SHNUajg0ZkFKbjJGdjloOW1xckl2VXpBdEVZUmxHRnZqVlRHQ3d6RXVsbHBzQjBHSmFmb3BVVEZieThXZFNxM2RHTEpCQjFyLVE4UXRabkF4eHZvbGh3T21Za0Jra2lkZWZtbTQ4WDdoRlhMMmNTSm0yRzd3UXlpbk9leV9VOHhEWjY4bWdUYWtpcVMyUnRqbkZEMGRucEJsNUNZVGU0czZvWktFeUZpRk5pVzRLa1IxR1Zqc0t3WTlvQzJ0cHlRMEFFVU12azlUOVZkSWx0U0lpQXZPS2x3RnpMNDljZ3daRHcifQ"
        },
        signer
      )

    {:ok,
     client: client,
     id_token: id_token,
     code: code,
     conn: put_req_header(conn, "content-type", "application/x-www-form-urlencoded")}
  end

  describe "SIOPV2 direct post" do
    test "unauthorized with a bad id_token", %{conn: conn} do
      conn =
        post(
          conn,
          "/openid/direct_post/bad_code",
          "id_token=bad_id_token"
        )

      assert json_response(conn, 401) == %{
               "error" => "unauthorized",
               "error_description" =>
                 "{:error, :token_malformed}"
             }
    end

    @tag :skip
    test "not found with a bad code", %{id_token: id_token, conn: conn} do
      conn =
        post(
          conn,
          "/openid/direct_post/bad_code",
          "id_token=#{id_token}"
        )

      assert response(conn, 404)
    end

    @tag :skip
    test "authenticates", %{id_token: id_token, code: code, conn: conn} do
      conn =
        post(
          conn,
          "/openid/direct_post/#{code.id}",
          "id_token=#{id_token}"
        )

      assert redirected_to(conn) =~ ~r/#{code.redirect_uri}/
      assert redirected_to(conn) =~ ~r/code=#{code.value}/
      assert redirected_to(conn) =~ ~r/state=#{code.state}/
    end
  end

  def public_key_fixture do
    "-----BEGIN RSA PUBLIC KEY-----\nMIIBCgKCAQEA1PaP/gbXix5itjRCaegvI/B3aFOeoxlwPPLvfLHGA4QfDmVOf8cU\n8OuZFAYzLArW3PnnwWWy39nVJOx42QRVGCGdUCmV7shDHRsr86+2DlL7pwUa9QyH\nsTj84fAJn2Fv9h9mqrIvUzAtEYRlGFvjVTGCwzEullpsB0GJafopUTFby8WdSq3d\nGLJBB1r+Q8QtZnAxxvolhwOmYkBkkidefmm48X7hFXL2cSJm2G7wQyinOey/U8xD\nZ68mgTakiqS2RtjnFD0dnpBl5CYTe4s6oZKEyFiFNiW4KkR1GVjsKwY9oC2tpyQ0\nAEUMvk9T9VdIltSIiAvOKlwFzL49cgwZDwIDAQAB\n-----END RSA PUBLIC KEY-----\n\n"
  end

  def private_key_fixture do
    "-----BEGIN RSA PRIVATE KEY-----\nMIIEowIBAAKCAQEA1PaP/gbXix5itjRCaegvI/B3aFOeoxlwPPLvfLHGA4QfDmVO\nf8cU8OuZFAYzLArW3PnnwWWy39nVJOx42QRVGCGdUCmV7shDHRsr86+2DlL7pwUa\n9QyHsTj84fAJn2Fv9h9mqrIvUzAtEYRlGFvjVTGCwzEullpsB0GJafopUTFby8Wd\nSq3dGLJBB1r+Q8QtZnAxxvolhwOmYkBkkidefmm48X7hFXL2cSJm2G7wQyinOey/\nU8xDZ68mgTakiqS2RtjnFD0dnpBl5CYTe4s6oZKEyFiFNiW4KkR1GVjsKwY9oC2t\npyQ0AEUMvk9T9VdIltSIiAvOKlwFzL49cgwZDwIDAQABAoIBAG0dg/upL8k1IWiv\n8BNphrXIYLYQmiiBQTPJWZGvWIC2sl7i40yvCXjDjiRnZNK9HwgL94XtALCXYRFR\nJD41bRA3MO5A0HSPIWwJXwS10/cU56HVCNHjwKa6Rz/QiG2kNASMZEMzlvHtrjna\ndx36/sjI3HH8gh1BaTZyiuDE72SMkPbL838jfL1YY9uJ0u6hWFDbdn3sqPfJ6Cnz\n1cu0piT35nkilnIGCNYA0i3lyMeo4XrdXaAJdN9nnqbCi5ewQWqaHbrIIY5LTgzJ\nYlOr3IiecyokFxHCbULXle60u0KqXYgBHmlQJJr1Dj4c9AkQmefjC2jRMlhOrIzo\nIkIUeMECgYEA+MNLB+w6vv1ogqzM3M1OLt6bziWJCn+XkziuMrCiY9KeDD+S70+E\nhfbhM5RjCE3wxC/k59039laT973BmdMHxrDd2zSjOFmCIORv5yrD5oBHMaMZcwuQ\n45Xisi4aoQoOhyznSnjo/RjeQB7qEDzXFznLLNT79HzqyAtCWD3UIu8CgYEA2yik\n9FKl7HJEY94D2K6vNh1AHGnkwIQC72pXzlUrVuwQYngj6/Gkhw8ayFBApHfwVCXj\no9rDYPdNrrAs0Zz0JsiJp6bOCEKCrMYE16UiejUUAg/OZ5eg6+3m3/iWatkzLUuK\n1LIkVBJlEyY0uPuAaBF0V0VleNvfCGhVYOn46+ECgYAUD4OsduNh5YOZDiBTKgdF\nBlSgMiyz+QgbKjX6Bn6B+EkgibvqqonwV7FffHbkA40H9SjLfe52YhL6poXHRtpY\nroillcAX2jgBOQrBJJS5sNyM5y81NNiRUdP/NHKXS/1R71ATlF6NkoTRvOx5NL7P\ns6xryB0tYSl5ylamUQ4bZwKBgHF6FB9mA//wErVbKcayfIqajq2nrwh30kVBXQG7\nW9uAE+PIrWDoF/bOvWFnHHGMoOYRUFNxXKUCqDiBhFNs34aNY6lpV1kzhxIK3ksC\neF2qyhdfM9Kz0mEXJ+pkfw4INNWJPfNv4hueArPtnnMB1rUMBJ+DkU0JG+zwiPTL\ncVZBAoGBAM6kOsh5KGn3aI83g9ZO0TrKLXXFotxJt31Wu11ydj9K33/Qj3UXcxd4\nJPXr600F0DkLeUKBob6BALeHFWcrSz5FGLGRqdRxdv+L6g18WH5m2xEs7o6M6e5I\nIhyUC60ZewJ2M8rV4KgCJJdZE2kENlSgjU92IDVPT9Oetrc7hQJd\n-----END RSA PRIVATE KEY-----\n\n"
  end
end
