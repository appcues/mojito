defmodule X1Client.Response do
  defstruct status_code: nil,
            headers: %{},
            body: [],
            done: false
end
