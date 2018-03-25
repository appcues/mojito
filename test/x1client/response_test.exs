defmodule XClient.ResponseTest do
  use ExSpec, async: true
  doctest XClient.Response

  import XClient.Response

  @headers [
    {"content-length", "222"},
    {"content-type", "application/json"},
    {"server", "cowpoke/0.22.0"}
  ]

  @response %XClient.Response{headers: @headers}

  context "get_headers" do
    it "works on response" do
      assert("222" == get_header(@response, "content-length"))
      assert("application/json" == get_header(@response, "content-type"))
      assert(nil == get_header(@response, "missing"))
    end

    it "works on headers" do
      assert("222" == get_header(@headers, "content-length"))
      assert("application/json" == get_header(@headers, "content-type"))
      assert(nil == get_header(@headers, "missing"))
    end

    it "tolerates mixed case" do
      assert("222" == get_header(@headers, "Content-Length"))
      assert("application/json" == get_header(@headers, "CONTENT-TYPE"))
    end
  end
end
