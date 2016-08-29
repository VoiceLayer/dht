defmodule Dht do
  use Application

  def start(_type, _args) do
    unless node() == "node1@127.0.0.1", do: Node.connect(:"node1@127.0.0.1")
    unless node() == "node2@127.0.0.1", do: Node.connect(:"node2@127.0.0.1")
    Dht.Supervisor.start_link
  end
end
