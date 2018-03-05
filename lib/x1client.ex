defmodule X1Client do
  @moduledoc ~S"""
  `X1Client` is a simplified HTTP 1.x client built using the
  low-level [`XHTTP` library](https://github.com/ericmj/xhttp).

  It provides an interface that will feel familiar to users of other
  Elixir HTTP client libraries.
  """

  alias X1Client.{Conn, Response}

  @type response :: %Response{}

  @request_timeout Application.get_env(:x1client, :request_timeout, 5000)

  @doc ~S"""
  Performs an HTTP 1.x request.
  """
  def request(method, url, headers, payload, opts \\ []) do
    timeout = opts[:timeout] || @request_timeout

    fn ->
      with {:ok, conn} <- Conn.connect(url),
           {:ok, conn, _} <- Conn.request(conn, method, url, headers, payload, opts),
           {:ok, _conn, response} <- Conn.stream_response(conn, opts) do
        {:ok, response}
      end
    end
    |> Task.async()
    |> Task.await(timeout)
  end
end
