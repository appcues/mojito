defmodule Mojito.Pool.Poolboy.Manager do
  ## I'd prefer to start new pools directly in the caller process, but
  ## they'd end up disappearing from the registry when the process
  ## terminates.  So instead we start new pools from here, a long-lived
  ## GenServer, and link them to Mojito.Supervisor instead of to here.

  @moduledoc false

  use GenServer
  alias Mojito.Telemetry

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(args) do
    {:ok, %{args: args, pools: %{}, last_start_at: %{}}}
  end

  defp time, do: System.monotonic_time(:millisecond)

  def handle_call({:start_pool, pool_key}, _from, state) do
    pool_opts = Mojito.Pool.pool_opts(pool_key)
    max_pools = pool_opts[:pools]

    pools = state.pools |> Map.get(pool_key, [])
    npools = Enum.count(pools)

    cond do
      npools >= max_pools ->
        ## We're at max, don't start a new pool
        {:reply, {:ok, Enum.random(pools)}, state}

      :else ->
        actually_start_pool(pool_key, pool_opts, pools, npools, state)
    end
  end

  def handle_call(:get_all_pool_states, _from, state) do
    all_pool_states =
      state.pools
      |> Enum.map(fn {pool_key, pools} ->
        {pool_key, pools |> Enum.map(&get_poolboy_state/1)}
      end)
      |> Enum.into(%{})

    {:reply, all_pool_states, state}
  end

  def handle_call({:get_pool_states, pool_key}, _from, state) do
    pools = state.pools |> Map.get(pool_key, [])
    pool_states = pools |> Enum.map(&get_poolboy_state/1)
    {:reply, pool_states, state}
  end

  def handle_call({:get_pools, pool_key}, _from, state) do
    {:reply, Map.get(state.pools, pool_key, []), state}
  end

  def handle_call(:state, _from, state) do
    {:reply, state, state}
  end

  defp get_poolboy_state(pool_pid) do
    {:state, supervisor, workers, waiting, monitors, size, overflow,
     max_overflow, strategy} = :sys.get_state(pool_pid)

    %{
      supervisor: supervisor,
      workers: workers,
      waiting: waiting,
      monitors: monitors,
      size: size,
      overflow: overflow,
      max_overflow: max_overflow,
      strategy: strategy
    }
  end

  ## This is designed to be able to launch pools on-demand, but for now we
  ## launch all pools at once in Mojito.Pool.
  defp actually_start_pool(pool_key, pool_opts, pools, npools, state) do
    {host, port} = pool_key
    meta = %{host: host, port: port}
    start = Telemetry.start(:pool, meta)

    pool_id = {Mojito.Pool, pool_key, npools}

    child_spec =
      pool_opts
      |> Keyword.put(:id, pool_id)
      |> Mojito.Pool.Poolboy.Single.child_spec()

    with {:ok, pool_pid} <-
           Supervisor.start_child(Mojito.Supervisor, child_spec),
         {:ok, _} <-
           Registry.register(Mojito.Pool.Poolboy.Registry, pool_key, pool_pid) do
      state =
        state
        |> put_in([:pools, pool_key], [pool_pid | pools])
        |> put_in([:last_start_at, pool_key], time())

      Telemetry.stop(:pool, start, meta)

      {:reply, {:ok, pool_pid}, state}
    else
      {:error, {msg, _pid}}
      when msg in [:already_started, :already_registered] ->
        ## There was a race; we lost and that is fine
        Telemetry.stop(:pool, start, meta)
        {:reply, {:ok, Enum.random(pools)}, state}

      error ->
        Telemetry.stop(:pool, start, meta)
        {:reply, error, state}
    end
  end
end
