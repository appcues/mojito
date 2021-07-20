defmodule Mojito do
  @external_resource "README.md"
  @moduledoc File.read!("README.md")
             |> String.split(~r/<!-- MDOC !-->/)
             |> Enum.fetch!(1)

  use Mojito.Base
end
