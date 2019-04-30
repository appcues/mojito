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
    {:ok, %{args: args, pools: %{}}}
  end

  def handle_call({:start_pool, pool_key}, _from, state) do
    pools = state.pools |> Map.get(pool_key, [])

    child_spec =
      Mojito.Config.pool_opts(pool_key)
      |> Keyword.put(:id, {Mojito.Pool, pool_key, Enum.count(pools)})
      |> Mojito.Pool.Single.child_spec()

    reply =
      with {:ok, pool_pid} <-
             Supervisor.start_child(Mojito.Supervisor, child_spec),
           {:ok, _} <-
             Registry.register(
               Mojito.Pool.Registry,
               pool_key,
               pool_pid
             ) do
        {:ok, pool_pid}
      else
        {:error, {msg, pid}}
        when msg in [:already_started, :already_registered] ->
          ## There was a race; we lost and that is fine
          {:ok, pid}
      end

    state =
      case reply do
        {:ok, pool_pid} -> put_in(state, [:pools, pool_key], [pool_pid | pools])
        _ -> state
      end

    {:reply, reply, state}
  end

  def handle_call({:get_pools, pool_key}, _from, state) do
    {:reply, Map.get(state.pools, pool_key, []), state}
  end
end
