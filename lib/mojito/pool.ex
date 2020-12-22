defmodule Mojito.Pool do
  @moduledoc false

  @callback request(request :: Mojito.request()) ::
              {:ok, Mojito.response()} | {:error, Mojito.error()}

  @type pool_key :: {String.t(), pos_integer}
end
