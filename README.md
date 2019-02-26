<img align="right" width="131" height="225" src="assets/mojito.png?raw=true">

# Mojito [![Build Status](https://travis-ci.org/appcues/mojito.svg?branch=master)](https://travis-ci.org/appcues/mojito) [![Hex.pm Version](http://img.shields.io/hexpm/v/mojito.svg?style=flat)](https://hex.pm/packages/mojito)

Mojito is a simplified HTTP client for Elixir, built using the
low-level [Mint client](https://github.com/ericmj/mint).

It provides an interface that will feel familiar to users of other
Elixir HTTP client libraries.

HTTPS, one-off requests, connection pooling, and request pipelining are
supported out of the box.

## Installation

Add `mojito` to your deps in `mix.exs`:

    {:mojito, "~> 0.1.0"}

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

## Authorship and License

Copyright 2018-2019, Appcues, Inc.

Mojito is released under the MIT License.
