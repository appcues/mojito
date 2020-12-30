defmodule Mojito.Pool.Multi do
  @moduledoc ~S"""
  A connection pool with support for multiplexing (HTTP/2) and
  pipelining (HTTP/2).
  """

  alias Mojito.Config
  require Logger

  @opaque server_id :: {Mojito.ConnServer, Mojito.Pool.pool_key, non_neg_integer, non_neg_integer}

  use GenServer

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl GenServer
  def init(args) do
    init_ets_table(args)
    init_registry(args)
    {:ok, %{}}
  end

  @ets_table __MODULE__.ETS

  defp init_ets_table(_args) do
    :ets.new(@ets_table, [
      :named_table,
      :set,
      :public,
      {:read_concurrency, true},
      {:write_concurrency, true}
    ])
  end

  @registry __MODULE__.Registry

  defp init_registry(_args) do
    {:ok, _} =
      Registry.start_link(
        keys: :unique,
        name: @registry,
        partitions: System.schedulers_online()
      )
  end

  @behaviour Mojito.Pool

  @impl Mojito.Pool
  def request(request) do
    t_start = now()

    {:ok, _protocol, host, port} = Mojito.Utils.decompose_url(request.url)
    pool_key = {host, port}

    checkout_timeout =
      min(
        Config.config(pool_key, :checkout_timeout, request.opts),
        Config.config(pool_key, :timeout, request.opts)
      )

    give_up_at =
      case checkout_timeout do
        :infinity -> :infinity
        t -> t_start + t
      end

    case checkout_conn_server(pool_key, request.opts, give_up_at) do
      {:ok, conn_server, server_id, counter} ->
        try do
          case do_request(request, conn_server, t_start, pool_key) do
            {:ok, response} ->
              checkin_conn_server(counter)
              {:ok, response}

            {:error, :timeout} ->
              ## No need to recycle conn after a request timeout
              checkin_conn_server(counter)
              {:error, :timeout}

            error ->
              ## Replace conn on any non-timeout request error
              replace_conn_server(server_id, request.opts)
              error
          end
        rescue
          e ->
            Logger.debug(e)

            ## Replace conn on any non-timeout request error
            replace_conn_server(server_id, request.opts)
            {:error, e}
        end

      checkout_error ->
        checkout_error
    end
  end

  defp do_request(request, conn_server, t_start, pool_key) do
    response_ref = make_ref()
    checkout_time = now() - t_start

    ## Lots of gunk to figure out when to give up
    #
    overall_timeout = Config.config(pool_key, :timeout, request.opts)

    ## number of milliseconds, or :infinity
    remaining_overall_timeout =
      case overall_timeout do
        :infinity -> :infinity
        t -> t - checkout_time
      end

    ## number of milliseconds, or :infinity
    request_timeout =
      min(
        remaining_overall_timeout,
        Config.config(pool_key, :request_timeout, request.opts)
      )

    ## :erlang.monotonic_time value, or :infinity
    no_reply_after =
      case request_timeout do
        :infinity -> :infinity
        t -> now() + t
      end

    with :ok <-
           Mojito.ConnServer.request(
             conn_server,
             request,
             self(),
             response_ref,
             no_reply_after
           ) do
      receive do
        {:mojito_response, ^response_ref, response} ->
          Mojito.Utils.wrap_return_value(response)
      after
        request_timeout -> {:error, :timeout}
      end
    end
  end

  @retry_delay 5

  @spec checkout_conn_server(
          Mojito.Pool.pool_key(),
          Keyword.t(),
          non_neg_integer | :infinity
        ) ::
          {:ok, pid, server_id, :counters.t()} | {:error, any}
  defp checkout_conn_server(pool_key, opts, give_up_at) do
    if give_up_at < now() do
      {:error, :checkout_timeout}
    else
      checkout_retry_delay =
        Config.config(pool_key, :checkout_retry_delay, opts) || @retry_delay

      case get_conn_server(pool_key, opts) do
        {:error, :server_full} ->
          Process.sleep(checkout_retry_delay)
          checkout_conn_server(pool_key, opts, give_up_at)

        other ->
          other
      end
    end
  end

  @spec get_conn_server(Mojito.Pool.pool_key(), Keyword.t()) ::
          {:ok, pid, server_id, :counters.t()} | {:error, any}
  defp get_conn_server(pool_key, opts) do
    size = Config.config(pool_key, :size, opts)
    index = :random.uniform(size)

    server_id = {Mojito.ConnServer, pool_key, :erlang.system_info(:scheduler_id), index}
    server_id |> inspect |> Logger.debug

    {conn_server, counter} = get_or_create_conn_server(server_id, opts)

    ## Now we have a connection -- check whether it's overbooked
    max_multi = Config.config(pool_key, :multi, opts)

    count = :counters.get(counter, 1)
    Logger.debug("count #{count}")
    if max_multi > count do
      :counters.add(counter, 1, 1)
      {:ok, conn_server, server_id, counter}
    else
      {:error, :server_full}
    end
  end

  @spec get_or_create_conn_server(
          server_id,
          Keyword.t()
        ) :: {pid, :counters.t()}
  defp get_or_create_conn_server(server_id, opts) do
    case Registry.lookup(@registry, server_id) do
      [] -> replace_conn_server(server_id, opts)
      [pid_and_counter] -> pid_and_counter
    end
  end

  defp checkin_conn_server(counter) do
    :counters.sub(counter, 1, 1)
  end

  @spec replace_conn_server(server_id, Keyword.t) :: {pid, :counters.t()}
  defp replace_conn_server(server_id, opts) do
    Registry.unregister(@registry, server_id)

    counter = :counters.new(1, [:atomics])

    conn_server_opts =
      Keyword.merge(opts,
        registry: @registry,
        registry_key: server_id,
        registry_value: counter
      )

    ## Server will register itself
    {:ok, pid} = Mojito.ConnServer.start_link(conn_server_opts)

    {pid, counter}
  end

  defp now, do: :erlang.monotonic_time(:millisecond)
end
