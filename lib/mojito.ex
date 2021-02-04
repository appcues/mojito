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

      {:mojito, "~> 0.7.7"}

  ## Upgrading from 0.4 and earlier

  Upgrading to 0.7 cannot be performed safely inside a hot upgrade.
  Deploy a regular release instead.

  Upgrading from 0.4 to 0.5 requires no end-user code changes.

  Mojito 0.5 refactors some internal functions in a way that changes
  their arity and order of arguments.

  Using request methods other than those in the `Mojito` module is
  deprecated since 0.3.

  A handful of new config parameters appeared in 0.3 as well.

  ## Configuration

  The following `config.exs` config parameters are supported:

  * `:timeout` (`:infinity` or milliseconds, default `5000`) --
    Default request timeout.
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

  ## Telemetry

  Mojito integrates with the standard
  [Telemetry](https://github.com/beam-telemetry/telemetry) library.

  See the `Mojito.Telemetry` module for more information.

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

  Copyright 2018-2019, Appcues, Inc.

  This software is released under the MIT License.
  """

  use Mojito.Base
end
