defmodule BorutaAdmin.ConfigurationLoader.Schema do
  @moduledoc false

  alias ExJsonSchema.Schema

  def gateway do
    %{
      "type" => "object",
      "properties" => %{
        "authorize" => %{"type" => "boolean"},
        "error_content_type" => %{"type" => "string"},
        "forbidden_response" => %{"type" => "string"},
        "unauthorized_response" => %{"type" => "string"},
        "forwarded_token_private_key" => %{"type" => "string"},
        "forwarded_token_public_key" => %{"type" => "string"},
        "forwarded_token_secret" => %{"type" => "string"},
        "forwarded_token_signature_alg" => %{"type" => "string"},
        "scheme" => %{"type" => "string", "pattern" => "^(http|https)$"},
        "host" => %{"type" => "string"},
        "port" => %{"type" => "number"},
        "uris" => %{
          "type" => "array",
          "items" => %{
            "type" => "string"
          }
        },
        "strip_uri" => %{"type" => "boolean"},
        "pool_count" => %{"type" => "number"},
        "pool_size" => %{"type" => "number"},
        "max_idle_time" => %{"type" => "number"},
        "required_scopes" => %{
          "type" => "object",
          "patternProperties" => %{
            "(GET|POST|PUT|HEAD|OPTIONS|PATCH|DELETE|\\*)" => %{
              "type" => "array",
              "items" => %{
                "type" => "string",
                "pattern" => ".+"
              },
              "minItems" => 1
            }
          },
          "additionalProperties" => false
        }
      },
      "required" => ["scheme", "host", "port", "uris"],
      "additionalProperties" => false
    }
    |> Schema.resolve()
  end

  def microgateway do
    %{
      "type" => "object",
      "properties" => %{
        "node_name" => %{"type" => "string"},
        "authorize" => %{"type" => "boolean"},
        "error_content_type" => %{"type" => "string"},
        "forbidden_response" => %{"type" => "string"},
        "unauthorized_response" => %{"type" => "string"},
        "forwarded_token_private_key" => %{"type" => "string"},
        "forwarded_token_public_key" => %{"type" => "string"},
        "forwarded_token_secret" => %{"type" => "string"},
        "forwarded_token_signature_alg" => %{"type" => "string"},
        "scheme" => %{"type" => "string", "pattern" => "^(http|https)$"},
        "host" => %{"type" => "string"},
        "port" => %{"type" => "number"},
        "uris" => %{
          "type" => "array",
          "items" => %{
            "type" => "string"
          }
        },
        "strip_uri" => %{"type" => "boolean"},
        "pool_count" => %{"type" => "number"},
        "pool_size" => %{"type" => "number"},
        "max_idle_time" => %{"type" => "number"},
        "required_scopes" => %{
          "type" => "object",
          "patternProperties" => %{
            "(GET|POST|PUT|HEAD|OPTIONS|PATCH|DELETE|\\*)" => %{
              "type" => "array",
              "items" => %{
                "type" => "string",
                "pattern" => ".+"
              },
              "minItems" => 1
            }
          },
          "additionalProperties" => false
        }
      },
      "required" => ["node_name", "scheme", "host", "port", "uris"],
      "additionalProperties" => false
    }
    |> Schema.resolve()
  end

  def organization do
    %{
      "type" => "object",
      "properties" => %{
        "id" => %{"type" => "string"},
        "name" => %{"type" => "string"},
        "label" => %{"type" => "string"}
      },
      "required" => ["name"],
      "additionalProperties" => false
    }
  end

  def backend do
    %{
      "type" => "object",
      "properties" => %{
        "create_default_organization" => %{"type" => "boolean"},
        "federated_servers" => %{
          "type" => "array",
          "items" => %{
            "type" => "object",
            "properties" => %{
              "name" => %{"type" => "string", "pattern" => "^[^\s]+$"},
              "client_id" => %{"type" => "string"},
              "client_secret" => %{"type" => "string"},
              "base_url" => %{"type" => "string"},
              "discovery_path" => %{"type" => "string"},
              "userinfo_path" => %{"type" => "string"},
              "authorize_path" => %{"type" => "string"},
              "token_path" => %{"type" => "string"},
              "scope" => %{"type" => "string"},
              "federated_attributes" => %{"type" => "string"},
              "metadata_endpoints" => %{
                "type" => "array",
                "items" => %{
                  "type" => "object",
                  "properties" => %{
                    "endpoint" => %{"type" => "string"},
                    "claims" => %{"type" => "string"}
                  },
                  "required" => ["endpoint", "claims"]
                }
              }
            },
            "required" => [
              "name",
              "client_id",
              "client_secret",
              "base_url"
            ],
            "additionalProperties" => false
          }
        },
        "id" => %{"type" => "string"},
        "is_default" => %{"type" => "boolean"},
        "ldap_base_dn" => %{"type" => "string"},
        "ldap_host" => %{"type" => "string"},
        "ldap_master_dn" => %{"type" => "string"},
        "ldap_master_password" => %{"type" => "string"},
        "ldap_ou" => %{"type" => "string"},
        "ldap_pool_size" => %{"type" => "string"},
        "ldap_user_rdn_attribute" => %{"type" => "string"},
        "metadata_fields" => %{
          "type" => "array",
          "items" => %{
            "type" => "object",
            "properties" => %{
              "attribute_name" => %{"type" => "string"},
              "user_editable" => %{"type" => "boolean"},
              "scopes" => %{"type" => "array", "items" => %{"type" => "string"}}
            },
            "required" => ["attribute_name"],
            "additionalProperties" => false
          }
        },
        "name" => %{"type" => "string"},
        "password_hashing_alg" => %{"type" => "string"},
        "password_hashing_opts" => %{"type" => "object"},
        "roles" => %{
          "type" => "array",
          "items" => %{
            "type" => "object",
            "properties" => %{
              "id" => %{"type" => "string"}
            }
          }
        },
        "smtp_from" => %{"type" => "string"},
        "smtp_password" => %{"type" => "string"},
        "smtp_port" => %{"type" => "number"},
        "smtp_relay" => %{"type" => "string"},
        "smtp_ssl" => %{"type" => "boolean"},
        "smtp_tls" => %{"type" => "string"},
        "smtp_username" => %{"type" => "string"},
        "type" => %{"type" => "string"},
        "verifiable_credentials" => %{
          "type" => "array",
          "items" => %{
            "type" => "object",
            "properties" => %{
              "version" => %{"type" => "string"},
              "credential_identifier" => %{"type" => "string"},
              "time_to_live" => %{"type" => "number"},
              "types" => %{"type" => "string"},
              "format" => %{"type" => "string", "pattern" => "jwt_vc|jwt_vc_json|vc\\+sd\\-jwt"},
              "claims" => %{
                "type" => "array",
                "items" => %{
                  "type" => "object",
                  "properties" => %{
                    "name" => %{"type" => "string"},
                    "label" => %{"type" => "string"},
                    "pointer" => %{"type" => "string"}
                  },
                  "required" => ["name", "label", "pointer"]
                }
              },
              "display" => %{
                "type" => "object",
                "properties" => %{
                  "name" => %{"type" => "string"},
                  "locale" => %{"type" => "string"},
                  "background_color" => %{"type" => "string"},
                  "text_color" => %{"type" => "string"},
                  "logo" => %{
                    "type" => "object",
                    "properties" => %{
                      "url" => %{"type" => "string"},
                      "alt_text" => %{"type" => "string"}
                    }
                  }
                },
                "required" => ["name"],
                "additionalProperties" => false
              }
            },
            "required" => [
              "version",
              "credential_identifier",
              "format",
              "types",
              "claims",
              "display"
            ],
            "additionalProperties" => false
          }
        }
      },
      "required" => [],
      "additionalProperties" => false
    }
    |> Schema.resolve()
  end

  def identity_provider do
    %{
      "type" => "object",
      "properties" => %{
        "backend_id" => %{"type" => "string"},
        "choose_session" => %{"type" => "boolean"},
        "confirmable" => %{"type" => "boolean"},
        "consentable" => %{"type" => "boolean"},
        "enforce_totp" => %{"type" => "boolean"},
        "id" => %{"type" => "string"},
        "name" => %{"type" => "string"},
        "registrable" => %{"type" => "boolean"},
        "totpable" => %{"type" => "boolean"},
        "user_editable" => %{"type" => "boolean"},
        "templates" => %{
          "type" => "array",
          "items" => %{
            "type" => "object",
            "properties" => %{
              "type" => %{"type" => "string"},
              "content" => %{"type" => "string"}
            }
          }
        }
      },
      "additionalProperties" => false
    }
    |> Schema.resolve()
  end

  def client do
    %{
      "type" => "object",
      "properties" => %{
        "access_token_ttl" => %{"type" => "number"},
        "authorization_code_ttl" => %{"type" => "number"},
        "authorization_request_ttl" => %{"type" => "number"},
        "authorize_scope" => %{"type" => "boolean"},
        "authorized_scopes" => %{
          "type" => "array",
          "items" => %{
            "type" => "object",
            "properties" => %{
              "id" => %{"type" => "string"},
              "name" => %{"type" => "string"}
            }
          }
        },
        "confidential" => %{"type" => "boolean"},
        "enforce_dpop" => %{"type" => "boolean"},
        "id" => %{"type" => "string"},
        "id_token_signature_alg" => %{"type" => "string"},
        "id_token_ttl" => %{"type" => "number"},
        "identity_provider" => %{
          "type" => "object",
          "properties" => %{
            "id" => %{"type" => "string"}
          }
        },
        "jwt_public_key" => %{"type" => "string"},
        "name" => %{"type" => "string"},
        "pkce" => %{"type" => "boolean"},
        "public_refresh_token" => %{"type" => "boolean"},
        "public_revoke" => %{"type" => "boolean"},
        "redirect_uris" => %{
          "type" => "array",
          "items" => %{"type" => "string"}
        },
        "refresh_token_ttl" => %{"type" => "number"},
        "secret" => %{"type" => "string"},
        "supported_grant_types" => %{
          "type" => "array",
          "items" => %{"type" => "string"}
        },
        "token_endpoint_auth_methods" => %{
          "type" => "array",
          "items" => %{"type" => "string"}
        },
        "token_endpoint_jwt_auth_alg" => %{"type" => "string"},
        "userinfo_signed_response_alg" => %{"type" => "string"}
      },
      "required" => [],
      "additionalProperties" => false
    }
    |> Schema.resolve()
  end

  def scope do
    %{
      "type" => "object",
      "properties" => %{
        "id" => %{"type" => "string"},
        "name" => %{"type" => "string"},
        "label" => %{"type" => "string"},
        "public" => %{"type" => "boolean"}
      },
      "required" => [],
      "additionalProperties" => false
    }
  end

  def role do
    %{
      "type" => "object",
      "properties" => %{
        "id" => %{"type" => "string"},
        "name" => %{"type" => "string"},
        "scopes" => %{
          "type" => "array",
          "items" => %{
            "type" => "object",
            "properties" => %{
              "id" => %{"type" => "string"}
            }
          }
        }
      },
      "required" => [],
      "additionalProperties" => false
    }
  end

  def error_template do
    %{
      "type" => "object",
      "properties" => %{
        "type" => %{"type" => "string"},
        "content" => %{"type" => "string"}
      },
      "additionalProperties" => false
    }
    |> Schema.resolve()
  end
end
