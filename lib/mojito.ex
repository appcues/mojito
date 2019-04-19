defmodule Mojito do
  @moduledoc ~S"""
  Mojito is a simplified HTTP client built using the
  low-level [Mint library](https://github.com/ericmj/mint).

  It provides an interface that will feel familiar to users of other
  Elixir HTTP client libraries.

  WARNING! This library currently depends on brand new software (Mint).
  It is not yet recommended to use Mojito in production.

  ## Installation

  Add `mojito` to your deps in `mix.exs`:

      {:mojito, "~> 0.2.0"}

  ## Single-request example

  `Mojito.request/5` can be used directly for making individual
  requests:

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

  ## Pool example

  `Mojito.Pool.request/6` can be used when a pool of persistent HTTP
  connections is desired:

      >>>> children = [Mojito.Pool.child_spec(MyPool)]
      >>>> {:ok, _pid} = Supervisor.start_link(children, strategy: :one_for_one)
      >>>> Mojito.Pool.request(MyPool, :get, "http://example.com")
      {:ok, %Mojito.Response{...}}

  Connection pooling in Mojito is implemented using
  [Poolboy](https://github.com/devinus/poolboy).

  ## Self-signed SSL/TLS certificates

  To accept self-signed certificates in HTTPS connections, you can give the
  `transport_opts: [verify: :verify_none]` option to `Mojito.request/5`
  or `Mojito.Pool.request/6`:

      >>>> Mojito.request(:get, "https://localhost:8443/")
      {:error, {:tls_alert, 'bad certificate'}}

      >>>> Mojito.request(:get, "https://localhost:4443/", [], "", transport_opts: [verify: :verify_none])
      {:ok, %Mojito.Response{...}}
  """

  alias Mojito.{Error, Utils}

  @type headers :: [{String.t(), String.t()}]

  @type response :: %Mojito.Response{
          status_code: pos_integer,
          headers: headers,
          body: String.t(),
        }

  @type error :: %Mojito.Error{
          reason: any,
          message: any,
        }

  @type method ::
          :head | :get | :post | :put | :patch | :delete | :options | String.t()

  @request_timeout Application.get_env(:mojito, :request_timeout, 5000)

  @doc ~S"""
  Performs an HTTP request and returns the response.

  Options:

  * `:timeout` - Response timeout in milliseconds.  Defaults to
    `Application.get_env(:mojito, :request_timeout, 5000)`.
  """
  @spec request(method, String.t(), headers, String.t(), Keyword.t()) ::
          {:ok, response} | {:error, error}
  def request(method, url, headers \\ [], payload \\ "", opts \\ [])

  def request(nil, _url, _headers, _payload, _opts) do
    {:error, %Mojito.Error{message: "method cannot be nil"}}
  end

  def request("", _url, _headers, _payload, _opts) do
    {:error, %Mojito.Error{message: "method cannot be blank"}}
  end

  def request(_method, nil, _headers, _payload, _opts) do
    {:error, %Mojito.Error{message: "url cannot be nil"}}
  end

  def request(_method, "", _headers, _payload, _opts) do
    {:error, %Mojito.Error{message: "url cannot be blank"}}
  end

  def request(method, url, headers, payload, opts) do
    timeout = opts[:timeout] || @request_timeout

    with {:ok, pid} <- Mojito.ConnServer.start_link(),
         :ok <-
           Mojito.ConnServer.request(
             pid,
             self(),
             method,
             url,
             headers,
             payload,
             opts
           ) do
      receive do
        {:mojito_response, reply} ->
          GenServer.stop(pid)
          reply
      after
        timeout ->
          GenServer.stop(pid)
          {:error, %Error{reason: :timeout}}
      end
    end
    |> Utils.wrap_return_value()
  end
end
