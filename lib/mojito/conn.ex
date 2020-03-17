defmodule Mojito.Conn do
  @moduledoc false

  alias Mojito.{Error, Utils}

  defstruct conn: nil,
            protocol: nil,
            hostname: nil,
            port: nil

  @type t :: %Mojito.Conn{}

  @doc ~S"""
  Connects to the specified endpoint, returning a connection to the server.
  No requests are made.
  """
  @spec connect(String.t(), Keyword.t()) :: {:ok, t} | {:error, any}
  def connect(url, opts \\ []) do
    with {:ok, protocol, hostname, port} <- Utils.decompose_url(url) do
      connect(protocol, hostname, port, opts)
    end
  end

  @doc ~S"""
  Connects to the server specified in the given URL,
  returning a connection to the server.  No requests are made.
  """
  @spec connect(String.t(), String.t(), non_neg_integer, Keyword.t()) ::
          {:ok, t} | {:error, any}
  def connect(protocol, hostname, port, opts \\ []) do
    with {:ok, proto} <- protocol_to_atom(protocol),
         {:ok, mint_conn} <- Mint.HTTP.connect(proto, hostname, port, opts) do
      {:ok,
       %Mojito.Conn{
         conn: mint_conn,
         protocol: proto,
         hostname: hostname,
         port: port
       }}
    end
  end

  defp protocol_to_atom("http"), do: {:ok, :http}
  defp protocol_to_atom("https"), do: {:ok, :https}
  defp protocol_to_atom(:http), do: {:ok, :http}
  defp protocol_to_atom(:https), do: {:ok, :https}

  defp protocol_to_atom(proto),
    do: {:error, %Error{message: "bad protocol #{inspect(proto)}"}}

  @doc ~S"""
  Initiates a request on the given connection.  Returns the updated Conn and
  a reference to this request (which is required when receiving pipelined
  responses).
  """
  @spec request(t, Mojito.request()) :: {:ok, t, reference} | {:error, any}
  def request(conn, request) do
    with {:ok, relative_url, auth_headers} <-
           Utils.get_relative_url_and_auth_headers(request.url),
         {:ok, mint_conn, request_ref} <-
           Mint.HTTP.request(
             conn.conn,
             method_to_string(request.method),
             relative_url,
             auth_headers ++ request.headers,
             request.body
           ) do
      {:ok, %{conn | conn: mint_conn}, request_ref}
    end
  end

  defp method_to_string(m) when is_atom(m) do
    m |> to_string |> String.upcase()
  end

  defp method_to_string(m) when is_binary(m) do
    m |> String.upcase()
  end
end
