defmodule Mojito.PoolTest do
  use ExSpec, async: false
  doctest Mojito.Pool

  context "Mojito.Pool" do
    @http_port Application.get_env(:mojito, :test_server_http_port)
    @https_port Application.get_env(:mojito, :test_server_https_port)

    defp get(path, opts \\ []) do
      Mojito.Pool.request(%Mojito.Request{
        method: :get,
        url: "http://localhost:#{@http_port}#{path}",
        opts: opts,
      })
    end

    defp get_ssl(path, opts \\ []) do
      Mojito.Pool.request(%Mojito.Request{
        method: :get,
        url: "https://localhost:#{@https_port}#{path}",
        opts: [transport_opts: [verify: :verify_none]] ++ opts,
      })
    end

    it "can make HTTP requests" do
      assert({:ok, response} = get("/"))
      assert(200 == response.status_code)
    end

    it "can make HTTPS requests" do
      assert({:ok, response} = get_ssl("/"))
      assert(200 == response.status_code)
    end

    it "can saturate many pools" do
      tasks =
        1..100
        |> Enum.map(fn _ ->
          Task.async(fn -> get("/wait1", timeout: 5000) end)
        end)

      Task.yield_many(tasks, 5100)

      GenServer.call(Mojito.Pool.Manager, :state)
      |> IO.inspect()
    end
  end
end
