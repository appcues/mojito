defmodule Mojito.Config do
  @moduledoc false

  @defaults [
    timeout: 5000,
  ]

  @spec config(atom, {any, any} | atom, Keyword.t) :: any
  def config(name, destination \\ :none, opts)

  def config(name, {hostname, port}, opts) do
    destination =
      try do
        String.to_existing_atom("#{hostname}:#{port}")
      rescue
        ArgumentError -> :none
      end

    config(name, destination, opts)
  end

  def config(name, destination, opts) do
    case Keyword.get(opts, name, :missing) do
      :missing -> dest_config(name, destination)
      value -> value
    end
  end

  defp dest_config(name, destination) do
    dest_env = Application.get_env(:mojito, destination) || []

    case Keyword.get(dest_env, name, :missing) do
      :missing -> mojito_config(name)
      value -> value
    end
  end

  defp mojito_config(name) do
    case Application.get_env(:mojito, name, :missing) do
      :missing -> @defaults[name]
      value -> value
    end
  end
end
