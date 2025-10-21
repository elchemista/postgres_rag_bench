defmodule HybridSearch.Repo do
  use Ecto.Repo,
    otp_app: :hybrid_search,
    adapter: Ecto.Adapters.Postgres
end
