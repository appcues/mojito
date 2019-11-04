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

  alias Mojito.{ConnServer, Request, Utils}
  import Mojito.Config
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
         {:ok, _proto, host, port} <- Utils.decompose_url(valid_request.url) do
      timeout = config(:timeout, request.opts, host, port)
      checkout_timeout = config(:checkout_timeout, request.opts, host, port)
      request_timeout = config(:request_timeout, request.opts, host, port)
      pool_size = config(:pool_size, request.opts, host, port)
      pool_count = config(:pool_count, request.opts, host, port)
      pool_name = get_pool_name(host, port, pool_count)

      lock_opts = [
        size: pool_size,
        resource: {Mojito.ConnServer, []},
        timeout: timeout,
        wait_timeout: checkout_timeout,
        fun_timeout: request_timeout,
      ]

      case Lockring.with_lock(pool_name, &do_request(&1, request), lock_opts) do
        {:ok, return} ->
          return

        {:error, "wait_timeout reached"} ->
          {:error, %Mojito.Error{reason: :timeout}}

        {:error, "fun_timeout reached"} ->
          {:error, %Mojito.Error{reason: :timeout}}

        {:error, reason} ->
          {:error, %Mojito.Error{reason: to_string(reason)}}
      end
    end
  end

  defp do_request(conn_server, request) do
    response_ref = make_ref()

    case ConnServer.request(conn_server, request, self(), response_ref) do
      :ok ->
        receive do
          {:mojito_response, ^response_ref, response} -> response
        end

      error ->
        error
    end
  end

  defp get_pool_name(host, port, pool_count) do
    pool = pool_count |> :math.floor() |> round()
    {Mojito.Pool, host, port, pool}
  end
end
