# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
use Mix.Config

# General application configuration
config :notification,
  ecto_repos: [Notification.Repo]

# Configures the endpoint
config :notification, NotificationWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "hHfd+3OuI39dyTsCq0jyRd0kyX14HciWpTP3g0EuNJSv/nfRFvjjsf/oO3HpWCZg",
  render_errors: [view: NotificationWeb.ErrorView, accepts: ~w(json)],
  pubsub: [name: Notification.PubSub,
           adapter: Phoenix.PubSub.PG2]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env}.exs"
