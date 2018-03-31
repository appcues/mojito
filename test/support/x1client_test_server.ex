defmodule XClient.TestServer do
  use Application

  def start(_type, _args) do
    children = [
      Plug.Adapters.Cowboy.child_spec(
        :http,
        XClient.TestServer.PlugRouter,
        [],
        port: Application.get_env(:xclient, :test_server_http_port)
      ),
      Plug.Adapters.Cowboy.child_spec(
        :https,
        XClient.TestServer.PlugRouter,
        [],
        port: Application.get_env(:xclient, :test_server_https_port),
        keyfile: System.cwd() <> "/test/support/key.pem",
        certfile: System.cwd() <> "/test/support/cert.pem"
      )
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end

defmodule XClient.TestServer.PlugRouter do
  use Plug.Router

  plug(:match)
  plug(Plug.Parsers, parsers: [:json], pass: ["application/json"], json_decoder: Jason)
  plug(:dispatch)

  get "/" do
    name = conn.params["name"] || "world"
    send_resp(conn, 200, "Hello #{name}!")
  end

  post "/post" do
    name = conn.body_params["name"] || "Bob"
    send_resp(conn, 200, Jason.encode!(%{name: name}))
  end

  get "/auth" do
    ["Basic " <> auth64] = Plug.Conn.get_req_header(conn, "authorization")
    creds = auth64 |> Base.decode64!() |> String.split(":", parts: 2)
    user = creds |> Enum.at(0)
    pass = creds |> Enum.at(1)
    send_resp(conn, 200, Jason.encode!(%{user: user, pass: pass}))
  end

  get "/wait" do
    delay = (conn.params["d"] || "100") |> String.to_integer
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
end
