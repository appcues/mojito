defmodule Mojito do
  @moduledoc ~S"""
  Mojito is an easy-to-use, high-performance HTTP client built using the
  low-level [Mint library](https://github.com/ericmj/mint).

  Mojito is built for comfort _and_ for speed.  Behind a simple and
  predictable interface, there is a sophisticated connection pool manager
  that delivers maximum throughput with no intervention from the user.

  Just want to make one request and bail?  No problem.  Mojito can make
  one-off requests as well, using the same process-less architecture as
  Mint.

  ## Installation

  Add `mojito` to your deps in `mix.exs`:

      {:mojito, "~> 0.3.0"}

  ## Common usage

  Make requests with `Mojito.request/1` or `Mojito.request/5`:

      >>>> Mojito.request(:get, "https://jsonplaceholder.typicode.com/posts/1")
      ## or...
      >>>> Mojito.request(%{method: :get, url: "https://jsonplaceholder.typicode.com/posts/1"})
      ## or...
      >>>> Mojito.request(method: :get, url: "https://jsonplaceholder.typicode.com/posts/1")

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

  By default, Mojito will use a connection pool for requests, automatically
  handling the creation and reuse of pools.  If this is not desired,
  specify the `pool: false` option with a request to perform a one-off request,
  or `pool: pool_name_or_pid` to use a specific user-created `Mojito.Pool.Single`
  pool.  See the documentation for `request/1` for more details.

  ## Self-signed SSL/TLS certificates

  To accept self-signed certificates in HTTPS connections, you can give the
  `transport_opts: [verify: :verify_none]` option to `Mojito.request`
  or `Mojito.Pool.request`:

      >>>> Mojito.request(method: :get, url: "https://localhost:8443/")
      {:error, {:tls_alert, 'bad certificate'}}

      >>>> Mojito.request(method: :get, url: "https://localhost:8443/", opts: [transport_opts: [verify: :verify_none]])
      {:ok, %Mojito.Response{ ... }}
  """

  @type method ::
          :head | :get | :post | :put | :patch | :delete | :options | String.t()

  @type headers :: [{String.t(), String.t()}]

  @type request :: %Mojito.Request{
          method: method,
          url: String.t(),
          headers: headers | nil,
          body: String.t() | nil,
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

  See `request/1` for documentation.
  """
  @spec request(method, String.t(), headers, String.t(), Keyword.t()) ::
          {:ok, response} | {:error, error} | no_return
  def request(method, url, headers \\ [], body \\ "", opts \\ []) do
    %Mojito.Request{
      method: method,
      url: url,
      headers: headers,
      body: body,
      opts: opts,
    }
    |> request
  end

  @doc ~S"""
  Performs an HTTP request and returns the response.

  Does not spawn an additional process.  Messages of the form `{:tcp, _, _}`
  or `{:ssl, _, _}` will be sent to and handled by the caller.  If the
  caller process expects to receive other `:tcp` or `:ssl` messages at the same
  time, conflicts can occur; in this case, it is recommended to wrap
  `request/1` in `Task.async/1`.

  Options:

  * `:timeout` - Response timeout in milliseconds.  Defaults to
    `Application.get_env(:mojito, :request_timeout, 5000)`.
  * `:transport_opts` - Options to be passed to either `:gen_tcp` or `:ssl`.
    Most commonly used to perform insecure HTTPS requests via
    `transport_opts: [verify: :verify_none]`.
  """
  @spec request(request) :: {:ok, response} | {:error, error}
  def request(request) do
    with {:ok, valid_request} <- Mojito.Request.validate_request(request) do
      Mojito.Pool.request(valid_request)
    end
  end
end
