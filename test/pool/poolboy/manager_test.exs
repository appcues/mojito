defmodule Mojito.Pool.Poolboy.ManagerTest do
  use ExSpec, async: true

  context "calls" do
    it "implements get_pools" do
      assert(
        [] =
          GenServer.call(
            Mojito.Pool.Poolboy.Manager,
            {:get_pools, {"example.com", 80}}
          )
      )
    end

    it "implements get_pool_states" do
      assert(
        [] =
          GenServer.call(
            Mojito.Pool.Poolboy.Manager,
            {:get_pool_states, {"example.com", 80}}
          )
      )
    end
  end
end
