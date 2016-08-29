defmodule Dht.Service do
  use GenServer
  alias Dispatch.Service
  require Logger

  def start_link() do
    GenServer.start_link(__MODULE__, [type: :dht])
  end

  def init(opts) do
    :ok = Service.init(opts)
    values = :ets.new(:values, [:set])
    {:ok, %{values: values}}
  end

  def set(key, value) do
    res = Service.multi_call(2, :dht, key, {:set, key, value})    
    res |> Enum.map(&elem(&1, 1)) |> Enum.any?()
  end

  def get_values(key, default \\ nil) do
    res = Service.multi_call(2, :dht, key, {:get, key})
    Enum.filter_map(res, &(elem(&1, 0) == :ok), &extract_value(&1, default))
  end

  defp extract_value({_status, _pid, [{_key, value}]}, _default), do: value
  defp extract_value(_, default), do: default

  def get(key, default \\ nil) do
    res = Service.multi_call(2, :dht, key, {:get, key})
    resolve_conflicts(key, res, default)
  end

  defp resolve_conflicts(key, res, default) do
    {value, pids} = Enum.reduce(res, {default, []}, fn 
      ({:ok, pid, []}, {current, pids}) ->
        {current, [pid | pids]}
      ({:ok, pid, [{^key, val}]}, {current, pids}) ->
        if val != default, do: {val, pids}, else: {current, [pid | pids]}
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
    res = :ets.insert(state.values, {key, val})
    Logger.info("Set #{inspect {key, val}}")
    {:reply, res, state}
  end

  def handle_call({:get, key}, _from, state) do
    res = :ets.lookup(state.values, key)
    Logger.info("Get #{inspect res}")
    {:reply, res, state}
  end
end