defmodule XClient.Response do
  @moduledoc false

  defstruct status_code: nil,
            headers: [],
            body: []

  @type t :: XClient.response()
end
