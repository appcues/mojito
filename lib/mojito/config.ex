defmodule Mojito.Config do
  @moduledoc false

  def timeout do
    Application.get_env(:mojito, :timeout, 5000)
  end

  ## pool_opts are handled in Mojito.Pool
end
