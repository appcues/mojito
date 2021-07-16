# Changelog

## 0.7.8 (2021-07-16)

Fixed a few bugs around connection handling and chunk sizing. Thanks to
[@reisub](https://github.com/reisub), [@fahchen](https://github.com/fahchen),
[@bmteller](https://github.com/bmteller).

## 0.7.7 (2021-02-04)

Added Mojito.Telemetry. Thanks,
[@andyleclair](https://github.com/andyleclair)! And thanks to the
[Finch](https://github.com/keathley/finch) team, whose telemetry
implementation informed this one.

## 0.7.6 (2020-12-10)

Fixed a bug around HTTP/2 responses larger than 64kB. Thanks for the
reports, [@dch](https://github.com/dch) and
[@jayjun](https://github.com/jayjun)!

Reduced memory footprint of idle Mojito pools by forcing GC after
requests complete. Thanks for the reports,
[@axelson](https://github.com/axelson) and
[@hubertlepicki](https://github.com/hubertlepicki)!

## 0.7.5 (2020-11-06)

Fixed packaging bug in 0.7.4.

## 0.7.4 (2020-11-02)

Fixed handling of Mint error responses.
Thanks, [@alexandremcosta](https://github.com/alexandremcosta)!

Fixed a Dialyzer warning around keyword lists.
Thanks, [@Vaysman](https://github.com/Vaysman)!

## 0.7.3 (2020-06-22)

Moved core Mojito functions into separate `Mojito.Base` module for
easier interoperation with mocking libraries like Mox. Thanks,
[@bcardarella](https://github.com/bcardarella)!

## 0.7.2 (2020-06-19)

Fixed typespecs.

## 0.7.1 (2020-06-17)

Fixed bug where Mojito failed to correctly handle responses with
a `connection: close` header. Thanks,
[@bmteller](https://github.com/bmteller)!

## 0.7.0 (2020-06-17)

Added the `:max_body_size` option, to prevent a response body from
growing too large. Thanks, [@rozap](https://github.com/rozap)!

## 0.6.4 (2020-05-20)

Fixed bug where sending an empty string request body would hang certain
HTTP/2 requests. Thanks for the report,
[@Overbryd](https://github.com/Overbryd)!

## 0.6.3 (2020-03-17)

`gzip`ped or `deflate`d responses are automatically expanded by
Mojito. Thanks, [@mogorman](https://github.com/mogorman)!

The Freedom Formatter has been removed. `mix format` is now applied.

## 0.6.2 (2020-03-11)

Header values are now stringified on their way to Mint. Thanks,
[@egze](https://github.com/egze)!

Timeouts of `:infinity` are now supported. Thanks,
[@t8rsalad](https://github.com/t8rsalad)!

## 0.6.1 (2019-12-20)

Internal refactor to support different pool implementations. No features
were added or changed.

Code formatting improvements in docs. Thanks,
[@sotojuan](https://github.com/sotojuan)!

## 0.6.0 (2019-11-02)

Upgraded to Mint 1.0. Thanks, [@esvinson](https://github.com/esvinson)!

Fixed typo in CHANGELOG. Thanks, [@alappe](https://github.com/alappe)!

## 0.5.0 (2019-08-21)

Fixed bug where timed-out responses could arrive in connection with
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

