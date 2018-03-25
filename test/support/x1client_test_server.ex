defmodule X1Client.TestServer do
  use Application

  def start(_type, _args) do
    children = [
      Plug.Adapters.Cowboy.child_spec(
        :http,
        X1Client.TestServer.PlugRouter,
        [],
        [
          port: Application.get_env(:x1client, :test_server_http_port)
        ]
      ),
      Plug.Adapters.Cowboy.child_spec(
        :https,
        X1Client.TestServer.PlugRouter,
        [],
        [
          port: Application.get_env(:x1client, :test_server_https_port),
          keyfile: System.cwd() <> "/test/support/key.pem",
          certfile: System.cwd() <> "/test/support/cert.pem"
        ]
      )
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end

defmodule X1Client.TestServer.PlugRouter do
  use Plug.Router

  plug(:match)
  plug(:dispatch)

  get "/" do
    send_resp(conn, 200, "Hello world!")
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
