defmodule Mojito.Request.Single do
  ## Make a single request, without spawning any processes.

  @moduledoc false

  alias Mojito.{Config, Conn, Error, Request, Response}
  require Logger

  @doc ~S"""
  Performs a single HTTP request, receiving `:tcp` and `:ssl` messages
  in the caller process.

  Options:

  * `:timeout` - Response timeout in milliseconds.  Defaults to
    `Application.get_env(:mojito, :timeout, 5000)`.
  * `:max_body_size` - Max body size in bytes. Defaults to nil in which
    case no max size will be enforced.
  * `:transport_opts` - Options to be passed to either `:gen_tcp` or `:ssl`.
    Most commonly used to perform insecure HTTPS requests via
    `transport_opts: [verify: :verify_none]`.
  """
  @spec request(Mojito.request()) ::
          {:ok, Mojito.response()} | {:error, Mojito.error()}
  def request(%Request{} = req) do
    with_connection(req, fn conn ->
      with {:ok, conn, _ref, response} <- Conn.request(conn, req) do
        timeout = req.opts[:timeout] || Config.timeout()
        receive_response(conn, response, timeout)
      end
    end)
  end

  defp time, do: System.monotonic_time(:millisecond)

  @doc false
  def receive_response(conn, response, timeout) do
    start_time = time()

    receive do
      {:tcp, _, _} = msg ->
        handle_msg(conn, response, timeout, msg, start_time)

      {:tcp_closed, _} = msg ->
        handle_msg(conn, response, timeout, msg, start_time)

      {:ssl, _, _} = msg ->
        handle_msg(conn, response, timeout, msg, start_time)

      {:ssl_closed, _} = msg ->
        handle_msg(conn, response, timeout, msg, start_time)
    after
      timeout -> {:error, %Error{reason: :timeout}}
    end
  end

  defp handle_msg(conn, response, timeout, msg, start_time) do
    new_timeout = fn ->
      case timeout do
        :infinity ->
          :infinity

        _ ->
          time_elapsed = time() - start_time

          case timeout - time_elapsed do
            x when x < 0 -> 0
            x -> x
          end
      end
    end

    case Mint.HTTP.stream(conn.conn, msg) do
      {:ok, mint_conn, resps} ->
        conn = %{conn | conn: mint_conn}

        case Response.apply_resps(response, resps) do
          {:ok, %{complete: true} = response} -> {:ok, response}
          {:ok, response} -> receive_response(conn, response, new_timeout.())
          err -> err
        end

      {:error, _, e, _} ->
        {:error, %Error{reason: e}}

      :unknown ->
        receive_response(conn, response, new_timeout.())
    end
  end

  defp with_connection(req, fun) do
    with {:ok, req} <- Request.validate_request(req),
         {:ok, conn} <- Conn.connect(req.url, req.opts) do
      try do
        fun.(conn)
      after
        Conn.close(conn)
      end
    end
  end
end
