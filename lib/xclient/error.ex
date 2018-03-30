defmodule XClient.Error do
  @moduledoc false

  defstruct reason: nil,
            message: nil

  @type t :: XClient.error()
end
