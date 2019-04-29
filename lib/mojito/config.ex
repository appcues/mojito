defmodule Mojito.Config do
  @moduledoc false

  @type pool_opts :: [pool_opt | {:destinations, %{String.t() => [pool_opt]}}]

  @type pool_opt ::
          {:size, pos_integer}
          | {:max_overflow, non_neg_integer}
          | {:max_pools, pos_integer}
          | {:name, atom}
          | {:strategy, :lifo | :fifo}

  def request_timeout do
    Application.get_env(:mojito, :request_timeout, 5000)
  end

  def pool_opts do
    Application.get_env(:mojito, :pool_opts, [])
  end

  def pool_opts(nil), do: pool_opts()

  def pool_opts(key) do
    opts = pool_opts()
    destinations = Keyword.get(opts, :destinations, %{})
    key_opts = Map.get(destinations, key, [])

    opts |> Keyword.merge(key_opts)
  end
end
