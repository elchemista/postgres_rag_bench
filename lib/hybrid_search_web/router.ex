defmodule HybridSearchWeb.Router do
  use HybridSearchWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api", HybridSearchWeb do
    pipe_through :api
  end
end
