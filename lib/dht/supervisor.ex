defmodule Dht.Supervisor do
  use Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, :ok, [])
  end

  def init(_) do
    children = [
      worker(Dht.Service, []),
    ]
    supervise(children, strategy: :one_for_one)
  end

end