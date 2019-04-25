<img align="right" width="131" height="225" src="assets/mojito.png?raw=true">

# Mojito [![Build Status](https://travis-ci.org/appcues/mojito.svg?branch=master)](https://travis-ci.org/appcues/mojito) [![Docs](https://img.shields.io/badge/api-docs-green.svg?style=flat)](https://hexdocs.pm/mojito/Mojito.html) [![Hex.pm Version](http://img.shields.io/hexpm/v/mojito.svg?style=flat)](https://hex.pm/packages/mojito)

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

`Mojito.request` does not spawn any additional processes to handle the
HTTP response; TCP messages are received and handled within the caller
process.  In the common case, this results in faster performance and
lower overhead in the Erlang VM.

However, if the caller is also expecting to receive other messages at
the same time, this can cause conflict.  In this case, it's recommended
to wrap the call to `Mojito.request` in `Task.async/1`:

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

`Mojito.Pool.request/2` or the equivalent `Mojito.Pool.request/6` can be
used when a pool of persistent HTTP connections is desired:

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
`transport_opts: [verify: :verify_none]` option to `Mojito.request`
or `Mojito.Pool.request`:

    >>>> Mojito.request(:get, "https://localhost:8443/")
    {:error, {:tls_alert, 'bad certificate'}}

    >>>> Mojito.request(:get, "https://localhost:4443/", [], "", transport_opts: [verify: :verify_none])
    {:ok, %Mojito.Response{...}}

## Authorship and License

Copyright 2018-2019, Appcues, Inc.

Mojito is released under the MIT License.
