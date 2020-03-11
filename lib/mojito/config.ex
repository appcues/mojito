defmodule Mojito.Config do
  @moduledoc false

  @doc ~S"""
  Returns the config value for the given `key`.

  Configs specified in `opts` take highest precedence.

  Per-destination configs can be specified in `opts` (second precedence)
  or in `config/config.exs` (third precedence) by referencing the
  destination's `hostname:port` as an atom, like
  `opts = ["example.com:443": [key: "value"]]` or
  `config :mojito, :"example.com:443", key: "value"`.

  Global configs (lowest precedence) can be specified in `config/config.exs`
  like `config :mojito, key: "value"`.

  If the given `key` is not found, `default` is returned.
  """
  @spec config(atom, Keyword.t(), atom) :: any
  def config(key, opts, destination \\ :none) do
    if Keyword.has_key?(opts, key) do
      opts[key]
    else
      local_destination_cfg = opts[destination] || []
      global_destination_cfg = Application.get_env(:mojito, destination, [])

      cond do
        Keyword.has_key?(local_destination_cfg, key) ->
          local_destination_cfg[key]

        Keyword.has_key?(global_destination_cfg, key) ->
          global_destination_cfg[key]

        :else ->
          Application.get_env(:mojito, key, default(key))
      end
    end
  end

  @spec config(atom, Keyword.t, String.t, String.t | non_neg_integer) :: any
  def config(key, opts, host, port) do
    destination = try do
      String.to_existing_atom("#{host}:#{port}")
    rescue
      ArgumentError -> :none
    end

    config(key, opts, destination)
  end

  @defaults [
    pools: "this value gets replaced below",
    timeout: 5000,
    checkout_timeout: :infinity,
    request_timeout: :infinity,
    size: 32,
    pipeline: 1024,
  ]

  defp default(:pools), do: System.schedulers_online()

  defp default(key), do: @defaults[key]
end
