defmodule Mojito.Pool.Manager do
  ## I'd prefer to start new pools directly in the caller process, but
  ## they'd end up disappearing from the registry when the process
  ## terminates.  So instead we start new pools from here, a long-lived
  ## GenServer, and link them to Mojito.Supervisor instead of to here.

  @moduledoc false

  use GenServer

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(args) do
    {:ok, %{args: args, pools: %{}, last_start_at: %{}}}
  end

  defp time, do: System.monotonic_time(:millisecond)

  @refractory_period 3000

  def handle_call({:start_pool, pool_key}, _from, state) do
    pool_opts = Mojito.Pool.pool_opts(pool_key)
    max_pools = pool_opts[:max_pools]

    pools = state.pools |> Map.get(pool_key, [])
    npools = Enum.count(pools)

    time_now = time()
    last_start_at = state.last_start_at |> Map.get(pool_key)

    cond do
      npools >= max_pools ->
        ## We're at max, don't start a new pool
        {:reply, {:ok, Enum.random(pools)}, state}

      last_start_at && time_now < last_start_at + @refractory_period ->
        ## Wait longer before starting a new pool
        {:reply, {:ok, Enum.random(pools)}, state}

      :else ->
        ## Actually start a pool
        pool_id = {Mojito.Pool, pool_key, npools}

        child_spec =
          pool_opts
          |> Keyword.put(:id, pool_id)
          |> Mojito.Pool.Single.child_spec()

        with {:ok, pool_pid} <-
               Supervisor.start_child(Mojito.Supervisor, child_spec),
             {:ok, _} <-
               Registry.register(Mojito.Pool.Registry, pool_key, pool_pid) do
          state =
            state
            |> put_in([:pools, pool_key], [pool_pid | pools])
            |> put_in([:last_start_at, pool_key], time_now)
          {:reply, {:ok, pool_pid}, state}
        else
          {:error, {msg, _pid}}
          when msg in [:already_started, :already_registered] ->
            ## There was a race; we lost and that is fine
            {:reply, {:ok, Enum.random(pools)}, state}
        end
    end
  end

  def handle_call({:get_pools, pool_key}, _from, state) do
    {:reply, Map.get(state.pools, pool_key, []), state}
  end

  def handle_call(:state, _from, state) do
    {:reply, state, state}
  end
end
