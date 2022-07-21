import Config

for config <- "../apps/*/config/config.exs" |> Path.expand(__DIR__) |> Path.wildcard() do
  import_config config
end

config :logger,
  backends: [{LoggerFileBackend, :file_logger}, :console]

config :logger, :file_logger,
  path: "./log/test",
  metadata: [:request_id],
  level: :info

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :phoenix, :json_library, Jason

config :mime, :types, %{
  "application/jwt" => ["jwt"]
}

import_config "#{Mix.env()}.exs"
