defmodule X1Client.ConnServer do
  @moduledoc ~S"""
  `X1Client.ConnServer` is a GenServer that handles a single
  `X1Client.Conn`.  It supports automatic connection/reconnection,
  connection keep-alive, and request pipelining.

  It's intended for usage through `X1Client` or `X1Client.Pool`.

  Example:

      >>>> {:ok, pid} = X1Client.ConnServer.start_link()
      >>>> :ok = GenServer.cast(pid, {:request, self(), :get, "http://example.com", [], "", []})
      >>>> receive do
      ...>   {:ok, response} -> response
      ...> after
      ...>   1_000 -> :timeout
      ...> end

  """

  use GenServer
  require Logger

  alias X1Client.{Conn, Response, Utils}

  @type state :: map

  @doc ~S"""
  Starts an X1Client.ConnServer.
  """
  @spec start_link(Keyword.t()) :: {:ok, pid} | {:error, any}
  def start_link(args \\ []) do
    GenServer.start_link(__MODULE__, args)
  end

  @doc ~S"""
  Initiates a request.  The `reply_to` pid will receive the response in a
  message of the format `{:ok, %X1Client.Response{}} | {:error, any}`.
  """
  @spec request(pid, pid, X1Client.method(), X1Client.headers(), String.t(), Keyword.t()) ::
          :ok | {:error, any}
  def request(pid, reply_to, method, url, headers \\ [], payload \\ "", opts \\ []) do
    GenServer.call(pid, {:request, reply_to, method, url, headers, payload, opts})
  end

  #### GenServer callbacks

  def init(_) do
    {:ok,
     %{
       conn: nil,
       protocol: nil,
       hostname: nil,
       port: nil,
       responses: %{},
       reply_tos: %{}
     }}
  end

  def terminate(reason, state) do
    Logger.debug(fn ->
      "X1Client.ConnServer #{inspect(self())}: terminating (#{inspect(reason)})"
    end)

    close_connections(state)
  end

  def handle_call({:request, reply_to, method, url, headers, payload, opts}, _from, state) do
    Logger.debug(fn -> "X1Client.ConnServer #{inspect(self())}: #{method} #{url}" end)

    with {:ok, state, _ref} <- do_request(state, reply_to, method, url, headers, payload, opts) do
      {:reply, :ok, state}
    else
      err ->
        ## TODO reconnect?
        {:reply, err, state}
    end
  end

  def handle_info({closed_msg, _port}, state)
      when closed_msg in [:tcp_closed, :ssl_closed] do
    Logger.debug(fn -> "X1Client.ConnServer #{inspect(self())}: connection closed" end)
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

  #### Helpers

  @spec close_connections(state) :: state
  defp close_connections(state) do
    Logger.debug(fn -> "X1Client.ConnServer #{inspect(self())}: cleaning up" end)

    Enum.each(state.reply_tos, fn {_request_ref, reply_to} ->
      send(reply_to, {:error, :closed})
    end)

    %{state | conn: nil, responses: %{}, reply_tos: %{}}
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
    r = Map.get(state.responses, request_ref)
    response = %{r | done: true, body: :erlang.list_to_binary(r.body)}

    reply_to = Map.get(state.reply_tos, request_ref)
    send(reply_to, {:ok, response})

    Logger.debug(fn ->
      "X1Client.ConnServer #{inspect(self())}: sent response to #{inspect(reply_to)}"
    end)

    %{
      state
      | responses: Map.delete(state.responses, request_ref),
        reply_tos: Map.delete(state.reply_tos, request_ref)
    }
  end

  @spec do_request(
          state,
          pid,
          X1Client.method(),
          String.t(),
          X1Client.headers(),
          String.t(),
          Keyword.t()
        ) :: {:ok, String.t(), reference} | {:error, any}
  defp do_request(state, reply_to, method, url, headers, payload, opts) do
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
    with {:ok, protocol, hostname, port} <- Utils.decompose_url(url) do
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


end
