defmodule XClient.Response do
  @moduledoc false

  defstruct [:status_code, :headers, :body]

  @type t :: XClient.response()
end
