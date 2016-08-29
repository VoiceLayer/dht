defmodule Dht.Mixfile do
  use Mix.Project

  def project do
    [app: :dht,
     version: "0.1.0",
     elixir: "~> 1.3",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps()]
  end

  def application do
    [applications: [:logger, :dispatch],
      mod: {Dht, []}]
  end

  defp deps do
    [
       {:hash_ring, github: "voicelayer/hash-ring"},
       {:dispatch, "~> 0.1.0"}
    ]
  end
end
