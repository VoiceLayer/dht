defmodule Dht.Service do
  use GenServer
  alias Dispatch.Service
  require Logger

  def start_link() do
    GenServer.start_link(__MODULE__, [type: "dht"])
  end

  def init(opts) do
    :ok = Service.init(opts)
    pubsub_server = Application.get_env(:dispatch, :pubsub)
                  |> Keyword.get(:name, Dispatch.PubSub)

    Phoenix.PubSub.subscribe(pubsub_server, "dht")
    values = :ets.new(:values, [:set])
    replicas = :ets.new(:replicas, [:set])
    {:ok, %{values: values, replicas: replicas}}
  end

  def set(key, value) do
    res = Service.multi_call(2, "dht", key, {:set, key, value})    
    res |> Enum.map(&elem(&1, 1)) |> Enum.any?()
  end

  def get(key, default \\ nil) do
    res = Service.multi_call(2, "dht", key, {:get, key})
    resolve_conflicts(key, res, default)
  end

  defp resolve_conflicts(key, res, default) do
    {value, pids} = Enum.reduce(res, {default, []}, fn 
      ({:ok, pid, []}, {current, pids}) ->
        {current, [pid | pids]}
      ({:ok, _pid, [{^key, val}]}, {^default, pids}) when val != default ->
        {val, pids}
      ({:ok, pid, [{^key, val}]}, {current, pids}) when val != current or val == default ->
        {current, [pid | pids]}
      (_, acc) -> acc
    end)
    update_replicas(key, value, pids, default)
  end

  defp update_replicas(key, value, pids, default) do
    parent = self
    if value != default do
      Enum.each(pids, fn pid ->
        # update value
        Task.async(fn ->
          Process.unlink(parent)
          GenServer.call(pid, {:set, key, value})
          Logger.info("Updated replica #{inspect pid} with #{inspect {key, value}}")
        end)
      end)
    end
    value
  end

  # GenServer Functions
  def handle_call({:set, key, val}, _from, state) do
    replicas = Dispatch.Registry.find_multi_service(2, "dht", key)
    :ets.insert(state.replicas, {key, replicas})
    res = :ets.insert(state.values, {key, val})
    Logger.info("Set #{inspect {key, val}}")
    {:reply, res, state}
  end

  def handle_call({:get, key}, _from, state) do
    res = :ets.lookup(state.values, key)
    Logger.info("Get #{inspect res}")
    {:reply, res, state}
  end

  def handle_info(msg, state) do
    case msg do
      {:join, pid, %{node: _node}} ->
        :ets.foldl(fn({key, value}, _) ->
          (new_replicas = Dispatch.Registry.find_multi_service(2, "dht", key))
          |> Enum.filter(fn({_node, rpid}) -> rpid == self() end)
          |> case do
            [] ->
              parent = self()
              :ets.delete(state.values, key)
              :ets.delete(state.replicas, key)
              Task.async(fn ->
                Process.unlink(parent)
                GenServer.call(pid, {:set, key, value})
                Logger.info("Migrated replica #{inspect pid} with #{inspect {key, value}}")
              end)
            _ ->
              :ets.insert(state.replicas, {key, new_replicas})
          end
        end, :dontCare, state.values)

      {:leave, pid, %{node: _node}} ->
        :ets.foldl(fn({key, value}, _) ->
          [{^key, replicas1}] = :ets.lookup(state.replicas, key)
          replicas = Enum.filter(replicas1, fn({_node, rpid}) -> rpid == pid end)
          unless Enum.empty?(replicas) do
            new_replicas = Dispatch.Registry.find_multi_service(2, "dht", key) 
            :ets.insert(state.replicas, {key, new_replicas})
            Enum.filter(new_replicas, fn({_node, rpid2}) -> rpid2 != pid and rpid2 != self() end)
            |> case do
              [{_new_node, rep_pid} | _] ->
                parent = self()
                Task.async(fn ->
                  Process.unlink(parent)
                  GenServer.call(rep_pid, {:set, key, value})
                  Logger.info("Failed over replica to #{inspect rep_pid} with #{inspect {key, value}}")
                end)
              _ -> true
            end
          end
        end, :dontCare, state.values)

      _ -> true
    end
    {:noreply, state}
  end
end