defmodule Mojito.Request.Single do
  ## Make a single request, without spawning any processes.

  @moduledoc false

  alias Mojito.{Config, Conn, Error, Request, Response}
  alias Mojito.Utils
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
    with {:ok, req} <- Request.validate_request(req),
         {:ok, conn} <- Conn.connect(req.url, req.opts),
         {:ok, conn, _ref} <- Conn.request(conn, req) do
      timeout = req.opts[:timeout] || Config.timeout()
      max_body_size = req.opts[:max_body_size]
      receive_response(conn, %Response{size: max_body_size}, timeout)
    end
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
        response = apply_resps(response, resps)

        case response do
          %{complete: true} ->
            {:ok, response}

          {:error, _} = err ->
            err

          _ ->
            receive_response(conn, response, new_timeout.())
        end

      {:error, _, e, _} ->
        {:error, %Error{reason: e}}

      :unknown ->
        receive_response(conn, response, new_timeout.())
    end
  end

  defp apply_resps(response, []), do: response

  defp apply_resps(response, [mint_resp | rest]) do
    apply_resp(response, mint_resp) |> apply_resps(rest)
  end

  defp apply_resp(response, {:status, _request_ref, status_code}) do
    %{response | status_code: status_code}
  end

  defp apply_resp(response, {:headers, _request_ref, headers}) do
    %{response | headers: headers}
  end

  defp apply_resp(response, {:data, _request_ref, chunk}) do
    {:ok, resp} = Utils.put_chunk(response, chunk)
    resp
  end

  defp apply_resp(response, {:done, _request_ref}) do
    %{response | complete: true, body: :erlang.iolist_to_binary(response.body)}
  end
end
