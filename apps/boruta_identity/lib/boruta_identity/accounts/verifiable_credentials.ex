defmodule BorutaIdentity.Accounts.VerifiableCredentials do
  @moduledoc false

  @authorization_details [
    %{
      "type" => "openid_credential",
      "format" => "jwt_vc_json",
      "credential_definition" => %{
        "type" => [
          "VerifiableCredential",
          "UniversityDegreeCredential"
        ]
      },
      "credential_identifiers" => [
        "CivilEngineeringDegree-2023",
        "ElectricalEngineeringDegree-2023"
      ]
    }
  ]

  def credentials do
    Enum.flat_map(@authorization_details, fn detail ->
      detail["credential_definition"]["type"]
    end)
    |> Enum.uniq()
  end

  def authorization_details, do: @authorization_details
end
