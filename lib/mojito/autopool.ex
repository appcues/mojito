defmodule Mojito.Autopool do
  alias Mojito.{Autopool, Utils}

  def request(%{} = request) do
    with {:ok, proto, host, port} <- Utils.decompose_url(request.url) do
      pool_id = {proto, host, port}

      pool_atom =
        "mojito_autopool_#{proto}_#{host}_#{port}"
        |> String.to_atom()

      pool_pid =
        case Registry.lookup(Autopool.Registry, pool_id) do
          [] ->
            ## TODO per-pool config
            IO.puts("making pool for #{inspect(pool_id)}")

            {:ok, pid} =
              [Mojito.Pool.child_spec(pool_atom)]
              |> Supervisor.start_link(strategy: :one_for_one)

            {:ok, _} = Registry.register(Autopool.Registry, pool_id, pid)
            pid

          [{_, pid} | _] ->
            pid
        end

      Mojito.Pool.request(pool_atom, request)
    end
  end
end
