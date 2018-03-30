defmodule XClient.Pool do
  @moduledoc ~S"""
  XClient.Pool provides an HTTP 1.x request connection pool based on
  XClient and Poolboy.

  Example:

      >>>> children = [XClient.Pool.child_spec(MyPool)]
      >>>> {:ok, _pid} = Supervisor.start_link(children, strategy: :one_for_one)
      >>>> XClient.Pool.request(MyPool, :get, "http://example.com")
      {:ok, %XClient.Response{...}}
  """

  alias XClient.{Error, Response, Utils}

  defp pool_opts, do: Application.get_env(:xclient, :pool_opts, [])

  @doc ~S"""
  Returns a child spec suitable to pass to e.g., `Supervisor.start_link/2`.

  Options:

  * `:size` sets the initial pool size.  Default is 10.
  * `:max_overflow` sets the maximum number of additional connections
    under high load.  Default is 5.
  * `:strategy` sets the pool connection-grabbing strategy. Valid values
    are `:fifo` and `:lifo` (default).

  The `:size` and `:max_overflow` options are passed to Poolboy.
  """
  def child_spec(name, opts \\ []) do
    size = opts[:size] || pool_opts()[:size] || 10
    max_overflow = opts[:max_overflow] || pool_opts()[:max_overflow] || 5
    strategy = opts[:strategy] || pool_opts()[:strategy] || :lifo

    poolboy_config = [
      {:name, {:local, name}},
      {:worker_module, XClient.ConnServer},
      {:size, size},
      {:max_overflow, max_overflow},
      {:strategy, strategy}
    ]

    :poolboy.child_spec(name, poolboy_config)
  end

  @request_timeout Application.get_env(:xclient, :request_timeout, 5000)

  @doc ~S"""
  Makes an HTTP 1.x request using an existing connection pool.

  Options:

  * `timeout` - Response timeout in milliseconds.  Defaults to
    `Application.get_env(:xclient, :request_timeout, 5000)`.
  """
  @spec request(pid, XClient.method(), String.t(), XClient.headers(), String.t(), Keyword.t()) ::
          {:ok, XClient.response()} | {:error, XClient.error()}
  def request(pool, method, url, headers \\ [], payload \\ "", opts \\ []) do
    timeout = opts[:timeout] || @request_timeout

    worker_fn = fn worker ->
      case XClient.ConnServer.request(worker, self(), method, url, headers, payload, opts) do
        :ok ->
          receive do
            response -> response
          after
            timeout -> {:error, :timeout}
          end

        err ->
          err
      end
    end

    task =
      fn -> :poolboy.transaction(pool, worker_fn) end
      |> Task.async()

    case Task.yield(task, timeout) || Task.shutdown(task) do
      nil -> {:error, :timeout}
      {:ok, reply} -> reply
    end
    |> Utils.wrap_return_value()
  end
end
