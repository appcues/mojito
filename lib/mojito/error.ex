defmodule Mojito.Error do
  @moduledoc false

  defstruct [:reason, :message]

  @type t :: Mojito.error()
end
