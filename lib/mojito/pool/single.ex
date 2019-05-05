defmodule Mojito.Pool.Single do
  @moduledoc ~S"""
  Mojito.Pool.Single provides an HTTP request connection pool based on
  Mojito and Poolboy.  It is intended for use through `Mojito.Pool`.

  Example:

      >>>> children = [Mojito.Pool.Single.child_spec()]
      >>>> {:ok, pool_pid} = Supervisor.start_link(children, strategy: :one_for_one)
      >>>> Mojito.Pool.Single.request(pool_pid, :get, "http://example.com")
      {:ok, %Mojito.Response{...}}
  """

  alias Mojito.{Config, ConnServer, Request, Utils}

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
  """
  def child_spec(opts \\ [])

  def child_spec(name) when is_binary(name) do
    child_spec(name: name)
  end

  def child_spec(opts) do
    name = opts[:name]

    name_opts =
      case name do
        nil -> []
        name -> [name: name]
      end

    poolboy_opts = [{:worker_module, Mojito.ConnServer} | opts]

    poolboy_opts =
      case name do
        nil -> poolboy_opts
        name -> [{:name, {:local, name}} | poolboy_opts]
      end

    %{
      id: opts[:id] || {Mojito.Pool, make_ref()},
      start: {:poolboy, :start_link, [poolboy_opts, name_opts]},
      restart: :permanent,
      shutdown: 5000,
      type: :worker,
    }
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
  def request(pool, method, url, headers \\ [], body \\ "", opts \\ []) do
    req = %Request{
      method: method,
      url: url,
      headers: headers,
      body: body,
      opts: opts,
    }

    request(pool, req)
  end

  @doc ~S"""
  Makes an HTTP request using the given connection pool.

  Options:

  * `:timeout` - Request timeout in milliseconds.  Defaults to
    `Application.get_env(:mojito, :request_timeout, 5000)`.
  * `:transport_opts` - Options to be passed to either `:gen_tcp` or `:ssl`.
    Most commonly used to perform insecure HTTPS requests via
    `transport_opts: [verify: :verify_none]`.
  """
  @spec request(pid, Mojito.request()) ::
          {:ok, Mojito.response()} | {:error, Mojito.error()}
  def request(pool, request) do
    with {:ok, valid_request} <- Request.validate_request(request) do
      do_request(pool, valid_request)
    end
  end

  defp do_request(pool, request) do
    timeout = request.opts[:timeout] || Config.request_timeout()

    start_time = time()

    worker_fn = fn worker ->
      case ConnServer.request(
             worker,
             self(),
             request.method,
             request.url,
             request.headers,
             request.body,
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
