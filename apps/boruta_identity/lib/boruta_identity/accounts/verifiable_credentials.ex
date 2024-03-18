defmodule BorutaIdentity.Accounts.VerifiableCredentials do
  @moduledoc false

  alias Boruta.Oauth.Client
  alias BorutaIdentity.Accounts.User
  alias BorutaIdentity.IdentityProviders.Backend
  alias BorutaIdentity.Repo

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

  def credential_configurations_supported do
    Repo.all(Backend)
    |> Enum.flat_map(fn %Backend{verifiable_credentials: credentials} ->
      Enum.map(credentials, fn credential ->
        {credential["credential_identifier"],
          %{
            "format" => credential["format"],
            # TODO add scope to backends vc configuration
            "scope" => credential["scope"],
            "cryptographic_binding_methods_supported" => [
                "did:jwk",
                "did:key"
            ],
            "credential_signing_alg_values_supported" => Client.Crypto.signature_algorithms(),
            "credential_definition" => %{
              "type" => String.split(credential["types"], " "),
              "credentialSubject" => Enum.map(credential["claims"], fn claim ->
                {claim["name"], [%{"name" => claim["label"]}]}
              end) |> Enum.into(%{})
            },
            "display" => [Map.put(credential["display"], "locale", "en-US")],
          }}
      end)
    end)
    |> Enum.into(%{})
  end

  def authorization_details(%User{backend: %Backend{} = backend}) do
    Enum.map(backend.verifiable_credentials, fn credential ->
        %{
          "type" => "openid_credential",
          "format" => credential["format"],
          "credential_configuration_id" => credential["credential_identifier"],
          "credential_identifiers" => String.split(credential["types"], " ")
        }
    end)
  end

  def authorization_details(_user), do: []

  def public_credential_configuration do
    backend = Backend.default!()

    Enum.map(backend.verifiable_credentials, fn credential ->
      {credential["credential_identifier"],
       %{
         types: String.split(credential["types"], " "),
         format: credential["format"],
         time_to_live: credential["time_to_live"] || 31_536_000,
         claims:
           case credential["claims"] do
             claim when is_binary(claim) -> String.split(claim, " ")
             claims when is_list(claims) -> claims
           end
       }}
    end)
    |> Enum.into(%{})
  end

  def credential_configuration(%User{backend: %Backend{} = backend}) do
    Enum.map(backend.verifiable_credentials, fn credential ->
      {credential["credential_identifier"],
       %{
         types: String.split(credential["types"], " "),
         format: credential["format"],
         time_to_live: credential["time_to_live"] || 31_536_000,
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
