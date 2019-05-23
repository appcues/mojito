defmodule Mojito.Pool.Manager do
  ## I'd prefer to start new pools directly in the caller process, but
  ## they'd end up disappearing from the registry when the process
  ## terminates.  So instead we start new pools from here, a long-lived
  ## GenServer, and link them to Mojito.Supervisor instead of to here.

  @moduledoc false

  use GenServer

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(args) do
    {:ok, %{args: args, pools: %{}, last_start_at: %{}}}
  end

  defp time, do: System.monotonic_time(:millisecond)

  def handle_call({:start_pool, pool_name, size, max_pipeline}, _from, state) do
    pool = %{
      name: pool_name,
      size: size,
      max_pipeline: max_pipeline,

      ## Current pipeline depth for each worker
      ## Resets to 0 if worker dies
      pipeline: :counters.new(size, []),

      ## Total success responses for each worker slot
      ## Persists if worker dies
      response_2xx: :counters.new(size, []),

      ## Total 4xx responses for each worker slot
      ## Persists if worker dies
      response_4xx: :counters.new(size, []),

      ## Total 5xx responses for each worker slot
      ## Persists if worker dies
      response_5xx: :counters.new(size, []),
    }

    ## Start `size` workers, each of which will register itself in
    ## Mojito.Pool.Registry
    1..size
    |> Enum.each(fn index ->
      {:ok, _pid} =
        DynamicSupervisor.start_child(
          Mojito.Pool.Supervisor,
          {Mojito.ConnServer, [pool: pool, index: index]}
        )
    end)

    ## This is mostly for convenience and debugging
    pools = state.pools |> Map.put(pool_name, pool)

    {:reply, {:ok, pool}, %{state | pools: pools}}
  end

  def handle_call(:state, _from, state) do
    {:reply, state, state}
  end
end
