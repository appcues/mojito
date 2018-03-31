defmodule XClient.Error do
  @moduledoc false

  defstruct [:reason, :message]

  @type t :: XClient.error()
end
