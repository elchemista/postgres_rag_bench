import Config

# Configure your database
config :hybrid_search, HybridSearch.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "hybrid_search_dev",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

# Enable dev routes for dashboard and mailbox
config :hybrid_search, dev_routes: true

# Do not include metadata nor timestamps in development logs
config :logger, :default_formatter, format: "[$level] $message\n"
