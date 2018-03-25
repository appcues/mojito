defmodule X1Client do
  @moduledoc ~S"""
  X1Client is a simplified HTTP 1.x client built using the
  low-level [XHTTP library](https://github.com/ericmj/xhttp).

  It provides an interface that will feel familiar to users of other
  Elixir HTTP client libraries.

  ## Installation

  Add `x1client` to your deps in `mix.exs`:

      {:x1client, "~> 0.6"}

  ## Single-request example

  `X1Client.request/5` can be used directly for making individual
  requests:

      >>>> X1Client.request(:get, "https://jsonplaceholder.typicode.com/posts/1")
      {:ok,
       %X1Client.Response{
         body: "{\n  \"userId\": 1,\n  \"id\": 1,\n  \"title\": \"sunt aut facere repellat provident occaecati excepturi optio reprehenderit\",\n  \"body\": \"quia et suscipit\\nsuscipit recusandae consequuntur expedita et cum\\nreprehenderit molestiae ut ut quas totam\\nnostrum rerum est autem sunt rem eveniet architecto\"\n}",
         headers: [
           {"content-type", "application/json; charset=utf-8"},
           {"content-length", "292"},
           {"connection", "keep-alive"},
           ...
         ],
         status_code: 200
       }}

  ## Pool example

  `X1Client.Pool.request/6` can be used when a pool of persistent HTTP
  connections is desired:

      >>>> children = [X1Client.Pool.child_spec(MyPool)]
      >>>> {:ok, _pid} = Supervisor.start_link(children, strategy: :one_for_one)
      >>>> X1Client.Pool.request(MyPool, :get, "http://example.com")
      {:ok, %X1Client.Response{...}}

  Connection pooling in X1Client is implemented using
  [Poolboy](https://github.com/devinus/poolboy).

  ## Self-signed SSL certificates

  To accept self-signed SSL/TLS certificates, you can give the
  `transport_opts: [verify: :verify_none]` option to `X1Client.request/5`
  or `X1Client.Pool.request/6`:

      >>>> X1Client.request(:get, "https://localhost:8443/")
      {:error, {:tls_alert, 'bad certificate'}}

      >>>> X1Client.request(:get, "https://localhost:4443/, [], "", transport_opts: [verify: :verify_none])
      {:ok, %X1Client.Response{...}}
  """

  alias X1Client.Response

  @type headers :: [{String.t(), String.t()}]

  @type method :: :get | :post | :put | :patch | :delete | :options

  @request_timeout Application.get_env(:x1client, :request_timeout, 5000)

  @doc ~S"""
  Performs an HTTP 1.x request and returns the response.

  Options:

  * `timeout` - Response timeout in milliseconds.  Defaults to
    `Application.get_env(:x1client, :request_timeout, 5000)`.
  """
  @spec request(method, String.t(), headers, String.t(), Keyword.t()) ::
          {:ok, %Response{}} | {:error, any}
  def request(method, url, headers \\ [], payload \\ "", opts \\ []) do
    timeout = opts[:timeout] || @request_timeout

    with {:ok, pid} <- X1Client.ConnServer.start_link(),
         :ok <- X1Client.ConnServer.request(pid, self(), method, url, headers, payload, opts) do
      receive do
        reply ->
          GenServer.stop(pid)
          reply
      after
        timeout ->
          GenServer.stop(pid)
          {:error, :timeout}
      end
    end
  end
end
