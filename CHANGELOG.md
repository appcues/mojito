# Changelog

## O.2.0 (2019-04-19)

Messages sent by Mojito now contain a `:mojito_response` prefix, to allow
processes to select or ignore these messages with `receive`.
Thanks [@AnilRedshift](https://github.com/AnilRedshift)!

Upgraded to Mint 0.2.0.

## 0.1.1 (2019-03-28)

`request/5` emits better error messages when confronted with nil or blank
method or url.  Thanks [@AnilRedshift](https://github.com/AnilRedshift)!

## 0.1.0 (2019-02-25)

Initial release, based on [Mint](https://github.com/ericmj/mint) 0.1.0.

