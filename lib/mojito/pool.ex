defmodule Mojito.Pool do
  @moduledoc false

  alias Mojito.{Pool, Utils}
  require Logger

  @spec request(Mojito.request) :: {:ok, Mojito.response} | {:error, Mojito.error}
  def request(%{} = request) do
    with {:ok, _proto, host, port} <- Utils.decompose_url(request.url),
         pool_key <- pool_key(host, port),
         {:ok, pool} <- get_pool(pool_key) do
      Pool.Single.request(pool, request)
    end
  end

  @spec get_pool(any) :: {:ok, pid} | {:error, Mojito.error}
  defp get_pool(pool_key) do
    case get_pools(pool_key) do
      [] ->
        Logger.debug("Mojito.Pool: starting pool for #{inspect(pool_key)}")
        start_pool(pool_key)

      pools ->
        {:ok, Enum.random(pools)}
    end
  end

  @spec get_pools(any) :: [pid]
  defp get_pools(pool_key) do
    Mojito.Pool.Registry
    |> Registry.lookup(pool_key)
    |> Enum.map(fn {_, pid} -> pid end)
  end

  defp start_pool(pool_key) do
    GenServer.call(Pool.Manager, {:start_pool, pool_key})
  end

  @doc false
  def pool_key(host, port) do
    {host, port}
  end
end
