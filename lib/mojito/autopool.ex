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
    pool_key = {proto, host, port}

    case Registry.lookup(Autopool.Registry, pool_key) do
      [{_, pid} | _] ->
        {:ok, pid}

      [] ->
        Logger.debug("Mojito.Autopool: starting pool for #{inspect(pool_key)}")
        start_pool(pool_key)
    end
  end

  defp start_pool(pool_key) do
    GenServer.call(Mojito.Autopool.Manager, {:start_pool, pool_key})
  end
end
