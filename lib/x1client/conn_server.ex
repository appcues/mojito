defmodule X1Client.ConnServer do
  use GenServer
  require Logger

  alias X1Client.{Conn, Response}

  @initial_state %{
    conn: nil,
    protocol: nil,
    hostname: nil,
    port: nil,
    responses: %{},
    reply_tos: %{}
  }

  @type state :: map

  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  def init(_) do
    {:ok, @initial_state}
  end

  def handle_cast({:request, reply_to, method, url, headers, payload, opts}, state) do
    with {:ok, state, _ref} <- request(state, reply_to, method, url, headers, payload, opts) do
      {:noreply, state}
    else
      err -> {:noreply, state}
    end
  end

  def handle_info({closed_msg, _port} = msg, state)
      when closed_msg in [:tcp_closed, :ssl_closed] do
    {:noreply, close_connections(state)}
  end

  def handle_info(msg, state) do
    case XHTTP1.Conn.stream(state.conn.conn, msg) do
      {:ok, xhttp1_conn, resps} ->
        state_conn = state.conn |> Map.put(:conn, xhttp1_conn)
        state = %{state | conn: state_conn}
        {:noreply, apply_resps(state, resps)}

      {:error, _xhttp1_conn, :closed} ->
        {:noreply, close_connections(state)}

      other ->
        Logger.error(fn -> "got unknown message: #{inspect(other)}" end)
        raise RuntimeError
    end
  end

  @spec close_connections(state) :: state
  defp close_connections(state) do
    Enum.each(state.reply_tos, fn reply_to ->
      send(reply_to, {:error, :closed})
    end)

    %{state |
      conn: nil,
      responses: %{},
      reply_tos: %{}
    }
  end

  defp apply_resps(state, []), do: state

  defp apply_resps(state, [resp | rest]) do
    apply_resp(state, resp) |> apply_resps(rest)
  end

  defp apply_resp(state, {:status, request_ref, status}) do
    response = Map.get(state.responses, request_ref)
    response = response |> Map.put(:status_code, status)
    %{state | responses: Map.put(state.responses, request_ref, response)}
  end

  defp apply_resp(state, {:headers, request_ref, headers}) do
    response = Map.get(state.responses, request_ref)
    response = response |> Map.put(:headers, headers)
    %{state | responses: Map.put(state.responses, request_ref, response)}
  end

  defp apply_resp(state, {:data, request_ref, chunk}) do
    response = Map.get(state.responses, request_ref)
    response = response |> Map.put(:body, [response.body | [chunk]])
    %{state | responses: Map.put(state.responses, request_ref, response)}
  end

  defp apply_resp(state, {:done, request_ref}) do
    response = Map.get(state.responses, request_ref)
    body = :erlang.list_to_binary(response.body)
    response = %{response | done: true, body: body}
    send(Map.get(state.reply_tos, request_ref), {:ok, response})

    %{
      state
      | responses: Map.delete(state.responses, request_ref),
        reply_tos: Map.delete(state.reply_tos, request_ref)
    }
  end

  @spec request(
          state,
          pid,
          X1Client.method(),
          String.t(),
          X1Client.headers(),
          String.t(),
          Keyword.t()
        ) :: {:ok, String.t(), reference} | {:error, any}
  defp request(state, reply_to, method, url, headers, payload, opts) do
    with {:ok, state} <- ensure_connection(state, url),
         {:ok, conn, request_ref} <- Conn.request(state.conn, method, url, headers, payload, opts) do
      responses = state.responses |> Map.put(request_ref, %Response{})
      reply_tos = state.reply_tos |> Map.put(request_ref, reply_to)
      state = %{state | conn: conn, responses: responses, reply_tos: reply_tos}

      {:ok, state, request_ref}
    end
  end

  @spec ensure_connection(state, String.t()) :: {:ok, state} | {:error, any}
  defp ensure_connection(state, url) do
    with {:ok, protocol, hostname, port} <- decompose_url(url) do
      new_destination =
        state.protocol != protocol || state.hostname != hostname || state.port != port

      cond do
        !state.conn || new_destination ->
          connect(state, protocol, hostname, port)

        :else ->
          {:ok, state}
      end
    end
  end

  @spec connect(state, String.t(), String.t(), non_neg_integer) :: {:ok, state} | {:error, any}
  defp connect(state, protocol, hostname, port) do
    with {:ok, conn} <- X1Client.Conn.connect(protocol, hostname, port) do
      {:ok, %{state | conn: conn, protocol: protocol, hostname: hostname, port: port}}
    end
  end

  @url_regex ~r"
    (?<protocol> https?)
    ://
    (?<hostname> [^:/]+)
    :?
    (?<port> \d+)?
  "xi
  @spec decompose_url(String.t()) :: {:ok, String.t(), String.t(), String.t()} | {:error, any}
  defp decompose_url(url) do
    case Regex.named_captures(@url_regex, url) do
      nil ->
        {:error, "could not parse url #{url}"}

      nc ->
        protocol = String.downcase(nc["protocol"])

        port =
          nc["port"] ||
            case protocol do
              "https" -> "443"
              "http" -> "80"
            end

        {:ok, protocol, nc["hostname"], String.to_integer(port)}
    end
  end


end
