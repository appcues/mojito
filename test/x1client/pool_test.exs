defmodule X1Client.PoolTest do
  use ExSpec, async: true
  doctest X1Client.Pool
  doctest X1Client.ConnServer

  context "live tests" do
    @port Application.get_env(:x1client, :test_server_port)

    defp with_pool(fun) do
      rand = round(:rand.uniform() * 1_000_000_000)
      pool_name = "TestPool#{rand}" |> String.to_atom()
      {:ok, pid} = start_pool(pool_name, size: 2, max_overflow: 1)
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

    it "can saturate pool" do
      with_pool(fn pool_name ->
        spawn fn -> get(pool_name, "/wait1") end
        spawn fn -> get(pool_name, "/wait1") end
        spawn fn -> get(pool_name, "/wait1") end
        spawn fn -> get(pool_name, "/wait1") end
        :timer.sleep(100)

        ## 0 ready, 1 waiting, 3 in-progress
        assert({:full, 0, 1, 3} = :poolboy.status(pool_name))

        :timer.sleep(1000)

        ## 1 ready, 0 waiting, 1 in-progress (the one previously waiting)
        assert({:ready, 1, 0, 1} = :poolboy.status(pool_name))

        :timer.sleep(1000)

        ## 2 ready, 0 waiting, 0 in progress (all done)
        assert({:ready, 2, 0, 0} = :poolboy.status(pool_name))
      end)
    end
  end
end
