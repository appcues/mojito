defmodule X1Client.PoolWorker do
  use GenServer
  alias X1Client.Conn

  @type state :: %{}

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

  ## `connect/2` ensures that `state.conn` is an open connection to the
  ## correct destination.

  @spec connect(state, String.t) :: {:ok, state} | {:error, any}
  defp connect(state, url) do
    open = state.conn && Conn.open?(state.conn)
    matches_url = state.conn && Conn.matches?(state.conn, url)

    cond do
      open && matches_url ->
        {:ok, state}

      matches_url ->
        with {:ok, conn} <- Conn.connect(url) do
          {:ok,
           %{
             state
             | conn: conn,
               stats:
                 Map.merge(state.stats, %{
                   reconnects: state.stats.reconnects + 1
                 })
           }}
        end

      :else ->
        # close socket cleanly
        if open, do: state.conn.conn.transport.close(state.conn.conn)

        with {:ok, conn} <- Conn.connect(url) do
          {:ok,
           %{
             state
             | conn: conn,
               stats:
                 Map.merge(state.stats, %{
                   reconnects: state.stats.reconnects + 1,
                   requests_at_this_host: 0
                 })
           }}
        end
    end
  end

  @request_timeout Application.get_env(:x1client, :request_timeout, 5000)

  def handle_call({:request, method, url, headers, payload, opts}, _from, state) do
    timeout = opts[:timeout] || @request_timeout

    response_task =
      fn ->
        with {:ok, state} <- connect(state, url),
             {:ok, conn} <- Conn.request(state.conn, method, url, headers, payload, opts) do
          Conn.stream_response(conn, opts)
        end
      end
      |> Task.async()

    response =
      Task.yield(response_task, timeout) ||
      Task.shutdown(response_task) ||
      {:error, :timeout}

    case response do
      {:ok, conn, response} ->
          {
            :reply,
            {:ok, response},
            %{
              state
              | conn: conn,
                stats:
                  Map.merge(state.stats, %{
                    requests: state.stats.requests + 1,
                    requests_at_this_host: state.stats.requests_at_this_host + 1
                  })
            }
          }
      err ->
        {
          :reply,
          err,
          %{
            state
            | stats:
                Map.merge(state.stats, %{
                  errors: state.stats.errors + 1,
                  requests: state.stats.requests + 1,
                  requests_at_this_host: state.stats.requests_at_this_host + 1
                })
          }
        }
    end
  end
end
