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
    {:ok, %{args: args}}
  end

  ## pool_key is {protocol, host, port}
  def handle_call({:start_pool, pool_key}, _from, state) do
    child_spec =
      Mojito.Config.pool_opts(pool_key) |> Mojito.Pool.Single.child_spec()

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
      end

    {:reply, reply, state}
  end
end
