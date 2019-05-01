use Mix.Config

config :mojito,
  test_server_http_port: 18999,
  test_server_https_port: 18443,
  pool_opts: [
    size: 2,
    max_overflow: 2,
    max_pools: 5,
    destinations: [
      "localhost:18443": [
        max_pools: 10,
      ],
    ],
  ]
