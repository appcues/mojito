defmodule Mojito.Response do
  @moduledoc false

  defstruct status_code: nil,
            headers: [],
            body: "",
            complete: false,
            location: nil

  @type t :: Mojito.response()
end
