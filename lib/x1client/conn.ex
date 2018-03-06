defmodule X1Client.Conn do
  @moduledoc ~S"""
  `X1Client.Conn` provides a lower-level API than `X1Client`, yet
  still higher-level than XHTTP.  It is intended for usage where
  greater control of the network socket is desired (e.g., connection
  pooling).
  """

  alias X1Client.Response

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
    with {:ok, protocol, hostname, port} <- decompose_url(url),
         {:ok, transport} <- protocol_to_transport(protocol),
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
          {:ok, t, reference} | {:error, any}
  def request(conn, method, url, headers, payload, _opts \\ []) do
    with {:ok, relative_url} <- make_relative_url(url),
         {:ok, xhttp1_conn, _request_ref} <-
           XHTTP1.Conn.request(conn.conn, method, relative_url, headers, payload) do
      {:ok, %{conn | conn: xhttp1_conn}}
    end
  end

  @doc ~S"""
  Handles the streaming of the response body in
  TCP/SSL active mode, stopping when the response is complete (generally
  when we've received as much data as the Content-length response header
  claimed).

  These messages are received in the caller process, so take care to
  execute this in a process where there are no other message-senders.

  `opts[:timeout]` may be used to provide a request timeout (in milliseconds).
  """
  @spec stream_response(t, Keyword.t()) :: {:ok, t, %Response{}} | {:error, any}

  def stream_response(conn, opts \\ []) do
    with {:ok, xhttp1_conn, response} <- do_stream_response(conn.conn, %Response{}, opts) do
      {:ok, %{conn | conn: xhttp1_conn}, response}
    end
  end

  @spec do_stream_response(XHTTP1.Conn.t(), %Response{}, Keyword.t()) ::
          {:ok, t, %Response{}} | {:error, any}

  defp do_stream_response(conn, %{done: true} = response, _opts), do: {:ok, conn, response}

  defp do_stream_response(conn, response, opts) do
    timeout = opts[:timeout] || @request_timeout

    receive do
      tcp_message ->
        case XHTTP1.Conn.stream(conn, tcp_message) do
          {:ok, conn, resps} ->
            do_stream_response(conn, build_response(response, resps), opts)

          other ->
            other
        end
    after
      timeout -> {:error, :timeout}
    end
  end

  @doc ~S"""
  Returns whether a connection is still open.
  """
  @spec open?(t) :: {:ok, boolean}
  def open?(conn), do: {:ok, XHTTP1.Conn.open?(conn.conn)}

  @doc ~S"""
  Returns true if the connection matches the protocol, hostname, and port
  in the given url.
  """
  @spec matches?(t, String.t()) :: {:ok, boolean} | {:error, any}
  def matches?(conn, url) do
    with {:ok, protocol, hostname, port} <- decompose_url(url) do
      is_match = protocol == conn.protocol && hostname == conn.hostname && port == conn.port

      {:ok, is_match}
    end
  end

  ## `build_response/2` adds streamed response chunks from XHTTP1 into
  ## an `%X1Client.Response{}` map.

  @spec build_response(%Response{}, [XHTTP1.Conn.response()]) :: %Response{}

  defp build_response(response, []), do: response

  defp build_response(response, [chunk | rest]) do
    response =
      case chunk do
        {:status, _request_ref, status} ->
          %{response | status_code: status}

        {:headers, _request_ref, headers} ->
          # TODO clean up header format into map
          %{response | headers: headers}

        {:data, _request_ref, chunk} ->
          %{response | body: [response.body | [chunk]]}

        {:done, _request_ref} ->
          body = :erlang.list_to_binary(response.body)
          %{response | done: true, body: body}
      end

    build_response(response, rest)
  end

  ## `decompose_url/1` extracts the protocol, host, and port from a web URL.

  defp decompose_url(url) do
    fu = Fuzzyurl.from_string(url)

    port =
      cond do
        fu.port -> String.to_integer(fu.port)
        fu.protocol == "https" -> 443
        fu.protocol == "http" -> 80
        String.downcase(to_string(fu.protocol)) == "https" -> 443
        String.downcase(to_string(fu.protocol)) == "http" -> 80
        :else -> nil
      end

    cond do
      !fu.protocol -> {:error, "protocol missing from url"}
      !fu.hostname -> {:error, "hostname missing from url"}
      !port -> {:error, "could not determine port for url"}
      :else -> {:ok, fu.protocol, fu.hostname, port}
    end
  end

  ## `make_relative_url/1` strips the protocol, hostname, and port from
  ## a web URL, returning the path (always starting with a slash).

  defp make_relative_url("http://" <> rest), do: {:ok, get_path(rest)}

  defp make_relative_url("https://" <> rest), do: {:ok, get_path(rest)}

  defp make_relative_url(url), do: {:error, "could not make url relative: #{url}"}

  defp get_path(url_without_protocol) do
    "/" <>
      case String.split(url_without_protocol, "/", parts: 2) do
        [_hostname, path] -> path
        _ -> ""
      end
  end

  ## `protocol_to_transport/1` returns the correct Erlang TCP transport
  ## module for the given protocol.

  defp protocol_to_transport("http"), do: {:ok, :gen_tcp}

  defp protocol_to_transport("https"), do: {:ok, :ssl}

  defp protocol_to_transport(other), do: {:error, "protocol not recognized: #{other}"}
end
