defmodule Mojito.Autopool do
  @moduledoc false

  alias Mojito.{Autopool, Utils}
  require Logger

  def request(%{} = request) do
    with {:ok, proto, host, port} <- Utils.decompose_url(request.url),
         {:ok, pool} <- get_pool(proto, host, port) do
      Mojito.Pool.request(pool, request)
    end
  end

  defp get_pool(proto, host, port) do
    pool_id = {proto, host, port}

    case Registry.lookup(Autopool.Registry, pool_id) do
      [{_, pid} | _] ->
        {:ok, pid}

      [] ->
        Logger.debug("Mojito.Autopool: starting pool for #{inspect(pool_id)}")
        start_pool(pool_id)
    end
  end

  defp start_pool({proto, host, port}) do
    GenServer.call(Mojito.Autopool.Manager, {:start_pool, proto, host, port})
  end
end

defmodule Mojito.Autopool.Manager do
  use GenServer

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(args) do
    {:ok, %{args: args}}
  end

  def handle_call({:start_pool, proto, host, port}, _from, state) do
    child_spec = Mojito.Pool.child_spec()

    reply =
      with {:ok, pool_pid} <-
             Supervisor.start_child(Mojito.Supervisor, child_spec),
           {:ok, _} <-
             Registry.register(
               Mojito.Autopool.Registry,
               {proto, host, port},
               pool_pid
             ) do
        {:ok, pool_pid}
      end

    {:reply, reply, state}
  end
end
