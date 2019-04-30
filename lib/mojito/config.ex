defmodule Mojito.Config do
  @moduledoc false

  def request_timeout do
    Application.get_env(:mojito, :request_timeout, 5000)
  end

  ## pool_opts are handled in Mojito.Pool
end
