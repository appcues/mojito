defmodule MojitoTest do
  use ExSpec, async: true
  doctest Mojito
  doctest Mojito.Utils

  alias Mojito.{Error, Headers}

  context "request" do
    context "url validation" do
      it "fails on url without protocol" do
        assert({:error, _} = Mojito.request(:get, "localhost/path"))
        assert({:error, _} = Mojito.request(:get, "/localhost/path"))
        assert({:error, _} = Mojito.request(:get, "//localhost/path"))
        assert({:error, _} = Mojito.request(:get, "localhost//path"))
      end

      it "fails on url with bad protocol" do
        assert({:error, _} = Mojito.request(:get, "garbage://localhost/path"))
        assert({:error, _} = Mojito.request(:get, "ftp://localhost/path"))
      end

      it "fails on url without hostname" do
        assert({:error, _} = Mojito.request(:get, "http://"))
      end

      it "fails on blank url" do
        assert({:error, err} = Mojito.request(:get, ""))
        assert(is_binary(err.message))
      end

      it "fails on nil url" do
        assert({:error, err} = Mojito.request(:get, nil))
        assert(is_binary(err.message))
      end
    end

    context "method validation" do
      it "fails on blank method" do
        assert({:error, err} = Mojito.request("", "https://cool.com"))
        assert(is_binary(err.message))
      end

      it "fails on nil method" do
        assert({:error, err} = Mojito.request(nil, "https://cool.com"))
        assert(is_binary(err.message))
      end
    end

    context "local server tests" do
      @http_port Application.get_env(:mojito, :test_server_http_port)
      @https_port Application.get_env(:mojito, :test_server_https_port)

      defp get(path, opts \\ []) do
        Mojito.request(
          :get,
          "http://localhost:#{@http_port}#{path}",
          [],
          "",
          opts
        )
      end

      defp get_with_user(path, user, opts \\ []) do
        Mojito.request(
          :get,
          "http://#{user}@localhost:#{@http_port}#{path}",
          [],
          "",
          opts
        )
      end

      defp get_with_user_and_pass(path, user, pass, opts \\ []) do
        Mojito.request(
          :get,
          "http://#{user}:#{pass}@localhost:#{@http_port}#{path}",
          [],
          "",
          opts
        )
      end

      defp post(path, body_obj, opts \\ []) do
        body = Jason.encode!(body_obj)
        headers = [{"content-type", "application/json"}]

        Mojito.request(
          :post,
          "http://localhost:#{@http_port}#{path}",
          headers,
          body,
          opts
        )
      end

      defp get_ssl(path, opts \\ []) do
        Mojito.request(
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
        assert("12" == Headers.get(response.headers, "content-length"))
      end

      it "can make HTTPS requests" do
        assert({:ok, response} = get_ssl("/"))
        assert(200 == response.status_code)
        assert("Hello world!" == response.body)
        assert("12" == Headers.get(response.headers, "content-length"))
      end

      it "handles timeouts" do
        assert({:ok, _} = get("/", timeout: 100))
        assert({:error, %Error{reason: :timeout}} = get("/wait1", timeout: 100))
      end

      it "handles timeouts even on long requests" do
        port = Application.get_env(:mojito, :test_server_http_port)
        {:ok, conn} = Mojito.Conn.connect("http://localhost:#{port}")

        mint_conn =
          Map.put(conn.conn, :request, %{
            ref: nil,
            state: :status,
            method: :get,
            version: nil,
            status: nil,
            headers_buffer: [],
            content_length: nil,
            connection: [],
            transfer_encoding: [],
            body: nil,
          })

        conn = %{conn | conn: mint_conn}

        pid = self()

        spawn(fn ->
          socket = conn.conn.socket
          Process.sleep(30)
          send(pid, {:tcp, socket, "HTTP/1.1 200 OK\r\nserver: Cowboy"})
          Process.sleep(30)
          send(pid, {:tcp, socket, "\r\ndate: Thu, 25 Apr 2019 10:48:25"})
          Process.sleep(30)
          send(pid, {:tcp, socket, " GMT\r\ncontent-length: 12\r\ncache-"})
          Process.sleep(30)
          send(pid, {:tcp, socket, "control: max-age=0, private, must-"})
          Process.sleep(30)
          send(pid, {:tcp, socket, "revalidate\r\n\r\nHello world!"})
        end)

        assert(
          {:error, %{reason: :timeout}} =
            Mojito.Request.Single.receive_response(
              conn,
              %Mojito.Response{},
              100
            )
        )
      end

      it "handles URL query params" do
        assert({:ok, %{body: "Hello Alice!"}} = get("/?name=Alice"))
        assert({:ok, %{body: "Hello Alice!"}} = get("?name=Alice"))
      end

      it "can post data" do
        assert({:ok, response} = post("/post", %{name: "Charlie"}))
        resp_body = response.body |> Jason.decode!()
        assert("Charlie" == resp_body["name"])
      end

      it "handles user+pass in URL" do
        assert({:ok, %{status_code: 500}} = get("/auth"))

        assert(
          {:ok, %{status_code: 200} = response} = get_with_user("/auth", "hi")
        )

        assert(%{"user" => "hi", "pass" => nil} = Jason.decode!(response.body))

        assert(
          {:ok, %{status_code: 200} = response} =
            get_with_user_and_pass("/auth", "hi", "mom")
        )

        assert(
          %{"user" => "hi", "pass" => "mom"} = Jason.decode!(response.body)
        )
      end
    end

    context "external tests" do
      it "can make HTTPS requests using proper cert chain by default" do
        assert({:ok, _} = Mojito.request(:get, "https://github.com"))
      end
    end
  end
end
