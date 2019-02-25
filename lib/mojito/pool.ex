defmodule Mojito.Pool do
  @moduledoc ~S"""
  Mojito.Pool provides an HTTP 1.x request connection pool based on
  Mojito and Poolboy.

  Example:

      >>>> children = [Mojito.Pool.child_spec(MyPool)]
      >>>> {:ok, _pid} = Supervisor.start_link(children, strategy: :one_for_one)
      >>>> Mojito.Pool.request(MyPool, :get, "http://example.com")
      {:ok, %Mojito.Response{...}}
  """

  alias Mojito.Utils

  defp pool_opts, do: Application.get_env(:mojito, :pool_opts, [])

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
      {:worker_module, Mojito.ConnServer},
      {:size, size},
      {:max_overflow, max_overflow},
      {:strategy, strategy}
    ]

    :poolboy.child_spec(name, poolboy_config)
  end

  @request_timeout Application.get_env(:mojito, :request_timeout, 5000)

  @doc ~S"""
  Makes an HTTP 1.x request using an existing connection pool.

  Options:

  * `:timeout` - Response timeout in milliseconds.  Defaults to
    `Application.get_env(:mojito, :request_timeout, 5000)`.
  """
  @spec request(pid, Mojito.method(), String.t(), Mojito.headers(), String.t(), Keyword.t()) ::
          {:ok, Mojito.response()} | {:error, Mojito.error()}
  def request(pool, method, url, headers \\ [], payload \\ "", opts \\ []) do
    timeout = opts[:timeout] || @request_timeout

    worker_fn = fn worker ->
      case Mojito.ConnServer.request(worker, self(), method, url, headers, payload, opts) do
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
