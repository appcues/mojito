defmodule X1Client.PoolTest do
  use ExSpec, async: true
  doctest X1Client.Pool
  doctest X1Client.PoolWorker

  context "live tests" do
    @port Application.get_env(:x1client, :test_server_port)

    defp with_pool(fun) do
      rand = round(:rand.uniform() * 1_000_000_000)
      pool_name = "TestPool#{rand}" |> String.to_atom()
      {:ok, pid} = start_pool(pool_name, size: 2, max_overflow: 2)
      fun.(pool_name)
      GenServer.stop(pid)
    end

    defp start_pool(name, opts) do
      children = [X1Client.Pool.child_spec(name, opts)]
      Supervisor.start_link(children, strategy: :one_for_one)
    end

    defp get(pool, path, opts \\ []) do
      X1Client.Pool.request(pool, :get, "http://localhost:#{@port}#{path}", [], "", opts)
    end

    it "can make requests" do
      with_pool(fn pool_name ->
        assert({:ok, response} = get(pool_name, "/"))
        assert(200 == response.status_code)
      end)
    end
  end
end
