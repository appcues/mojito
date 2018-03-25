defmodule XClientTest do
  use ExSpec, async: true
  doctest XClient
  doctest XClient.Utils

  context "request" do
    context "url validation" do
      it "fails on url without protocol" do
        assert({:error, _} = XClient.request(:get, "localhost/path"))
        assert({:error, _} = XClient.request(:get, "/localhost/path"))
        assert({:error, _} = XClient.request(:get, "//localhost/path"))
        assert({:error, _} = XClient.request(:get, "localhost//path"))
      end

      it "fails on url with bad protocol" do
        assert({:error, _} = XClient.request(:get, "garbage://localhost/path"))
        assert({:error, _} = XClient.request(:get, "ftp://localhost/path"))
      end

      it "fails on url without hostname" do
        assert({:error, _} = XClient.request(:get, "http://"))
      end
    end

    context "local server tests" do
      @http_port Application.get_env(:xclient, :test_server_http_port)
      @https_port Application.get_env(:xclient, :test_server_https_port)

      defp get(path, opts \\ []) do
        XClient.request(:get, "http://localhost:#{@http_port}#{path}", [], "", opts)
      end

      defp get_ssl(path, opts \\ []) do
        XClient.request(
          :get,
          "https://localhost:#{@https_port}#{path}",
          [],
          "",
          [transport_opts: [verify: :verify_none]] ++ opts
        )
      end

      it "can make HTTP requests" do
        assert({:ok, response} = get("/"))
        assert(200 == response.status_code)
        assert("Hello world!" == response.body)
        assert("12" == XClient.Response.get_header(response, "content-length"))
      end

      it "can make HTTPS requests" do
        assert({:ok, response} = get_ssl("/"))
        assert(200 == response.status_code)
        assert("Hello world!" == response.body)
        assert("12" == XClient.Response.get_header(response, "content-length"))
      end

      it "handles timeouts" do
        assert({:ok, _} = get("/", timeout: 100))
        assert({:error, :timeout} = get("/wait1", timeout: 100))
      end
    end

    context "external tests" do
      it "can make HTTPS requests using proper cert chain by default" do
        assert({:ok, _} = XClient.request(:get, "https://github.com"))
      end
    end
  end
end
