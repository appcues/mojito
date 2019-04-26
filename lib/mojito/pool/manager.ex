defmodule Mojito.Autopool.Manager do
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
    child_spec = Mojito.Pool.child_spec()

    reply =
      with {:ok, pool_pid} <-
             Supervisor.start_child(Mojito.Supervisor, child_spec),
           {:ok, _} <-
             Registry.register(
               Mojito.Autopool.Registry,
               pool_key,
               pool_pid
             ) do
        {:ok, pool_pid}
      end

    {:reply, reply, state}
  end
end
