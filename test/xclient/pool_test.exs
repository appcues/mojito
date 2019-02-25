defmodule Mojito.PoolTest do
  use ExSpec, async: true
  doctest Mojito.Pool
  doctest Mojito.ConnServer

  context "live tests" do
    @http_port Application.get_env(:mojito, :test_server_http_port)
    @https_port Application.get_env(:mojito, :test_server_https_port)

    defp with_pool(fun) do
      rand = round(:rand.uniform() * 1_000_000_000)
      pool_name = "TestPool#{rand}" |> String.to_atom()
      {:ok, pid} = start_pool(pool_name, size: 2, max_overflow: 1)
      fun.(pool_name)
      GenServer.stop(pid)
    end

    defp start_pool(name, opts) do
      children = [Mojito.Pool.child_spec(name, opts)]
      Supervisor.start_link(children, strategy: :one_for_one)
    end

    defp get(pool, path, opts \\ []) do
      Mojito.Pool.request(pool, :get, "http://localhost:#{@http_port}#{path}", [], "", opts)
    end

    defp get_ssl(pool, path, opts \\ []) do
      Mojito.Pool.request(
        pool,
        :get,
        "https://localhost:#{@https_port}#{path}",
        [],
        "",
        [transport_opts: [verify: :verify_none]] ++ opts
      )
    end

    it "can make HTTP requests" do
      with_pool(fn pool_name ->
        assert({:ok, response} = get(pool_name, "/"))
        assert(200 == response.status_code)
      end)
    end

    it "can make HTTPS requests" do
      with_pool(fn pool_name ->
        assert({:ok, response} = get_ssl(pool_name, "/"))
        assert(200 == response.status_code)
      end)
    end

    it "can saturate pool" do
      with_pool(fn pool_name ->
        spawn(fn -> get(pool_name, "/wait1") end)
        spawn(fn -> get(pool_name, "/wait1") end)
        spawn(fn -> get(pool_name, "/wait1") end)
        spawn(fn -> get(pool_name, "/wait1") end)
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
