defmodule Mojito.Config do
  @moduledoc ~S"""
  Mojito.Config is the basis for Mojito's configuration.
  It allows destinationd and top-level configuration at compile
  time and runtime, as well as dependency injection that is
  convenient in testing.

  Any configuration key can be present at the top level:

      # in config.exs
      config :mojito, timeout: 10_000

      # in opts
      Mojito.get(url, timeout: 10_000)

  Or nested under a destination, which is an atom of `hostname:port`:

      # in config.exs
      config :mojito, :"example.com:80", timeout: 500

      # in opts
      Mojito.get(url, "example.com:80": [timeout: 500])

  To retrieve a config value, use any of:

      Mojito.Config.config(:somekey, opts)
      Mojito.Config.config(:"example.com:443", :somekey, opts)
      Mojito.Config.config(:"example.com:443", :somekey)

  Configurations in `opts` override configs in `config.exs`
  (i.e., `Application.get_env/2`), which override defaults.

  """

  @defaults [
    ## implementations
    mint: Mint,
    pool: Mojito.Pool.Poolboy,

    ## configs
    timeout: 5000,
    checkout_timeout: :infinity,
    request_timeout: :infinity,
    size: 8,
    pipeline: 1024,
    strategy: :lifo
  ]

  ## runtime_default/1 is for values that must be determined at runtime
  defp runtime_default(:pools), do: System.schedulers_online()

  defp runtime_default(_key), do: nil

  @doc "Looks up a config value. Returns `nil` if not found."
  @spec config(atom | Mojito.Pool.pool_key(), atom, Keyword.t) :: any | nil
  def config(destination, key, opts) when is_atom(destination) do
    ## First non-nil value wins
    with nil <- opts[destination][key],
         nil <- opts[key],
         nil <- Application.get_env(:mojito, destination)[key],
         nil <- Application.get_env(:mojito, key),
         nil <- @defaults[destination][key],
         nil <- @defaults[key],
         nil <- runtime_default(key) do
      nil
    end
  end

  def config({host, port}=_pool_key, key, opts) do
    try do
      "#{host}:#{port}"
      |> String.to_existing_atom()
      |> config(key, opts)
    rescue
      ArgumentError -> config(:none, key, opts)
    end
  end

  @spec config(atom, atom | Keyword.t()) :: any | nil
  def config(key, opts) when is_list(opts) do
    config(:none, key, opts)
  end

  def config(destination, key) when is_atom(key) do
    config(destination, key, [])
  end
end
