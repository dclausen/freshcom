use Mix.Config

config :ex_unit, capture_log: true

config :argon2_elixir, t_cost: 1, m_cost: 8

config :eventstore, EventStore.Storage,
  serializer: Commanded.Serialization.JsonSerializer,
  username: System.get_env("DB_USERNAME"),
  database: "freshcom_eventstore_test",
  hostname: "localhost",
  pool_size: 10

# Print only warnings and errors during test
config :logger, level: :warn

config :fc_state_storage, adapter: FCStateStorage.MemoryAdapter

config :freshcom, Freshcom.Repo,
  adapter: Ecto.Adapters.Postgres,
  database: "freshcom_projections_test",
  hostname: "localhost",
  username: System.get_env("DB_USERNAME"),
  pool: Ecto.Adapters.SQL.Sandbox