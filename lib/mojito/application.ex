defmodule Mojito.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      Mojito.Pool.Manager,
      {Registry,
       keys: :duplicate,
       name: Mojito.Pool.Registry,
       partitions: System.schedulers_online()},
      {DynamicSupervisor, name: Mojito.Pool.Supervisor},
    ]

    opts = [strategy: :one_for_one, name: Mojito.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
