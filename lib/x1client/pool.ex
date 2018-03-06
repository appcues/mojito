defmodule X1Client.Pool do
  @moduledoc ~S"""
  X1Client.Pool provides an HTTP 1.x request connection pool based on
  X1Client and Poolboy.

  Example:

      >>>> children = [X1Client.Pool.child_spec(MyPool)]
      >>>> Supervisor.start_link(children, strategy: :one_for_one)
      >>>> X1Client.Pool.request(MyPool, :get, "http://example.com")
      {:ok, %X1Client.Response{...}}
  """

  defp pool_config, do: Application.get_env(:x1client, :pool, [])

  @doc ~S"""
  Returns a child spec suitable to pass to e.g., `Supervisor.start_link/2`.
  The `:size` and `:max_overflow` options are passed to Poolboy.
  """
  def child_spec(name, opts \\ []) do
    size = opts[:size] || pool_config()[:size] || 10
    max_overflow = opts[:max_overflow] || pool_config()[:max_overflow] || 5

    poolboy_config = [
      {:name, {:local, name}},
      {:worker_module, X1Client.PoolWorker},
      {:size, size},
      {:max_overflow, 50}
    ]

    :poolboy.child_spec(name, poolboy_config)
  end

  @doc ~S"""
  Makes an HTTP 1.x request using an existing connection pool.
  """
  def request(pool, method, url, headers \\ [], payload \\ "", opts \\ []) do
    :poolboy.transaction(pool, fn worker ->
      GenServer.call(worker, {:request, method, url, headers, payload, opts})
    end)
  end
end
