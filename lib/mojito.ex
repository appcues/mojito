defmodule Mojito do
  @moduledoc ~S"""
  Mojito is an easy-to-use HTTP client built using the
  low-level [Mint library](https://github.com/ericmj/mint).

  It provides an interface that will feel familiar to users of other
  Elixir HTTP client libraries.

  HTTPS, one-off requests, connection pooling, and request pipelining are
  supported out of the box.  Mojito supports the same process-less
  architecture as Mint; i.e., it does not spawn a process per request.

  ## Installation

  Add `mojito` to your deps in `mix.exs`:

      {:mojito, "~> 0.2.1"}

  ## Single-request example

  `Mojito.request/1` or the equivalent `Mojito.request/5` can be used
  directly for making individual requests:

      >>>> Mojito.request(:get, "https://jsonplaceholder.typicode.com/posts/1")
      {:ok,
       %Mojito.Response{
         body: "{\n  \"userId\": 1,\n  \"id\": 1,\n  \"title\": \"sunt aut facere repellat provident occaecati excepturi optio reprehenderit\",\n  \"body\": \"quia et suscipit\\nsuscipit recusandae consequuntur expedita et cum\\nreprehenderit molestiae ut ut quas totam\\nnostrum rerum est autem sunt rem eveniet architecto\"\n}",
         headers: [
           {"content-type", "application/json; charset=utf-8"},
           {"content-length", "292"},
           {"connection", "keep-alive"},
           ...
         ],
         status_code: 200
       }}

  `Mojito.request/1,5` does not spawn any additional processes to handle the
  HTTP response; TCP messages are received and handled within the caller
  process.  In the common case, this results in faster performance and
  lower overhead in the Erlang VM.

  However, if the caller is also expecting to receive other messages at
  the same time, this can cause conflict.  In this case, it's recommended
  to wrap the call to `Mojito.request/1,5` in `Task.async/1`:

      >>>> task = Task.async(fn () -> Mojito.request(:get, "https://jsonplaceholder.typicode.com/posts/1") end)
      >>>> Task.await(task)
      {:ok,
       %Mojito.Response{
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

  `Mojito.Pool.request/6` can be used when a pool of persistent HTTP
  connections is desired:

      >>>> children = [Mojito.Pool.child_spec(MyPool)]
      >>>> {:ok, _pid} = Supervisor.start_link(children, strategy: :one_for_one)
      >>>> Mojito.Pool.request(MyPool, :get, "http://example.com")
      {:ok, %Mojito.Response{...}}

  Connection pooling in Mojito is implemented using
  [Poolboy](https://github.com/devinus/poolboy).

  Currently, Mojito connection pools should only be used to access a single
  protocol + hostname + port destination; otherwise, connections are
  reused only sporadically.

  ## Self-signed SSL/TLS certificates

  To accept self-signed certificates in HTTPS connections, you can give the
  `transport_opts: [verify: :verify_none]` option to `Mojito.request/5`
  or `Mojito.Pool.request/6`:

      >>>> Mojito.request(:get, "https://localhost:8443/")
      {:error, {:tls_alert, 'bad certificate'}}

      >>>> Mojito.request(:get, "https://localhost:4443/", [], "", transport_opts: [verify: :verify_none])
      {:ok, %Mojito.Response{...}}
  """

  @type method ::
          :head | :get | :post | :put | :patch | :delete | :options | String.t()

  @type headers :: [{String.t(), String.t()}]

  @type request :: %Mojito.Request{
          method: method,
          url: String.t(),
          headers: headers | nil,
          payload: String.t() | nil,
          opts: Keyword.t() | nil,
        }

  @type response :: %Mojito.Response{
          status_code: pos_integer,
          headers: headers,
          body: String.t(),
          complete: boolean,
        }

  @type error :: %Mojito.Error{
          reason: any,
          message: String.t() | nil,
        }

  @doc ~S"""
  Performs an HTTP request and returns the response.
  Equivalent to `request/1`.
  Does not spawn an additional process.

  Options:

  * `:timeout` - Response timeout in milliseconds.  Defaults to
    `Application.get_env(:mojito, :request_timeout, 5000)`.
  """
  @spec request(method, String.t(), headers, String.t(), Keyword.t()) ::
          {:ok, response} | {:error, error} | no_return
  def request(method, url, headers \\ [], payload \\ "", opts \\ []) do
    %Mojito.Request{
      method: method,
      url: url,
      headers: headers,
      payload: payload,
      opts: opts,
    }
    |> request
  end

  @doc ~S"""
  Performs an HTTP request and returns the response.
  Does not spawn an additional process.

  Options:

  * `:timeout` - Response timeout in milliseconds.  Defaults to
    `Application.get_env(:mojito, :request_timeout, 5000)`.
  """
  @spec request(request) :: {:ok, response} | {:error, error} | no_return
  def request(request)

  def request(%{method: nil}) do
    {:error, %Mojito.Error{message: "method cannot be nil"}}
  end

  def request(%{method: ""}) do
    {:error, %Mojito.Error{message: "method cannot be blank"}}
  end

  def request(%{url: nil}) do
    {:error, %Mojito.Error{message: "url cannot be nil"}}
  end

  def request(%{url: ""}) do
    {:error, %Mojito.Error{message: "url cannot be blank"}}
  end

  def request(%{headers: h}) when not is_list(h) and not is_nil(h) do
    {:error, %Mojito.Error{message: "headers must be a list"}}
  end

  def request(%{payload: p}) when not is_binary(p) and not is_nil(p) do
    {:error, %Mojito.Error{message: "payload must be a UTF-8 string"}}
  end

  def request(%{} = request) do
    Mojito.Request.request(request)
  end
end
