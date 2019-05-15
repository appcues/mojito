defmodule Mojito.ConnServer do
  @moduledoc false

  use GenServer
  require Logger

  alias Mojito.{Conn, Response, Utils}

  @type state :: map

  @doc ~S"""
  Starts a `Mojito.ConnServer`.

  `Mojito.ConnServer` is a GenServer that handles a single
  `Mojito.Conn`.  It supports automatic reconnection,
  connection keep-alive, and request pipelining.

  It's intended for usage through `Mojito.Pool`.

  Example:

      {:ok, pid} = Mojito.ConnServer.start_link()
      :ok = GenServer.cast(pid, {:request, self(), :get, "http://example.com", [], "", []})
      receive do
        {:ok, response} -> response
      after
        1_000 -> :timeout
      end
  """
  @spec start_link(Keyword.t()) :: {:ok, pid} | {:error, any}
  def start_link(args \\ []) do
    GenServer.start_link(__MODULE__, args)
  end

  @doc ~S"""
  Initiates a request.  The `reply_to` pid will receive the response in a
  message of the format `{:ok, %Mojito.Response{}} | {:error, any}`.
  """
  @spec request(
          pid,
          pid,
          Mojito.method(),
          Mojito.headers(),
          String.t(),
          Keyword.t()
        ) :: :ok | {:error, any}
  def request(
        pid,
        reply_to,
        method,
        url,
        headers \\ [],
        body \\ "",
        opts \\ []
      ) do
    GenServer.call(
      pid,
      {:request, reply_to, method, url, headers, body, opts}
    )
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
       reply_tos: %{},
     }}
  end

  def terminate(reason, state) do
    Logger.debug(fn ->
      "Mojito.ConnServer #{inspect(self())}: terminating (#{inspect(reason)})"
    end)

    close_connections(state)
  end

  def handle_call(
        {:request, reply_to, method, url, headers, body, opts},
        _from,
        state
      ) do
    Logger.debug(fn ->
      "Mojito.ConnServer #{inspect(self())}: #{method} #{url}"
    end)

    with {:ok, state, _ref} <-
           do_request(state, reply_to, method, url, headers, body, opts) do
      {:reply, :ok, state}
    else
      err -> {:reply, err, close_connections(state)}
    end
  end

  ## `msg` is an incoming chunk of a response
  def handle_info(msg, state) do
    Logger.debug(fn ->
      "Mojito.ConnServer #{inspect(self())}: received TCP data #{inspect(msg)}"
    end)

    if !state.conn do
      {:noreply, close_connections(state)}
    else
      case Mint.HTTP.stream(state.conn.conn, msg) do
        {:ok, mint_conn, resps} ->
          state_conn = state.conn |> Map.put(:conn, mint_conn)
          state = %{state | conn: state_conn}
          {:noreply, apply_resps(state, resps)}

        {:error, _mint_conn, _error, _resps} ->
          {:noreply, close_connections(state)}

        :unknown ->
          {:noreply, state}
      end
    end
  end

  #### Helpers

  @spec close_connections(state) :: state
  defp close_connections(state) do
    Logger.debug(fn -> "Mojito.ConnServer #{inspect(self())}: cleaning up" end)

    Enum.each(state.reply_tos, fn {_request_ref, reply_to} ->
      respond(reply_to, {:error, :closed})
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
    response = %{r | complete: true, body: :erlang.list_to_binary(r.body)}

    Map.get(state.reply_tos, request_ref)
    |> respond({:ok, response})

    %{
      state
      | responses: Map.delete(state.responses, request_ref),
        reply_tos: Map.delete(state.reply_tos, request_ref),
    }
  end

  defp respond(pid, message) do
    send(pid, {:mojito_response, message})

    Logger.debug(fn ->
      "Mojito.ConnServer #{inspect(self())}: sent response to #{inspect(pid)}"
    end)
  end

  @spec do_request(
          state,
          pid,
          Mojito.method(),
          String.t(),
          Mojito.headers(),
          String.t(),
          Keyword.t()
        ) :: {:ok, state, reference} | {:error, any}
  defp do_request(state, reply_to, method, url, headers, body, opts) do
    with {:ok, state} <- ensure_connection(state, url, opts),
         {:ok, conn, request_ref} <-
           Conn.request(state.conn, method, url, headers, body, opts) do
      responses = state.responses |> Map.put(request_ref, %Response{body: []})
      reply_tos = state.reply_tos |> Map.put(request_ref, reply_to)
      state = %{state | conn: conn, responses: responses, reply_tos: reply_tos}

      {:ok, state, request_ref}
    end
  end

  @spec ensure_connection(state, String.t(), Keyword.t()) ::
          {:ok, state} | {:error, any}
  defp ensure_connection(state, url, opts) do
    with {:ok, protocol, hostname, port} <- Utils.decompose_url(url) do
      new_destination =
        state.protocol != protocol || state.hostname != hostname ||
          state.port != port

      cond do
        !state.conn || new_destination ->
          connect(state, protocol, hostname, port, opts)

        :else ->
          {:ok, state}
      end
    end
  end

  @spec connect(state, String.t(), String.t(), non_neg_integer, Keyword.t()) ::
          {:ok, state} | {:error, any}
  defp connect(state, protocol, hostname, port, opts) do
    with {:ok, conn} <- Mojito.Conn.connect(protocol, hostname, port, opts) do
      {:ok,
       %{state | conn: conn, protocol: protocol, hostname: hostname, port: port}}
    end
  end
end
