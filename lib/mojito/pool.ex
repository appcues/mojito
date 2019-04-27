defmodule Mojito.Pool do
  @moduledoc ~S"""
  Mojito.Pool provides an HTTP request connection pool based on
  Mojito and Poolboy.

  Example:

      >>>> children = [Mojito.Pool.child_spec(MyPool)]
      >>>> {:ok, _pid} = Supervisor.start_link(children, strategy: :one_for_one)
      >>>> Mojito.Pool.request(MyPool, :get, "http://example.com")
      {:ok, %Mojito.Response{...}}
  """

  alias Mojito.{Config, Utils}

  @doc false
  @deprecated "Use child_spec/1 instead"
  def child_spec(name, opts) do
    opts
    |> Keyword.put(:name, name)
    |> child_spec
  end

  @doc ~S"""
  Returns a child spec suitable to pass to e.g., `Supervisor.start_link/2`.

  Options:

  * `:name` sets a global name for the pool.  Optional.
  * `:size` sets the initial pool size.  Default is 10.
  * `:max_overflow` sets the maximum number of additional connections
    under high load.  Default is 5.
  * `:strategy` sets the pool connection-grabbing strategy. Valid values
    are `:fifo` and `:lifo` (default).

  The `:size` and `:max_overflow` options are passed to Poolboy.
  """
  def child_spec(opts \\ [])

  def child_spec(name) when is_binary(name) do
    child_spec(name: name)
  end

  def child_spec(opts) do
    pool_opts = Config.pool_opts()
    name = opts[:name]
    size = opts[:size] || pool_opts[:size] || 10
    max_overflow = opts[:max_overflow] || pool_opts[:max_overflow] || 5
    strategy = opts[:strategy] || pool_opts[:strategy] || :lifo

    poolboy_config =
      [
        {:worker_module, Mojito.ConnServer},
        {:size, size},
        {:max_overflow, max_overflow},
        {:strategy, strategy},
      ] ++ if name, do: [{:name, {:local, name}}], else: []

    :poolboy.child_spec(name, poolboy_config)
  end

  @doc ~S"""
  Makes an HTTP request using the given connection pool.

  See `request/2` for documentation.
  """
  @spec request(
          pid,
          Mojito.method(),
          String.t(),
          Mojito.headers(),
          String.t(),
          Keyword.t()
        ) :: {:ok, Mojito.response()} | {:error, Mojito.error()}
  def request(pool, method, url, headers \\ [], payload \\ "", opts \\ []) do
    req = %Mojito.Request{
      method: method,
      url: url,
      headers: headers,
      payload: payload,
      opts: opts,
    }

    request(pool, req)
  end

  @doc ~S"""
  Makes an HTTP request using the given connection pool.

  Options:

  * `:timeout` - Response timeout in milliseconds.  Defaults to
    `Application.get_env(:mojito, :request_timeout, 5000)`.
  * `:transport_opts` - Options to be passed to either `:gen_tcp` or `:ssl`.
    Most commonly used to perform insecure HTTPS requests via
    `transport_opts: [verify: :verify_none]`.
  """
  @spec request(pid, Mojito.request()) ::
          {:ok, Mojito.response()} | {:error, Mojito.error()}
  def request(pool, request) do
    with {:ok, valid_request} <- Mojito.Request.validate_request(request) do
      do_request(pool, valid_request)
    end
  end

  defp do_request(pool, request) do
    timeout = request.opts[:timeout] || Config.request_timeout()

    start_time = time()

    worker_fn = fn worker ->
      case Mojito.ConnServer.request(
             worker,
             self(),
             request.method,
             request.url,
             request.headers,
             request.payload,
             request.opts
           ) do
        :ok ->
          new_timeout = timeout - (time() - start_time)

          receive do
            {:mojito_response, response} -> response
          after
            new_timeout -> {:error, :timeout}
          end

        e ->
          e
      end
    end

    old_trap_exit = Process.flag(:trap_exit, true)

    try do
      :poolboy.transaction(pool, worker_fn, timeout)
    rescue
      e -> {:error, e}
    catch
      :exit, _ -> {:error, :checkout_timeout}
    after
      Process.flag(:trap_exit, old_trap_exit)
    end
    |> Utils.wrap_return_value()
  end

  defp time, do: System.monotonic_time(:millisecond)
end
