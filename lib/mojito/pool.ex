defmodule Mojito.Pool do
  @moduledoc false

  ## Mojito.Pool is an HTTP client with high-performance, easy-to-use
  ## connection pools.
  ##
  ## Pools are maintained automatically by Mojito, requests are matched to
  ## the correct pool without user intervention, and multiple pools can be
  ## used for the same destination in order to reduce concurrency bottlenecks.
  ##
  ## `Mojito.Pool.request/1` is intended for use through `Mojito.request/1`.
  ## Config parameters are explained in the `Mojito` moduledocs.

  alias Mojito.{Config, Request, Utils}
  require Logger

  @type pool_opts :: [pool_opt | {:destinations, [pool_opt]}]

  @type pool_opt ::
          {:size, pos_integer}
          | {:pools, pos_integer}
          | {:max_pipeline, pos_integer}

  @type destination_key :: :atom
  @type pool_index :: pos_integer
  @type pool_name :: {destination_key, pool_index}

  @type pool :: %{
          name: pool_name,
          size: pos_integer,
          max_pipeline: pos_integer,
          pipeline: :counters.counters_ref(),
          response_2xx: :counters.counters_ref(),
          response_4xx: :counters.counters_ref(),
          response_5xx: :counters.counters_ref(),
        }

  @default_pool_opts [
    size: 8,
    pools: 4,
    max_pipeline: 16,
  ]

  @doc ~S"""
  Performs an HTTP request using a connection pool, creating that pool if
  it didn't already exist.  Requests are always matched to a pool that is
  connected to the correct destination host and port.
  """
  @spec request(Mojito.request()) ::
          {:ok, Mojito.response()} | {:error, Mojito.error()}
  def request(%{} = request) do
    timeout = request.opts[:timeout] || Mojito.Config.timeout()

    with {:ok, valid_request} <- Request.validate_request(request),
         {:ok, destination_key} <- destination_key(valid_request.url),
         {:ok, pool} <- get_pool(destination_key),
         {:ok, worker, timeout_left} <- get_worker(pool, time(), timeout),
         :ok <- Mojito.ConnServer.request(worker, self(), valid_request) do
      receive do
        {:mojito_response, response} -> response
      after
        timeout_left -> {:error, :timeout}
      end
    end
    |> Utils.wrap_return_value()
  end

  defp destination_key(url) do
    with {:ok, _proto, host, port} <- Utils.decompose_url(url) do
      {:ok, :"#{host}:#{port}"}
    end
  end

  defp time, do: :erlang.monotonic_time(:millisecond)

  defp get_worker(pool, time_started, timeout) do
    index = :random.uniform(pool.size)
    worker_name = {Mojito.Pool, pool.name, index}
    current_pipeline = :counters.get(pool.pipeline, index)

    cond do
      time_started + timeout < time() ->
        {:error, :checkout_timeout}

      current_pipeline > pool.max_pipeline ->
        get_worker(pool, time_started, timeout)

      :else ->
        case Registry.lookup(Mojito.Pool.Registry, worker_name) do
          [{_, worker_pid}] ->
            {:ok, worker_pid, timeout - (time() - time_started)}

          [] ->
            ## Transient error due to recent worker death; retry
            get_worker(pool, time_started, timeout)

          _ ->
            ## This should not happen
            {:error, :too_many_workers}
        end
    end
  end

  ## Returns a pool for the given destination, starting one or more
  ## if necessary.
  @doc false
  @spec get_pool(any) :: {:ok, pid} | {:error, Mojito.error()}
  def get_pool(destination_key) do
    case get_pools(destination_key) do
      [] ->
        Logger.debug("Mojito.Pool: starting pools for #{destination_key}")
        opts = pool_opts(destination_key)

        pools =
          1..opts[:pools]
          |> Enum.map(fn i ->
            {:ok, pool} = start_pool({destination_key, i}, opts)
            pool
          end)

        :ok = :persistent_term.put({Mojito.Pool, destination_key}, pools)
        get_pool(destination_key)

      pools ->
        {:ok, Enum.random(pools)}
    end
  end

  ## Returns all pools for the given destination.
  @doc false
  @spec get_pools(any) :: [pool]
  defp get_pools(destination_key) do
    :persistent_term.get({Mojito.Pool, destination_key}, [])
  end

  ## Starts a new pool for the given destination.
  @doc false
  @spec start_pool(destination_key, pool_opts) ::
          {:ok, pid} | {:error, Mojito.error()}
  def start_pool({destination_key, _} = pool_name, pool_opts) do
    old_trap_exit = Process.flag(:trap_exit, true)

    try do
      {:ok, pool} =
        GenServer.call(
          Mojito.Pool.Manager,
          {:start_pool, pool_name, pool_opts[:size], pool_opts[:max_pipeline]},
          Config.timeout()
        )
    rescue
      e -> {:error, e}
    catch
      :exit, _ -> {:error, :checkout_timeout}
    after
      Process.flag(:trap_exit, old_trap_exit)
    end
    |> Utils.wrap_return_value()
  end

  ## Returns the configured `t:pool_opts` for the given destination.
  @doc false
  @spec pool_opts(destination_key) :: Mojito.pool_opts()
  def pool_opts(destination_key) do
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
