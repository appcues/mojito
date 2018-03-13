defmodule X1Client.Conn do
  @moduledoc ~S"""
  `X1Client.Conn` provides a lower-level API than `X1Client`, yet
  still higher-level than XHTTP.  It is intended for usage where
  greater control of the network socket is desired (e.g., connection
  pooling).
  """

  alias X1Client.{Response, Utils}

  @request_timeout Application.get_env(:x1client, :request_timeout, 5000)

  defstruct conn: nil,
            protocol: nil,
            hostname: nil,
            port: nil

  @type t :: %X1Client.Conn{}

  @doc ~S"""
  Connects to the server specified in the given URL,
  returning a connection to the server.  No requests are made.
  """
  @spec connect(String.t()) :: {:ok, t} | {:error, any}
  def connect(url) do
    with {:ok, protocol, hostname, port} <- Utils.decompose_url(url) do
      connect(protocol, hostname, port)
    end
  end

  @spec connect(String.t(), String.t(), non_neg_integer) :: {:ok, t} | {:error, any}
  def connect(protocol, hostname, port) do
    with {:ok, transport} <- Utils.protocol_to_transport(protocol),
         {:ok, xhttp1_conn} <- XHTTP1.Conn.connect(hostname, port, transport: transport) do
      {:ok,
       %X1Client.Conn{
         conn: xhttp1_conn,
         protocol: protocol,
         hostname: hostname,
         port: port
       }}
    end
  end

  @doc ~S"""
  Initiates a request on the given connection.
  """
  @spec request(t, atom, String.t(), [{String.t(), String.t()}], String.t(), Keyword.t()) ::
          {:ok, t} | {:error, any}
  def request(conn, method, url, headers, payload, _opts \\ []) do
    with {:ok, relative_url} <- Utils.make_relative_url(url),
         {:ok, xhttp1_conn, request_ref} <-
           XHTTP1.Conn.request(conn.conn, method, relative_url, headers, payload) do
      {:ok, %{conn | conn: xhttp1_conn}, request_ref}
    end
  end
end
