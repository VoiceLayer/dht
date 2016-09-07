use Mix.Config

config :dispatch,
  pubsub: [name: Dispatch.PubSub,
           adapter: Phoenix.PubSub.PG2,
           opts: []],
  registry: [log_level: :debug, 
             broadcast_period: 100,
             max_silent_periods: 3]

config :logger,
  level: :info