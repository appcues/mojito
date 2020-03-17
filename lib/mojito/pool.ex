defmodule Mojito.Pool do
  @moduledoc false

  @callback request(request :: Mojito.request()) ::
              {:ok, Mojito.response()} | {:error, Mojito.error()}

  @type pool_opts :: [pool_opt | {:destinations, [pool_opt]}]

  @type pool_opt ::
          {:size, pos_integer}
          | {:max_overflow, non_neg_integer}
          | {:pools, pos_integer}
          | {:strategy, :lifo | :fifo}

  @type pool_key :: {String.t(), pos_integer}

  @default_pool_opts [
    size: 5,
    max_overflow: 10,
    pools: 5,
    strategy: :lifo
  ]

  ## Returns the configured `t:pool_opts` for the given destination.
  @doc false
  @spec pool_opts(pool_key) :: Mojito.pool_opts()
  def pool_opts({host, port}) do
    destination_key =
      try do
        "#{host}:#{port}" |> String.to_existing_atom()
      rescue
        _ -> :none
      end

    config_pool_opts = Application.get_env(:mojito, :pool_opts, [])

    destination_pool_opts =
      config_pool_opts
      |> Keyword.get(:destinations, [])
      |> Keyword.get(destination_key, [])

    @default_pool_opts
    |> Keyword.merge(config_pool_opts)
    |> Keyword.merge(destination_pool_opts)
    |> Keyword.delete(:destinations)
  end
end
