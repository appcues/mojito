defmodule XClient.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      # {XClient.Worker, arg},
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: XClient.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
