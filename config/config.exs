import Config

for config <- "../apps/*/config/config.exs" |> Path.expand(__DIR__) |> Path.wildcard() do
  import_config config
end

config :logger, utc_log: true

Enum.map([:request, :business], fn type ->
  Enum.map([:boruta_web, :boruta_identity, :boruta_admin, :boruta_gateway], fn application ->
    config :logger, :"#{application}_#{type}_logger",
      format: "$dateT$timeZ $metadata[$level] $message\n",
      path: "./log/test",
      metadata: [:request_id],
      metadata_filter: [application: application, type: type],
      level: :info
  end)
end)

config :logger, :default_formatter,
  format: "$dateT$timeZ $metadata[$level] $message\n",
  metadata: [:request_id],
  utc_log: true

config :logger, :default_handler,
  level: :info

config :phoenix, :json_library, Jason

config :mime, :types, %{
  "text/event-stream" => ["event-stream"],
  "application/jwt" => ["jwt"]
}

import_config "#{Mix.env()}.exs"
