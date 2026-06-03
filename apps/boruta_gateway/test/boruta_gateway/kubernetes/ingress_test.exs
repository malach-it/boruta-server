defmodule BorutaGateway.Kubernetes.IngressTest do
  use ExUnit.Case

  alias BorutaGateway.Kubernetes.Ingress

  test "translates networking.k8s.io/v1 ingress rules into managed upstreams" do
    ingresses = [
      %{
        "metadata" => %{
          "name" => "api",
          "namespace" => "apps",
          "annotations" => %{
            "nginx.ingress.kubernetes.io/backend-protocol" => "HTTPS",
            "boruta.patatoid.fr/strip-uri" => "true"
          }
        },
        "spec" => %{
          "ingressClassName" => "boruta",
          "rules" => [
            %{
              "host" => "api.example.com",
              "http" => %{
                "paths" => [
                  %{
                    "path" => "/v1",
                    "backend" => %{
                      "service" => %{
                        "name" => "api-service",
                        "port" => %{"name" => "https"}
                      }
                    }
                  }
                ]
              }
            }
          ]
        }
      }
    ]

    services = [
      %{
        "metadata" => %{"namespace" => "apps", "name" => "api-service"},
        "spec" => %{"ports" => [%{"name" => "https", "port" => 8443}]}
      }
    ]

    assert [
             %{
               node_name: "global",
               virtual_host: "api.example.com",
               scheme: "https",
               host: "api-service.apps.svc.cluster.local",
               port: 8443,
               uris: ["/v1"],
               strip_uri: true,
               authorize: false,
               required_scopes: %{},
               managed_id: "apps|api|api.example.com|/v1|api-service|https"
             }
           ] =
             Ingress.desired_upstreams(ingresses, services,
               ingress_class: "boruta",
               node_name: "global"
             )
  end

  test "ignores ingresses for a different ingress class" do
    ingresses = [
      %{
        "metadata" => %{"name" => "api", "namespace" => "apps"},
        "spec" => %{"ingressClassName" => "nginx", "rules" => []}
      }
    ]

    assert [] = Ingress.desired_upstreams(ingresses, [], ingress_class: "boruta")
  end

  test "translates authorization annotations into managed upstream fields" do
    ingresses = [
      %{
        "metadata" => %{
          "name" => "api",
          "namespace" => "apps",
          "annotations" => %{
            "boruta.patatoid.fr/authorize" => "true",
            "boruta.patatoid.fr/required-scopes" => Jason.encode!(%{"GET" => ["api:read"]}),
            "boruta.patatoid.fr/error-content-type" => "application/problem+json",
            "boruta.patatoid.fr/forbidden-response" => ~s({"error":"forbidden"}),
            "boruta.patatoid.fr/unauthorized-response" => ~s({"error":"unauthorized"}),
            "boruta.patatoid.fr/forwarded-token-signature-alg" => "HS256",
            "boruta.patatoid.fr/forwarded-token-secret" => "secret",
            "boruta.patatoid.fr/forwarded-token-public-key" => "public",
            "boruta.patatoid.fr/forwarded-token-private-key" => "private"
          }
        },
        "spec" => %{
          "rules" => [
            %{
              "http" => %{
                "paths" => [
                  %{
                    "path" => "/v1",
                    "backend" => %{
                      "service" => %{
                        "name" => "api-service",
                        "port" => %{"number" => 8080}
                      }
                    }
                  }
                ]
              }
            }
          ]
        }
      }
    ]

    assert [
             %{
               authorize: true,
               required_scopes: %{"GET" => ["api:read"]},
               error_content_type: "application/problem+json",
               forbidden_response: ~s({"error":"forbidden"}),
               unauthorized_response: ~s({"error":"unauthorized"}),
               forwarded_token_signature_alg: "HS256",
               forwarded_token_secret: "secret",
               forwarded_token_public_key: "public",
               forwarded_token_private_key: "private"
             }
           ] = Ingress.desired_upstreams(ingresses, [])
  end
end
