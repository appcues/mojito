defmodule Mojito.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      Mojito.Pool.Poolboy.Manager,
      {Registry,
       keys: :duplicate,
       name: Mojito.Pool.Poolboy.Registry,
       partitions: System.schedulers_online()}
    ]

    opts = [strategy: :one_for_one, name: Mojito.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
