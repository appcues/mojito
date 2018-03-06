defmodule X1ClientTest do
  use ExSpec, async: true
  doctest X1Client

  context "request" do
    context "url validation" do
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

    context "live tests" do
      @port Application.get_env(:x1client, :test_server_port)

      defp get(path, opts \\ []) do
        X1Client.request(:get, "http://localhost:#{@port}#{path}", [], "", opts)
      end

      it "can make requests" do
        assert({:ok, response} = get("/"))
        assert(200 == response.status_code)
        assert("Hello world!" == response.body)
        assert("12" == X1Client.Response.get_header(response, "content-length"))
      end

      it "handles timeouts" do
        assert({:ok, _} = get("/", timeout: 50))
        assert({:error, :timeout} = get("/wait", timeout: 50))
      end
    end
  end
end
