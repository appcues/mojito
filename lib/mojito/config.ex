defmodule Mojito.Config do
  @defaults [
    ## implementations
    mint: Mint,
    pool: Mojito.Pool.Poolboy,

    ## configs
    timeout: 5000,
    checkout_timeout: :infinity,
    request_timeout: :infinity,
    transport_opts: [],
    size: 8,
    depth: 1024,
    strategy: :lifo
  ]

  @moduledoc ~s"""
  Mojito.Config is the basis for Mojito's configuration system.
  It allows destination- and top-level configuration at compile
  time and runtime, as well as dependency injection that is
  convenient in testing.

  Any configuration key can be set at the top level:

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

      # top-level scope
      Mojito.Config.config(:somekey)
      Mojito.Config.config(:somekey, opts)

      # common case: scoped under a destination/pool key
      Mojito.Config.config({"example.com", 443}, :somekey)
      Mojito.Config.config({"example.com", 443}, :somekey, opts)

      # this works, just make sure you don't allocate atoms at runtime!
      Mojito.Config.config(:"example.com:443", :somekey)
      Mojito.Config.config(:"example.com:443", :somekey, opts)

  Configurations in `opts` override configs in `config.exs`
  (i.e., `Application.get_env/2`), which override defaults.
  And at each level, namespaced configs override top-level configs.

  ## Available options

  ### Request options

  * `:timeout` is the maximum number of milliseconds to wait for
    a request to complete, including both the time spent checking
    out a pool worker, and the time spent communicating with the
    server. Set to `:infinity` to wait indefinitely.
    Default is `#{inspect @defaults[:timeout]}`.

  * `:checkout_timeout` is the maximum number of milliseconds (or
    `:infinity`, as above) to wait for a pool worker to be available.
    Default is `#{inspect @defaults[:checkout_timeout]}`.

  * `:request_timeout` is the maximum number of milliseconds (or
    `:infinity`, as above) to wait for the server to complete its
    response once a pool worker has been checked out.
    Default is `#{inspect @defaults[:request_timeout]}`.

  * `:transport_opts` is passed to the `:gen_tcp` or `:ssl` module
    when establishing connections. Its most common use is disabling
    TLS certificate verification by passing a value of
    `[verify: :verify_none]`.
    Default is `#{inspect @defaults[:transport_opts]}`.

  ### Pool options

  * `:pools` is the number of separate pools to start for each unique
    destination (host + port). Default is `System.schedulers_online()`,
    generally the number of CPUs.

  * `:size` is the number of connections per pool.
    Default is `#{inspect @defaults[:size]}`.

  * `:depth` is the maximum number of pipelined (HTTP/1.1) or
    multiplexed (HTTP/2) requests per pool worker.
    Default is `#{inspect @defaults[:depth]}`.

  * `:strategy` is the algorithm for selecting a pool worker.
    Valid values are `:lifo` (reuse workers immediately) and
    `:fifo` (wait as long as possible before reuse).
    Default is `#{inspect @defaults[:strategy]}`.
  """

  ## runtime_default/1 is for values that must be determined at runtime
  defp runtime_default(:pools), do: System.schedulers_online()

  defp runtime_default(_key), do: nil

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

  @spec config(atom) :: any | nil
  def config(key) do
    config(:none, key, [])
  end
end
