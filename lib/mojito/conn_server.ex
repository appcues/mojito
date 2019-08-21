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
  @spec request(pid, Mojito.request(), pid, reference) :: :ok | {:error, any}
  def request(server_pid, request, reply_to, response_ref) do
    GenServer.call(server_pid, {:request, request, reply_to, response_ref})
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
       response_refs: %{},
     }}
  end

  def terminate(_reason, state) do
    close_connections(state)
  end

  def handle_call(
        {:request, request, reply_to, response_ref},
        _from,
        state
      ) do
    with {:ok, state, _request_ref} <-
           start_request(state, request, reply_to, response_ref) do
      {:reply, :ok, state}
    else
      err -> {:reply, err, close_connections(state)}
    end
  end

  ## `msg` is an incoming chunk of a response
  def handle_info(msg, state) do
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
    Enum.each(state.reply_tos, fn {_request_ref, reply_to} ->
      respond(reply_to, {:error, :closed})
    end)

    %{state | conn: nil, responses: %{}, reply_tos: %{}, response_refs: %{}}
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
    response_ref = state.response_refs |> Map.get(request_ref)

    Map.get(state.reply_tos, request_ref)
    |> respond({:ok, response}, response_ref)

    %{
      state
      | responses: Map.delete(state.responses, request_ref),
        reply_tos: Map.delete(state.reply_tos, request_ref),
        response_refs: Map.delete(state.response_refs, request_ref),
    }
  end

  defp respond(pid, message, response_ref \\ nil) do
    send(pid, {:mojito_response, response_ref, message})
  end

  @spec start_request(
          state,
          Mojito.request(),
          pid,
          reference
        ) :: {:ok, state, reference} | {:error, any}
  defp start_request(state, request, reply_to, response_ref) do
    with {:ok, state} <- ensure_connection(state, request.url, request.opts),
         {:ok, conn, request_ref} <- Conn.request(state.conn, request) do
      responses = state.responses |> Map.put(request_ref, %Response{body: []})
      reply_tos = state.reply_tos |> Map.put(request_ref, reply_to)
      response_refs = state.response_refs |> Map.put(request_ref, response_ref)

      state = %{
        state
        | conn: conn,
          responses: responses,
          reply_tos: reply_tos,
          response_refs: response_refs,
      }

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
