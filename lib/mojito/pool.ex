defmodule Mojito.Pool do
  @moduledoc ~S"""
  > This module is intended for Mojito developers, not end users.

  The `Mojito.Pool` behaviour describes the interface of any
  pooling implementation. These implementations can be used
  by providing the `pool: <modulename>` config to
  `Mojito.request/1` and its related functions.

  A pool implementation may start one or more connection pools,
  or none at all.

  Each pool implementation may have its own configuration options,
  as well as supporting all or a subset of these standardized
  configs:

  * `:size` specifies the number of connections per connection pool.
  * `:multi` specifies the maximum number of simultaneous multiplexed
    (HTTP/2) or pipelined (HTTP/1) requests per connection.
  """

  @callback request(request :: Mojito.request()) ::
              {:ok, Mojito.response()} | {:error, Mojito.error()}

  @type pool_key :: {String.t(), pos_integer}
end
