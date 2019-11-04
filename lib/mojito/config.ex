defmodule Mojito.Config do
  @moduledoc false

  @defaults [
    timeout: 5000,
    checkout_timeout: :infinity,
    request_timeout: :infinity,
    pool_size: 10,
    pool_count: 1,
    pool: true,
  ]

  def config(key, opts \\ [], destination \\ :none) do
    opts[key] || Application.get_env(:mojito, destination)[key] ||
      Application.get_env(:mojito, key) || @defaults[key]
  end

  def config(key, opts, host, port) do
    config(key, opts, "#{host}:#{port}")
  end
end
