defmodule Mojito.Conn do
  @moduledoc false

  alias Mojito.Utils

  defstruct conn: nil,
            protocol: nil,
            hostname: nil,
            port: nil

  @type t :: %Mojito.Conn{}

  @doc ~S"""
  Connects to the specified endpoint, returning a connection to the server.
  No requests are made.
  """
  @spec connect(String.t()) :: {:ok, t} | {:error, any}
  def connect(url) do
    with {:ok, protocol, hostname, port} <- Utils.decompose_url(url) do
      connect(protocol, hostname, port)
    end
  end

  @doc ~S"""
  Connects to the server specified in the given URL,
  returning a connection to the server.  No requests are made.
  """
  @spec connect(String.t(), String.t(), non_neg_integer) :: {:ok, t} | {:error, any}
  def connect(protocol, hostname, port, opts \\ []) do
    with {:ok, transport} <- Utils.protocol_to_transport(protocol),
         {:ok, opts} <- configure_opts_for_transport(opts, transport),
         {:ok, xhttp1_conn} <- Mint1.Conn.connect(hostname, port, opts) do
      {:ok,
       %Mojito.Conn{
         conn: xhttp1_conn,
         protocol: protocol,
         hostname: hostname,
         port: port
       }}
    end
  end

  @spec configure_opts_for_transport(Keyword.t(), atom) :: {:ok, Keyword.t()} | {:error, any}
  defp configure_opts_for_transport(opts, :gen_tcp) do
    {:ok, opts |> Keyword.put(:transport, :gen_tcp)}
  end

  @cacerts (case File.read("./priv/cacerts.pem") do
              {:ok, certs_data} ->
                :public_key.pem_decode(certs_data)
                |> Enum.map(fn {:Certificate, bem, _} -> bem end)

              {:error, e} ->
                raise e
            end)

  defp configure_opts_for_transport(opts, :ssl) do
    transport_opts = (opts[:transport_opts] || []) ++ [cacerts: @cacerts]

    {:ok,
     opts
     |> Keyword.put(:transport, :ssl)
     |> Keyword.put(:transport_opts, transport_opts)}
  end

  @doc ~S"""
  Initiates a request on the given connection.  Returns the updated Conn and
  a reference to this request (which is required when receiving pipelined
  responses).
  """
  @spec request(t, atom, String.t(), [{String.t(), String.t()}], String.t(), Keyword.t()) ::
          {:ok, t, reference} | {:error, any}
  def request(conn, method, url, headers, payload, _opts \\ []) do
    with {:ok, relative_url, auth_headers} <- Utils.get_relative_url_and_auth_headers(url),
         {:ok, xhttp1_conn, request_ref} <-
           Mint1.Conn.request(conn.conn, method, relative_url, auth_headers ++ headers, payload) do
      {:ok, %{conn | conn: xhttp1_conn}, request_ref}
    end
  end
end
