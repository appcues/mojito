defmodule X1ClientTest do
  use ExSpec, async: true
  doctest X1Client

  context "request" do
    it "fails on url without protocol" do
      assert({:error, _} = X1Client.request(:get, "localhost/path"))
      assert({:error, _} = X1Client.request(:get, "/localhost/path"))
      assert({:error, _} = X1Client.request(:get, "//localhost/path"))
      assert({:error, _} = X1Client.request(:get, "localhost//path"))
    end

    it "fails on url with bad protocol" do
      assert({:error, _} = X1Client.request(:get, "garbage://localhost/path"))
      assert({:error, _} = X1Client.request(:get, "ftp://localhost/path"))
    end

    it "fails on url without hostname" do
      assert({:error, _} = X1Client.request(:get, "http://"))
    end
  end
end
