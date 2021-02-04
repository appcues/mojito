defmodule Mojito.Telemetry do
  @moduledoc ~S"""
  Mojito's [Telemetry](https://github.com/beam-telemetry/telemetry)
  integration.

  Mojito emits the following Telemetry measurements:

  ```
  [:mojito, :pool, :start]
  [:mojito, :pool, :stop]

  [:mojito, :request, :start]
  [:mojito, :request, :stop]

  [:mojito, :connect, :start]
  [:mojito, :connect, :stop]
  ```

  Thanks to team Finch for basically all of this


  `request` events contain the following metadata

  ```
  %{
      url: url,
      method: method
  }
  ```

  [:mojito, :connect, :start]
  [:mojito, :connect, :stop]

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

  @typep monotonic_time :: integer

  @doc false
  @spec start(atom, map) :: monotonic_time
  def start(name, meta \\ %{}) do
    start_time = time()

    :telemetry.execute(
      [:mojito, name, :start],
      %{system_time: system_time},
      meta
    )

    start_time
  end

  @doc false
  @spec stop(atom, monotonic_time, map) :: monotonic_time
  def stop(name, start_time, meta \\ %{}) do
    stop_time = time()
    duration = stop_time - start_time

    :telemetry.execute(
      [:mojito, name, :stop],
      %{system_time: system_time(), duration: duration},
      meta
    )

    stop_time
  end

  defp time(), do: System.monotonic_time(:millisecond)
  defp system_time, do: System.system_time(:millisecond)
end
