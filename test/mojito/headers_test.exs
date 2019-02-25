defmodule Mojito.HeadersTest do
  use ExUnit.Case, async: true
  doctest Mojito.Headers
  alias Mojito.Headers

  @test_headers [
    {"header1", "value1"},
    {"header3", "value3-1"},
    {"header2", "value2"},
    {"HeaDer3", "value3-2"}
  ]

  test "Headers.get with no match" do
    assert(nil == Headers.get(@test_headers, "header0"))
  end

  test "Headers.get with case-sensitive match" do
    assert("value1" == Headers.get(@test_headers, "header1"))
    assert("value2" == Headers.get(@test_headers, "header2"))
  end

  test "Headers.get with case-insensitive match" do
    assert("value1" == Headers.get(@test_headers, "HEADER1"))
    assert("value2" == Headers.get(@test_headers, "hEaDeR2"))
  end

  test "Headers.get with multiple values" do
    assert("value3-1,value3-2" == Headers.get(@test_headers, "header3"))
  end

  test "Headers.get_values with no match" do
    assert([] == Headers.get_values(@test_headers, "header0"))
  end

  test "Headers.get_values with case-sensitive match" do
    assert(["value1"] == Headers.get_values(@test_headers, "header1"))
    assert(["value2"] == Headers.get_values(@test_headers, "header2"))
  end

  test "Headers.get_values with case-insensitive match" do
    assert(["value1"] == Headers.get_values(@test_headers, "HEADER1"))
    assert(["value2"] == Headers.get_values(@test_headers, "hEaDeR2"))
  end

  test "Headers.get_values with multiple values" do
    assert(["value3-1", "value3-2"] == Headers.get_values(@test_headers, "header3"))
  end

  test "Headers.put when value doesn't exist" do
    output = [
      {"header1", "value1"},
      {"header3", "value3-1"},
      {"header2", "value2"},
      {"HeaDer3", "value3-2"},
      {"header4", "new value"}
    ]

    assert(output == Headers.put(@test_headers, "header4", "new value"))
  end

  test "Headers.put when value exists once" do
    output = [
      {"header1", "value1"},
      {"header3", "value3-1"},
      {"HeaDer3", "value3-2"},
      {"heADer2", "new value"}
    ]

    assert(output == Headers.put(@test_headers, "heADer2", "new value"))
  end

  test "Headers.put when value exists multiple times" do
    output = [
      {"header1", "value1"},
      {"header2", "value2"},
      {"HeaDer3", "new value"}
    ]

    assert(output == Headers.put(@test_headers, "HeaDer3", "new value"))
  end

  test "Headers.delete when value doesn't exist" do
    assert(@test_headers == Headers.delete(@test_headers, "nope"))
  end

  test "Headers.delete when value exists once" do
    output = [
      {"header1", "value1"},
      {"header3", "value3-1"},
      {"HeaDer3", "value3-2"}
    ]

    assert(output == Headers.delete(@test_headers, "heADer2"))
  end

  test "Headers.delete when value exists multiple times" do
    output = [
      {"header1", "value1"},
      {"header2", "value2"}
    ]

    assert(output == Headers.delete(@test_headers, "HEADER3"))
  end

  test "Headers.keys" do
    assert(["header1", "header3", "header2"] == Headers.keys(@test_headers))
  end

  test "normalize_headers" do
    output = [
      {"header1", "value1"},
      {"header3", "value3-1,value3-2"},
      {"header2", "value2"}
    ]

    assert(output == Headers.normalize(@test_headers))
  end
end
