# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
use Mix.Config

# General application configuration
config :tudo,
  ecto_repos: [Tudo.Repo]

# Configures the endpoint
config :tudo, Tudo.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "sQevW4xtgHvQW8GRGvC+xpHqTHz6fHU7y6WujMJuFy0qipl3a2tysAbXmpwdMfCF",
  render_errors: [view: Tudo.ErrorView, accepts: ~w(html json)],
  pubsub: [name: Tudo.PubSub,
           adapter: Phoenix.PubSub.PG2]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env}.exs"
