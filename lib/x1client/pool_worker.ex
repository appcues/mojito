defmodule X1Client.PoolWorker do
  use GenServer
  alias X1Client.Conn

  @type state :: map

  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  @initial_state %{
    conn: nil,
    request_opts: [],
    stats: %{
      requests: 0,
      requests_at_this_host: 0,
      reconnects: 0,
      errors: 0
    }
  }

  def init(args) do
    {:ok, %{@initial_state | request_opts: args[:request_opts] || []}}
  end

  @request_timeout Application.get_env(:x1client, :request_timeout, 5000)

  def handle_call({:request, method, url, headers, payload, opts}, _from, %{} = state) do
    timeout = opts[:timeout] || @request_timeout
    request_opts = Keyword.merge(state.request_opts, opts)

    response_task =
      fn ->
        with {:ok, state} <- connect(state, url),
             {:ok, conn} <- Conn.request(state.conn, method, url, headers, payload, request_opts) do
          Conn.stream_response(conn, opts)
        end
      end
      |> Task.async()

    response =
      Task.yield(response_task, timeout) || Task.shutdown(response_task) || {:error, :timeout}

    case response do
      nil ->
        {:reply, {:error, :timeout}, state |> add_request() |> add_error()}

      {:ok, {:ok, conn, response}} ->
        {:reply, {:ok, response}, %{state | conn: conn} |> add_request()}

      err ->
        {:reply, {:error, err}, state |> add_request() |> add_error()}
    end
  end

  ## `connect/2` ensures that `state.conn` is an open connection to the
  ## correct destination.

  @spec connect(state, String.t()) :: {:ok, state} | {:error, any}
  defp connect(state, url) do
    open = state.conn && Conn.open?(state.conn)
    matches_url = state.conn && Conn.matches?(state.conn, url)

    cond do
      open && matches_url ->
        {:ok, state}

      matches_url ->
        with {:ok, conn} <- Conn.connect(url) do
          {:ok, %{state | conn: conn} |> add_reconnect()}
        end

      :else ->
        # close socket cleanly
        if open, do: state.conn.conn.transport.close(state.conn.conn)

        with {:ok, conn} <- Conn.connect(url) do
          {:ok, %{state | conn: conn} |> clear_host() |> add_reconnect()}
        end
    end
  end

  defp add_request(state) do
    %{
      state
      | stats:
          Map.merge(state.stats, %{
            requests: state.stats.requests + 1,
            requests_at_this_host: state.stats.requests_at_this_host + 1
          })
    }
  end

  defp add_error(state) do
    %{
      state
      | stats:
          Map.merge(state.stats, %{
            errors: state.stats.errors + 1
          })
    }
  end

  defp add_reconnect(state) do
    %{
      state
      | stats:
          Map.merge(state.stats, %{
            reconnects: state.stats.reconnects + 1
          })
    }
  end

  defp clear_host(state) do
    %{state | stats: Map.put(state.stats, :requests_at_this_host, 0)}
  end
end
