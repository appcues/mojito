defmodule Mojito.Pool do
  @moduledoc ~S"""
  Mojito.Pool is an HTTP client with high-performance, easy-to-use
  connection pools.

  Pools are maintained automatically by Mojito, requests are matched to
  the correct pool without user intervention, and multiple pools can be
  used for the same destination in order to reduce concurrency bottlenecks.

  `Mojito.Pool.request/1` is intended for use through `Mojito.request/1`,
  but can also be used directly.

  Pool options can be specified by ...
  """

  alias Mojito.{Request, Utils}
  require Logger

  @doc ~S"""
  Performs an HTTP request using a connection pool, creating that pool if
  it didn't already exist.  Requests are always matched to a pool that is
  connected to the correct destination host and port.
  """
  @spec request(Mojito.request()) ::
          {:ok, Mojito.response()} | {:error, Mojito.error()}
  def request(%{} = request) do
    with {:ok, valid_request} <- Request.validate_request(request),
         {:ok, _proto, host, port} <- Utils.decompose_url(valid_request.url),
         pool_key <- pool_key(host, port),
         {:ok, pool} <- get_pool(pool_key) do
      Mojito.Pool.Single.request(pool, valid_request)
    end
  end

  @spec get_pool(any) :: {:ok, pid} | {:error, Mojito.error()}
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

  @spec start_pool(any) :: {:ok, pid} | {:error, Mojito.error()}
  defp start_pool(pool_key) do
    GenServer.call(Mojito.Pool.Manager, {:start_pool, pool_key})
  end

  @doc false
  def pool_key(host, port) do
    {host, port}
  end
end
