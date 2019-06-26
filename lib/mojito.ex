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

  ## Quickstart

      {:ok, response} = Mojito.request(method: :get, url: "https://github.com")

  ## Why Mojito?

  Mojito addresses the following design goals:

  * _Little or no configuration needed._  Use Mojito to make requests to as
    many different destinations as you like, without thinking about
    starting or selecting connection pools.  Other clients like
    [Hackney](https://github.com/benoitc/hackney)
    (and [HTTPoison](https://github.com/edgurgel/httpoison)),
    [Ibrowse](https://github.com/cmullaparthi/ibrowse) (and
    [HTTPotion](https://github.com/myfreeweb/httpotion)), and
    Erlang's built-in [httpc](http://erlang.org/doc/man/httpc.html)
    offer this feature, except that...

  * _Connection pools should be used only for a single destination._
    Using a pool for making requests against multiple destinations is less
    than ideal, as many of the connections need to be reset before use.
    Mojito assigns requests to the correct pools transparently to the user.
    Other clients, such as [Buoy](https://github.com/lpgauth/buoy), Hackney/
    HTTPoison, Ibrowse/HTTPotion, etc. force the user to handle this
    themselves, which is often inconvenient if the full set of HTTP
    destinations is not known at compile time.

  * _Redundant pools to reduce concurrency-related bottlenecks._  Mojito can
    serve requests to the same destination from more than one connection
    pool, and those pools can be selected by round-robin at runtime in order
    to minimize resource contention in the Erlang VM.  This feature is
    unique to Mojito.

  ## Installation

  Add `mojito` to your deps in `mix.exs`:

      {:mojito, "~> 0.3.0"}

  ## Upgrading from 0.2

  Using request methods other than those in the `Mojito` module is deprecated.
  A handful of new config parameters appeared as well.

  Upgrading 0.2 to 0.3 cannot be performed safely inside a hot upgrade.
  Deploy a regular release instead.

  ## Configuration

  The following `config.exs` config parameters are supported:

  * `:timeout` (milliseconds, default 5000) -- Default request timeout.
  * `:transport_opts` (`t:Keyword.t`, default `[]`) -- Options to pass to
    the `:gen_tcp` or `:ssl` modules.  Commonly used to make HTTPS requests
    with self-signed TLS server certificates; see below for details.
  * `:pool_opts` (`t:pool_opts`, default `[]`) -- Configuration options
    for connection pools.

  The following `:pool_opts` options are supported:

  * `:size` (integer) sets the number of steady-state connections per pool.
    Default is 5.
  * `:max_overflow` (integer) sets the number of additional connections
    per pool, opened under conditions of heavy load.
    Default is 10.
  * `:pools` (integer) sets the maximum number of pools to open for a
    single destination host and port (not the maximum number of total
    pools to open).  Default is 5.
  * `:strategy` is either `:lifo` or `:fifo`, and selects which connection
    should be checked out of a single pool.  Default is `:lifo`.
  * `:destinations` (keyword list of `t:pool_opts`) allows these parameters
    to be set for individual `:"host:port"` destinations.

  For example:

      use Mix.Config

      config :mojito,
        timeout: 2500,
        pool_opts: [
          size: 10,
          destinations: [
            "example.com:443": [
              size: 20,
              max_overflow: 20,
              pools: 10
            ]
          ]
        ]

  Certain configs can be overridden with each request.  See `request/1`.

  ## Usage

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

  In addition to `Mojito.request/5`, Mojito also provides convenience functions like `Mojito.head/3`,
  `Mojito.get/3`, `Mojito.post/4`, `Mojito.put/4`, `Mojito.patch/4`,
  `Mojito.delete/3`, and `Mojito.options/3` for each corresponding HTTP methods.

  By default, Mojito will use a connection pool for requests, automatically
  handling the creation and reuse of pools.  If this is not desired,
  specify the `pool: false` option with a request to perform a one-off request.
  See the documentation for `request/1` for more details.

  ## Self-signed SSL/TLS certificates

  To accept self-signed certificates in HTTPS connections, you can give the
  `transport_opts: [verify: :verify_none]` option to `Mojito.request`
  or `Mojito.Pool.request`:

  ## Examples

      >>>> Mojito.request(method: :get, url: "https://localhost:8443/")
      {:error, {:tls_alert, 'bad certificate'}}

      >>>> Mojito.request(method: :get, url: "https://localhost:8443/", opts: [transport_opts: [verify: :verify_none]])
      {:ok, %Mojito.Response{...}}

  ## Changelog

  See the [CHANGELOG.md](https://github.com/appcues/mojito/blob/master/CHANGELOG.md).

  ## Contributing

  Thanks for considering contributing to this project, and to the free
  software ecosystem at large!

  Interested in contributing a bug report?  Terrific!  Please open a [GitHub
  issue](https://github.com/appcues/mojito/issues) and include as much detail
  as you can.  If you have a solution, even better -- please open a pull
  request with a clear description and tests.

  Have a feature idea?  Excellent!  Please open a [GitHub
  issue](https://github.com/appcues/mojito/issues) for discussion.

  Want to implement an issue that's been discussed?  Fantastic!  Please
  open a [GitHub pull request](https://github.com/appcues/mojito/pulls)
  and write a clear description of the patch.
  We'll merge your PR a lot sooner if it is well-documented and fully
  tested.

  Contributors and contributions are listed in the
  [changelog](https://github.com/appcues/mojito/blob/master/CHANGELOG.md).
  Heartfelt thanks to everyone who's helped make Mojito better.

  ## Authorship and License

  Copyright 2019, Appcues, Inc.

  This software is released under the MIT License.
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

  @type request_kwlist :: [request_field]

  @type request_field ::
          {:method, method}
          | {:url, String.t()}
          | {:headers, headers}
          | {:body, String.t()}
          | {:opts, Keyword.t()}

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

  @type pool_opts :: [pool_opt | {:destinations, [{atom, pool_opts}]}]

  @type pool_opt ::
          {:size, pos_integer}
          | {:max_overflow, non_neg_integer}
          | {:pools, pos_integer}
          | {:strategy, :lifo | :fifo}

  @doc ~S"""
  Performs an HTTP request and returns the response.

  See `request/1` for details.
  """
  @spec request(method, String.t(), headers, String.t(), Keyword.t()) ::
          {:ok, response} | {:error, error} | no_return
  def request(method, url, headers \\ [], body \\ "", opts \\ []) do
    %Mojito.Request{
      method: method,
      url: url,
      headers: headers,
      body: body,
      opts: opts
    }
    |> request
  end

  @doc ~S"""
  Performs an HTTP request and returns the response.

  If the `pool: true` option is given, or `:pool` is not specified, the
  request will be made using Mojito's automatic connection pooling system.
  For more details, see `Mojito.Pool.request/1`.  This is the default
  mode of operation, and is recommended for best performance.

  If `pool: false` is given as an option, the request will be made on
  a brand new connection.  This does not spawn an additional process.
  Messages of the form `{:tcp, _, _}` or `{:ssl, _, _}` will be sent to
  and handled by the caller.  If the caller process expects to receive
  other `:tcp` or `:ssl` messages at the same time, conflicts can occur;
  in this case, it is recommended to wrap `request/1` in `Task.async/1`,
  or use one of the pooled request modes.

  Options:

  * `:pool` - See above.
  * `:timeout` - Response timeout in milliseconds.  Defaults to
    `Application.get_env(:mojito, :timeout, 5000)`.
  * `:transport_opts` - Options to be passed to either `:gen_tcp` or `:ssl`.
    Most commonly used to perform insecure HTTPS requests via
    `transport_opts: [verify: :verify_none]`.
  """
  @spec request(request | request_kwlist) :: {:ok, response} | {:error, error}
  def request(request) do
    with {:ok, valid_request} <- Mojito.Request.validate_request(request) do
      request_fn =
        case Keyword.get(valid_request.opts, :pool, true) do
          true -> fn -> Mojito.Pool.request(valid_request) end
          false -> fn -> Mojito.Request.Single.request(valid_request) end
          pool -> fn -> Mojito.Pool.Single.request(pool, valid_request) end
        end

      ## Retry connection-closed errors once
      case request_fn.() |> Mojito.Utils.wrap_return_value() do
        {:error, %{reason: %{reason: :closed}}} -> request_fn.()
        other -> other
      end
    end
  end

  @doc ~S"""
  Perform an HTTP HEAD request and returns the response.

  See `request/1` for documentation.
  """
  @spec head(String.t(), headers, Keyword.t()) ::
          {:ok, response} | {:error, error} | no_return
  def head(url, headers \\ [], opts \\ []) do
    request(:head, url, headers, "", opts)
  end

  @doc ~S"""
  Perform an HTTP GET request and returns the response.

  ## Examples

  Assemble URL with a query string params and fetch it with GET request:

      >>>> "https://www.google.com/search"
      ...> |> URI.parse()
      ...> |> Map.put(:query, URI.encode_query(%{"q" => "mojito elixir"}))
      ...> |> URI.to_string()
      ...> |> Mojito.get()
      {:ok,
       %Mojito.Response{
         body: "<!doctype html><html lang=\"en\"><head><meta charset=\"UTF-8\"> ...",
         complete: true,
         headers: [
           {"content-type", "text/html; charset=ISO-8859-1"},
           ...
         ],
         status_code: 200
       }}


  See `request/1` for detailed documentation.
  """
  @spec get(String.t(), headers, Keyword.t()) ::
          {:ok, response} | {:error, error} | no_return
  def get(url, headers \\ [], opts \\ []) do
    request(:get, url, headers, "", opts)
  end

  @doc ~S"""
  Perform an HTTP POST request and returns the response.

  ## Examples

  Submitting a form with POST request:

      >>>> Mojito.post(
      ...>   "http://localhost:4000/messages",
      ...>   [{"content-type", "application/x-www-form-urlencoded"}],
      ...>   URI.encode_query(%{"message[subject]" => "Contact request", "message[content]" => "data"}))
      {:ok,
       %Mojito.Response{
         body: "Thank you!",
         complete: true,
         headers: [
           {"server", "Cowboy"},
           {"connection", "keep-alive"},
           ...
         ],
         status_code: 200
       }}

  Submitting a JSON payload as POST request body:

      >>>> Mojito.post(
      ...>   "http://localhost:4000/api/messages",
      ...>   [{"content-type", "application/json"}],
      ...>   Jason.encode(%{"message" => %{"subject" => "Contact request", "content" => "data"}}))
      {:ok,
       %Mojito.Response{
         body: "{\"message\": \"Thank you!\"}",
         complete: true,
         headers: [
           {"server", "Cowboy"},
           {"connection", "keep-alive"},
           ...
         ],
         status_code: 200
       }}

  See `request/1` for detailed documentation.
  """
  @spec post(String.t(), headers, String.t(), Keyword.t()) ::
          {:ok, response} | {:error, error} | no_return
  def post(url, headers \\ [], payload \\ "", opts \\ []) do
    request(:post, url, headers, payload, opts)
  end

  @doc ~S"""
  Perform an HTTP PUT request and returns the response.

  See `request/1` and `post/4` for documentation and examples.
  """
  @spec put(String.t(), headers, String.t(), Keyword.t()) ::
          {:ok, response} | {:error, error} | no_return
  def put(url, headers \\ [], payload \\ "", opts \\ []) do
    request(:put, url, headers, payload, opts)
  end

  @doc ~S"""
  Perform an HTTP PATCH request and returns the response.

  See `request/1` and `post/4` for documentation and examples.
  """
  @spec patch(String.t(), headers, String.t(), Keyword.t()) ::
          {:ok, response} | {:error, error} | no_return
  def patch(url, headers \\ [], payload \\ "", opts \\ []) do
    request(:patch, url, headers, payload, opts)
  end

  @doc ~S"""
  Perform an HTTP DELETE request and returns the response.

  See `request/1` and `post/4` for documentation and examples.
  """
  @spec delete(String.t(), headers, Keyword.t()) ::
          {:ok, response} | {:error, error} | no_return
  def delete(url, headers \\ [], opts \\ []) do
    request(:delete, url, headers, "", opts)
  end

  @doc ~S"""
  Perform an HTTP OPTIONS request and returns the response.

  See `request/1` for documentation.
  """
  @spec options(String.t(), headers, Keyword.t()) ::
          {:ok, response} | {:error, error} | no_return
  def options(url, headers \\ [], opts \\ []) do
    request(:options, url, headers, "", opts)
  end
end
