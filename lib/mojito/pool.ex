defmodule Mojito.Pool do
  @moduledoc ~S"""
  Mojito.Pool is an HTTP client with high-performance, easy-to-use
  connection pools.

  Pools are maintained automatically by Mojito, requests are matched to
  the correct pool without user intervention, and multiple pools can be
  used for the same destination in order to reduce concurrency bottlenecks.

  `Mojito.Pool.request/1` is intended for use through `Mojito.request/1`,
  but can also be used directly.

  ## Configuration

  Pool options can be specified in your config file like this:

      use Mix.Config
      config :mojito, pool_opts: [ ... ]

  The available options are:

  * `:size` (integer) sets the number of steady-state connections per pool.
    Default is 5.
  * `:max_overflow` (integer) sets the number of additional connections
    per pool, opened under conditions of heavy load.
    Default is 10.
  * `:pools` (integer) sets the maximum number of pools to open for a
    single destination host and port (not the maximum number of total
    pools to open).  Default is 5.
  * `:strategy` is either `:lifo` or `:fifo`, and selects which connection
    should be checked out of a single pool.  Default is `:lifo`.
  * `:refractory_period` (integer, milliseconds) configures how long Mojito
    should wait after starting a pool before starting another one to the same
    destination.  Default 3000.
  * `:destinations` (keyword list of `t:pool_opts`) allows these parameters
    to be set for individual `:"host:port"` destinations.

  For example:

      use Mix.Config

      config :mojito, :pool_opts,
        size: 10,
        destinations: [
          "example.com:443": [
            size: 20,
            max_overflow: 20,
            pools: 10
          ]
        ]
  """

  alias Mojito.{Request, Utils}
  require Logger

  @type pool_opts :: [pool_opt | {:destinations, [pool_opt]}]

  @type pool_opt ::
          {:size, pos_integer}
          | {:max_overflow, non_neg_integer}
          | {:pools, pos_integer}
          | {:strategy, :lifo | :fifo}
          | {:refractory_period, non_neg_integer}

  @typep pool_key :: {String.t(), pos_integer}

  @default_pool_opts [
    size: 5,
    max_overflow: 10,
    pools: 5,
    strategy: :lifo,
    refractory_period: 3000
  ]

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
      do_request(pool, pool_key, valid_request)
    end
  end

  defp do_request(pool, pool_key, request) do
    case Mojito.Pool.Single.request(pool, request) do
      {:error, %{reason: :checkout_timeout}} ->
        {:ok, pid} = start_pool(pool_key)
        Mojito.Pool.Single.request(pid, request)

      other ->
        other
    end
  end

  ## Returns a pool for the given destination, starting one or more
  ## if necessary.
  @doc false
  @spec get_pool(any) :: {:ok, pid} | {:error, Mojito.error()}
  def get_pool(pool_key) do
    case get_pools(pool_key) do
      [] ->
        Logger.debug("Mojito.Pool: starting pools for #{inspect(pool_key)}")
        opts = pool_opts(pool_key)
        1..(opts[:pools]) |> Enum.each(fn _ -> start_pool(pool_key) end)
        get_pool(pool_key)

      pools ->
        {:ok, Enum.random(pools)}
    end
  end

  ## Returns all pools for the given destination.
  @doc false
  @spec get_pools(any) :: [pid]
  defp get_pools(pool_key) do
    Mojito.Pool.Registry
    |> Registry.lookup(pool_key)
    |> Enum.map(fn {_, pid} -> pid end)
  end

  ## Starts a new pool for the given destination.
  @doc false
  @spec start_pool(any) :: {:ok, pid} | {:error, Mojito.error()}
  def start_pool(pool_key) do
    GenServer.call(Mojito.Pool.Manager, {:start_pool, pool_key})
  end

  ## Returns a key representing the given destination.
  @doc false
  @spec pool_key(String.t(), pos_integer) :: pool_key
  def pool_key(host, port) do
    {host, port}
  end

  ## Returns the configured `t:pool_opts` for the given destination.
  @doc false
  @spec pool_opts(pool_key) :: pool_opts
  def pool_opts({host, port}) do
    destination_key =
      try do
        "#{host}:#{port}" |> String.to_existing_atom()
      rescue
        _ -> :none
      end

    config_pool_opts = Application.get_env(:mojito, :pool_opts, [])

    destination_pool_opts =
      config_pool_opts
      |> Keyword.get(:destinations, [])
      |> Keyword.get(destination_key, [])

    @default_pool_opts
    |> Keyword.merge(config_pool_opts)
    |> Keyword.merge(destination_pool_opts)
    |> Keyword.delete(:destinations)
  end
end
