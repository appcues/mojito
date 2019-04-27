defmodule Mojito.Pool do
  @moduledoc false

  alias Mojito.{Pool, Utils}
  require Logger

  def request(%{} = request) do
    with {:ok, _proto, host, port} <- Utils.decompose_url(request.url),
         {:ok, pool} <- get_pool(host, port) do
      Pool.Single.request(pool, request)
    end
  end

  defp get_pool(host, port) do
    pool_key = pool_key(host, port)

    case Registry.lookup(Pool.Registry, pool_key) do
      [{_, pid} | _] ->
        {:ok, pid}

      [] ->
        Logger.debug("Mojito.Autopool: starting pool for #{inspect(pool_key)}")
        start_pool(pool_key)
    end
  end

  defp start_pool(pool_key) do
    GenServer.call(Pool.Manager, {:start_pool, pool_key})
  end

  @doc false
  def pool_key(host, port) do
    {host, port}
  end
end
