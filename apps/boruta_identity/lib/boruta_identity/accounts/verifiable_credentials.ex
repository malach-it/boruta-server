defmodule BorutaIdentity.Accounts.VerifiableCredentials do
  @moduledoc false

  @credentials_supported_draft_11 [
    %{
      "id" => "FederatedAttributes",
      "types" => [
        "VerifiableCredential",
        "BorutaCredential"
      ],
      "format" => "jwt_vc_json",
      "cryptographic_binding_methods_supported" => [
        "did:example"
      ],
      "display" => [
        %{
          "name" => "Federation credential PoC",
          "locale" => "en-US",
          "logo" => %{
            "url" => "https://io.malach.it/assets/images/logo.png",
            "alt_text" => "Boruta PoC logo"
          },
          "background_color" => "#53b29f",
          "text_color" => "#FFFFFF"
        }
      ]
    }
  ]

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

  @credential_configuration %{
    "FederatedAttributes" => %{
      types: [
        "VerifiableCredential",
        "BorutaCredential"
      ],
      claims: ["family_name", "email", "email_verified"]
    }
  }

  def credentials do
    Enum.flat_map(@authorization_details, fn detail ->
      detail["credential_definition"]["type"]
    end)
    |> Enum.uniq()
  end

  def authorization_details, do: @authorization_details

  def credentials_supported, do: @credentials_supported_draft_11

  def credentials_supported_current, do: @credentials_supported_draft_12

  def credential_configuration, do: @credential_configuration
end
