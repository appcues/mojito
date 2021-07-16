defmodule MojitoSyncTest do
  use ExSpec, async: false
  doctest Mojito

  context "local server tests" do
    @http_port Application.get_env(:mojito, :test_server_http_port)

    defp get(path, opts) do
      Mojito.get(
        "http://localhost:#{@http_port}#{path}",
        [],
        opts
      )
    end

    it "doesn't leak connections with pool: false" do
      original_open_ports = length(open_tcp_ports(@http_port))
      assert({:ok, response} = get("/", pool: false))
      assert(200 == response.status_code)

      final_open_ports = length(open_tcp_ports(@http_port))
      assert original_open_ports == final_open_ports
    end
  end

  defp open_tcp_ports(to_port) do
    Enum.filter(tcp_sockets(), fn socket ->
      case :inet.peername(socket) do
        {:ok, {_ip, ^to_port}} -> true
        _error -> false
      end
    end)
  end

  defp tcp_sockets() do
    Enum.filter(:erlang.ports(), fn port ->
      case :erlang.port_info(port, :name) do
        {_, 'tcp_inet'} -> true
        _ -> false
      end
    end)
  end
end
