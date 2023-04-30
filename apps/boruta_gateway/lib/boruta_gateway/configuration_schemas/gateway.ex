defmodule BorutaGateway.ConfigurationSchemas.GatewaySchema do
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
      "required" => ["scheme", "host", "port", "uris"]
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
      "required" => ["node_name", "scheme", "host", "port", "uris"]
    }
    |> Schema.resolve()
  end
end
