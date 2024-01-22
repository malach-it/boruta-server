defmodule BorutaIdentity.Accounts.VerifiableCredentials do
  @moduledoc false

  alias BorutaIdentity.Accounts.User
  alias BorutaIdentity.IdentityProviders.Backend
  alias BorutaIdentity.Repo

  # @available_formats ["jwt_vc_json", "jwt_vc"]
  @available_formats ["jwt_vc"]

  # @credentials_supported_draft_11 [
  #   %{
  #     "id" => "FederatedAttributes",
  #     "types" => [
  #       "VerifiableCredential",
  #       "BorutaCredential"
  #     ],
  #     "format" => "jwt_vc_json",
  #     "cryptographic_binding_methods_supported" => [
  #       "did:example"
  #     ],
  #     "display" => [
  #       %{
  #         "name" => "Federation credential PoC",
  #         "locale" => "en-US",
  #         "logo" => %{
  #           "url" => "https://io.malach.it/assets/images/logo.png",
  #           "alt_text" => "Boruta PoC logo"
  #         },
  #         "background_color" => "#53b29f",
  #         "text_color" => "#FFFFFF"
  #       }
  #     ]
  #   }
  # ]

  @credentials_supported_draft_12 %{
    "UniversityDegreeCredential" => %{
      "format" => "jwt_vc_json",
      "scope" => "UniversityDegree",
      "cryptographic_binding_methods_supported" => [
        "did:example"
      ],
      "cryptographic_suites_supported" => [
        "ES256K"
      ],
      "credential_definition" => %{
        "type" => [
          "VerifiableCredential",
          "UniversityDegreeCredential"
        ],
        "credentialSubject" => %{
          "given_name" => %{
            "display" => [
              %{
                "name" => "Given Name",
                "locale" => "en-US"
              }
            ]
          },
          "family_name" => %{
            "display" => [
              %{
                "name" => "Surname",
                "locale" => "en-US"
              }
            ]
          },
          "degree" => %{},
          "gpa" => %{
            "display" => [
              %{
                "name" => "GPA"
              }
            ]
          }
        }
      },
      "proof_types_supported" => [
        "jwt"
      ],
      "display" => [
        %{
          "name" => "University Credential",
          "locale" => "en-US",
          "logo" => %{
            "url" => "https://exampleuniversity.com/public/logo.png",
            "alt_text" => "a square logo of a university"
          },
          "background_color" => "#12107c",
          "text_color" => "#FFFFFF"
        }
      ]
    }
  }

  @authorization_details [
    %{
      "type" => "openid_credential",
      "format" => "jwt_vc_json",
      "credential_definition" => %{
        "type" => [
          "VerifiableCredential",
          "BorutaCredential"
        ]
      },
      "credential_identifiers" => [
        "FederatedAttributes"
      ]
    }
  ]

  def credentials do
    Enum.flat_map(@authorization_details, fn detail ->
      detail["credential_definition"]["type"]
    end)
    |> Enum.uniq()
  end

  def credentials_supported do
    Repo.all(Backend)
    |> Enum.flat_map(fn %Backend{verifiable_credentials: credentials} ->
      Enum.flat_map(credentials, fn credential ->
        Enum.map(@available_formats, fn format ->
          %{
            "id" => credential["credential_identifier"],
            "types" => String.split(credential["types"], " "),
            "display" => [Map.put(credential["display"], "locale", "en-US")],
            "format" => format,
            "cryptographic_binding_methods_supported" => [
              "did:example"
            ]
          }
        end)
      end)
    end)
  end

  def credentials_supported_current, do: @credentials_supported_draft_12

  def authorization_details(%User{backend: %Backend{} = backend}) do
    Enum.flat_map(backend.verifiable_credentials, fn credential ->
      Enum.map(@available_formats, fn format ->
        %{
          "type" => "openid_credential",
          "format" => format,
          "credential_definition" => %{
            "type" => String.split(credential["types"], " ")
          },
          "credential_identifiers" => [credential["credential_identifier"]]
        }
      end)
    end)
  end

  def authorization_details(_user), do: []

  def credential_configuration(%User{backend: %Backend{} = backend}) do
    %{
      "FederatedAttributes" => %{
        types: [
          "VerifiableCredential",
          "BorutaCredential"
        ],
        claims: []
      }
    }

    Enum.map(backend.verifiable_credentials, fn credential ->
      {credential["credential_identifier"],
       %{
         types: String.split(credential["types"], " "),
         claims:
           case credential["claims"] do
             claim when is_binary(claim) -> String.split(claim, " ")
             claims when is_list(claims) -> claims
           end
       }}
    end)
    |> Enum.into(%{})
  end

  def credential_configuration(_user), do: %{}
end
