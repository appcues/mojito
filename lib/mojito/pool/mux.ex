defmodule Mojito.Pool.Mux do
  @moduledoc false
  @behaviour Mojito.Pool

  alias Mojito.{Config, Request, Utils}
  require Logger

  @impl Mojito.Pool
  def request(request) do
    with {:ok, valid_request} <- Request.validate_request(request),
         timeout <- get_timeout(valid_request),
         {:ok, _proto, host, port} <- Utils.decompose_url(valid_request.url),
         conn_server <- get_conn_server(host, port),
         response_ref <- make_ref(),
         :ok <-
           Mojito.ConnServer.request(conn_server, valid_request, self(), response_ref) do
      receive do
        {:mojito_response, ^response_ref, response} -> {:ok, response}
      after
        timeout -> {:error, :timeout}
      end
    end
  end

  defp get_timeout(request) do
    request.opts[:timeout] || Config.timeout()
  end

  ## Returns the Mojito.ConnServer pid for the given {host, port, scheduler_id},
  ## launching one if necessary.
  defp get_conn_server(host, port) do
    scheduler_id = :erlang.system_info(:scheduler_id)
    conn_id = {Mojito.Pool.Mux, host, port, scheduler_id}

    case Registry.lookup(Mojito.Pool.Mux.Registry, conn_id) do
      [{conn_server, true}] ->
        Logger.debug("found conn_server #{inspect(conn_server)} for #{inspect(conn_id)}")
        conn_server

      [] ->
        child_spec = %{
          id: conn_id,
          start:
            {Mojito.ConnServer, :start_link,
             [[register: {Mojito.Pool.Mux.Registry, conn_id, true}]]},
          restart: :permanent,
          shutdown: 5000,
          type: :worker
        }

        {:ok, pid} = Supervisor.start_child(Mojito.Supervisor, child_spec)
        Logger.debug("started conn_server #{inspect(pid)} for #{inspect(conn_id)}")

        pid
    end
  end
end
