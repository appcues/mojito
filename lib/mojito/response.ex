defmodule Mojito.Response do
  @moduledoc false

  defstruct status_code: nil,
            headers: [],
            body: "",
            complete: false,
            size: 0

  @type t :: Mojito.response()
end
