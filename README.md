# XClient

XClient is a simplified HTTP 1.x client for Elixir, built using the
low-level [XHTTP library](https://github.com/ericmj/xhttp).

It provides an interface that will feel familiar to users of other
Elixir HTTP client libraries.

WARNING! This library currently depends on pre-release software (XHTTP).
It is not yet recommended to use XClient in production.

## Installation

Add `xclient` to your deps in `mix.exs`:

    {:xclient, "~> 0.6"}

## Single-request example

`XClient.request/5` can be used directly for making individual
requests:

    >>>> XClient.request(:get, "https://jsonplaceholder.typicode.com/posts/1")
    {:ok,
     %XClient.Response{
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

`XClient.Pool.request/6` can be used when a pool of persistent HTTP
connections is desired:

    >>>> children = [XClient.Pool.child_spec(MyPool)]
    >>>> {:ok, _pid} = Supervisor.start_link(children, strategy: :one_for_one)
    >>>> XClient.Pool.request(MyPool, :get, "http://example.com")
    {:ok, %XClient.Response{...}}

Connection pooling in XClient is implemented using
[Poolboy](https://github.com/devinus/poolboy).

## Self-signed SSL certificates

To accept self-signed SSL/TLS certificates, you can give the
`transport_opts: [verify: :verify_none]` option to `XClient.request/5`
or `XClient.Pool.request/6`:

    >>>> XClient.request(:get, "https://localhost:8443/")
    {:error, {:tls_alert, 'bad certificate'}}

    >>>> XClient.request(:get, "https://localhost:4443/, [], "", transport_opts: [verify: :verify_none])
    {:ok, %XClient.Response{...}}

## Authorship and License

Copyright 2018, Appcues, Inc.

XClient is released under the MIT License.
