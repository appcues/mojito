Logger.remove_backend(:console)

Mojito.TestServer.start([], [])

if System.get_env("SLOW_TESTS"), do: :timer.sleep(1000)

ExUnit.start()
