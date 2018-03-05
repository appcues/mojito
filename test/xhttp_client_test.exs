defmodule XHTTPClientTest do
  use ExUnit.Case
  doctest XHTTPClient

  test "greets the world" do
    assert XHTTPClient.hello() == :world
  end
end
