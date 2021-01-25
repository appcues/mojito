defmodule Mojito.Telemetry do
  @moduledoc ~S"""
  Mojito Telemetry integration
  Thanks to team Finch for basically all of this

  [:mojito, :queue, :start]
  [:mojito, :queue, :stop]
  [:mojito, :pool, :start]
  [:mojito, :pool, :stop] # How long it took to boot the child
  [:mojito, :request, :start]
  [:mojito, :request, :stop]

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
