# Changelog

## 0.5.0 (2018-08-21)

Fixed bug where timed-out responses would arrive in connection with
the next request from that caller.  Thanks for the report and the
test case, [@seanedwards](https://github.com/seanedwards)!

Refactored to use `%Mojito.Request{}` structs more consistently across
internal Mojito functions.

## 0.4.0 (2019-08-13)

Upgraded to Mint 0.4.0.

Requests are automatically retried when we attempt to reuse a closed
connection.

Added `Mojito.Headers.auth_header/2` helper for formintg HTTP Basic
`Authorization` header.

Don't pass the URL fragment to Mint when making requests.
Thanks [@alappe](https://github.com/alappe)!

Improved examples and docs around making POST requests.
Thanks [@hubertlepicki](https://github.com/hubertlepicki)!

Removed noisy debug output.
Thanks for the report, [@bcardarella](https://github.com/bcardarella)!

## 0.3.0 (2019-05-08)

Major refactor.

All end-user requests pass through `Mojito.request/1`, which now
accepts keyword list input as well.  `Mojito.request/5` remains
as an alias, and convenience methods for `get/3`, `post/4`, `put/4`,
`patch/4`, `delete/3`, `head/3`, and `options/3` have been added
(thanks, [@danhuynhdev](https://github.com/danhuynhdev)!).

Connection pools are handled automatically, sorting requests to the
correct pools, starting pools when necessary, and maintaining
multiple redundant pools for GenServer efficiency.

## 0.2.2 (2019-04-26)

Fixed a bug where long requests could exceed the given timeout without
failing (#17).  Thanks for the report,
[@mischov](https://github.com/mischov)!

Improved documentation about receiving `:tcp` and `:ssl` messages.
Thanks for the report,
[@axelson](https://github.com/axelson)!

Removed an extra `Task` process creation in `Mojito.Pool.request/2`.

## 0.2.1 (2019-04-23)

Refactored `Mojito.request/5` so it doesn't spawn a process.  Now all
TCP messages are handled within the caller process.

Added `Mojito.request/1` and `Mojito.Pool.request/2`, which accept a
`%Mojito.Request{}` struct as input.

Removed dependency on Fuzzyurl in favor of built-in URI module.

## 0.2.0 (2019-04-19)

Messages sent by Mojito now contain a `:mojito_response` prefix, to allow
processes to select or ignore these messages with `receive`.
Thanks [@AnilRedshift](https://github.com/AnilRedshift)!

Upgraded to Mint 0.2.0.

## 0.1.1 (2019-03-28)

`request/5` emits better error messages when confronted with nil or blank
method or url.  Thanks [@AnilRedshift](https://github.com/AnilRedshift)!

## 0.1.0 (2019-02-25)

Initial release, based on [Mint](https://github.com/ericmj/mint) 0.1.0.

