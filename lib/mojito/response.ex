defmodule Mojito.Response do
  @moduledoc false

  defstruct [:status_code, :headers, :body]

  @type t :: Mojito.response()
end
