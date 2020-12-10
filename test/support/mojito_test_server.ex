defmodule Mojito.TestServer do
  use Application

  def start(_type, _args) do
    children = [
      {Plug.Cowboy,
       scheme: :http,
       plug: Mojito.TestServer.PlugRouter,
       port: Application.get_env(:mojito, :test_server_http_port)},
      {Plug.Cowboy,
       scheme: :https,
       plug: Mojito.TestServer.PlugRouter,
       port: Application.get_env(:mojito, :test_server_https_port),
       keyfile: File.cwd!() <> "/test/support/key.pem",
       certfile: File.cwd!() <> "/test/support/cert.pem"}
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end

defmodule Mojito.TestServer.PlugRouter do
  use Plug.Router

  plug(Plug.Head)

  plug(:match)

  plug(
    Plug.Parsers,
    parsers: [:json],
    pass: ["application/json"],
    json_decoder: Jason
  )

  plug(:dispatch)

  get "/" do
    name = conn.params["name"] || "world"
    send_resp(conn, 200, "Hello #{name}!")
  end

  get "/close" do
    {adapter, req} = conn.adapter

    {:ok, req} =
      :cowboy_req.reply(
        200,
        %{"connection" => "close"},
        "close",
        req
      )

    %{conn | adapter: {adapter, req}}
  end

  post "/post" do
    name = conn.body_params["name"] || "Bob"
    send_resp(conn, 200, Jason.encode!(%{name: name}))
  end

  patch "/patch" do
    name = conn.body_params["name"] || "Bob"
    send_resp(conn, 200, Jason.encode!(%{name: name}))
  end

  put "/put" do
    name = conn.body_params["name"] || "Bob"
    send_resp(conn, 200, Jason.encode!(%{name: name}))
  end

  delete "/delete" do
    send_resp(conn, 200, "")
  end

  options _ do
    conn
    |> merge_resp_headers([
      {"Allow", "OPTIONS, GET, HEAD, POST, PATCH, PUT, DELETE"}
    ])
    |> send_resp(200, "")
  end

  get "/auth" do
    ["Basic " <> auth64] = Plug.Conn.get_req_header(conn, "authorization")
    creds = auth64 |> Base.decode64!() |> String.split(":", parts: 2)
    user = creds |> Enum.at(0)
    pass = creds |> Enum.at(1)
    send_resp(conn, 200, Jason.encode!(%{user: user, pass: pass}))
  end

  get "/wait" do
    delay = (conn.params["d"] || "100") |> String.to_integer()
    :timer.sleep(delay)
    send_resp(conn, 200, "ok")
  end

  get "/wait1" do
    :timer.sleep(1000)
    send_resp(conn, 200, "ok")
  end

  get "/wait10" do
    :timer.sleep(10000)
    send_resp(conn, 200, "ok")
  end

  get "/infinite" do
    Stream.unfold(send_chunked(conn, 200), fn
      conn ->
        {:ok, conn} = chunk(conn, "bytes")
        {nil, conn}
    end)
    |> Stream.run()
  end

  @gzip_body "H4sICOnTcF4AA3Jlc3BvbnNlAKtWys9WsiopKk2t5QIAiEF/wgwAAAA="
             |> Base.decode64!()

  get "/gzip" do
    conn
    |> put_resp_header("content-encoding", "gzip")
    |> put_resp_header("content-type", "application/json")
    |> send_resp(200, @gzip_body)
  end

  @deflate_body "eJyrVsrPVrIqKSpNreUCABr+BBs=" |> Base.decode64!()

  get "/deflate" do
    conn
    |> put_resp_header("content-encoding", "deflate")
    |> put_resp_header("content-type", "application/json")
    |> send_resp(200, @deflate_body)
  end
end
