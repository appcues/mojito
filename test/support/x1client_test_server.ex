defmodule X1Client.TestServer do
  use Application

  def start(_type, _args) do
    port = Application.get_env(:x1client, :test_server_port)

    children = [
      Plug.Adapters.Cowboy.child_spec(:http, X1Client.TestServer.PlugRouter, [], port: port)
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

  get "/wait" do
    :timer.sleep(1000)
    send_resp(conn, 200, "ok")
  end
end
