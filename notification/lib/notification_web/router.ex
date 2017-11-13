defmodule NotificationWeb.Router do
  use NotificationWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api", NotificationWeb do
    pipe_through :api
  end
end
