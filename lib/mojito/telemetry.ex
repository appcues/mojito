defmodule Mojito.Telemetry do
  @moduledoc ~S"""
  Mojito Telemetry integration
  Thanks to team Finch for basically all of this

  Mojito executes the following events:
  [:mojito, :pool, :start]
  [:mojito, :pool, :stop]

  `pool` events contain the `pool_key` metadata

  [:mojito, :request, :start]
  [:mojito, :request, :stop]

  `request` events contain the following metadata

  ```
  %{
      url: url,
      method: method
  }
  ```

  [:mojito, :connection, :start]
  [:mojito, :connection, :stop]

  `connection` events contain the following metadata

  ```
  %{
    hostname: hostname,
    protocol: protocol,
    port: port
  }

  `start` events will contain the `system_time` measurements, and `stop` events
  will contain the `system_time` as well as the `duration` between `start` and `stop`
  """

  def start(name, meta \\ %{}) do
    start_time = time()

    :telemetry.execute(
      [:mojito, name, :start],
      %{system_time: start_time},
      meta
    )

    start_time
  end

  def stop(name, start_time, meta \\ %{}) do
    stop_time = time()
    duration = stop_time - start_time

    :telemetry.execute(
      [:mojito, name, :stop],
      %{system_time: stop_time, duration: duration},
      meta
    )

    stop_time
  end

  defp time(), do: System.monotonic_time(:millisecond)
end
