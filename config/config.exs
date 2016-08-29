use Mix.Config

config :dispatch,
  pubsub: [name: Dispatch.PubSub,
           adapter: Phoenix.PubSub.PG2,
           opts: []]

config :logger,
  level: :info