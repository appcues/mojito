defmodule Mojito.Request do
  @moduledoc false

  defstruct method: nil,
            url: nil,
            headers: [],
            payload: "",
            opts: []

  require Logger
  alias Mojito.{Conn, Error, Response}

  @request_timeout Application.get_env(:mojito, :request_timeout, 5000)

  @doc false
  @spec request(Mojito.request()) ::
          {:ok, Mojito.response()} | {:error, Mojito.error()}
  def request(%Mojito.Request{} = req) do
    opts = req.opts || []
    headers = req.headers || []
    payload = req.payload || ""

    timeout = opts[:timeout] || @request_timeout

    with {:ok, conn} <- Conn.connect(req.url, opts),
         {:ok, conn, _ref} <-
           Conn.request(conn, req.method, req.url, headers, payload, opts) do
      receive_response(conn, %Response{}, timeout)
    end
  end

  defp time, do: System.monotonic_time(:millisecond)

  @doc false
  def receive_response(conn, response, timeout) do
    start_time = time()

    receive do
      {:tcp, _, _} = msg -> handle_msg(conn, response, timeout, msg, start_time)
      {:ssl, _, _} = msg -> handle_msg(conn, response, timeout, msg, start_time)
    after
      timeout -> {:error, %Error{reason: :timeout}}
    end
  end

  defp handle_msg(conn, response, timeout, msg, start_time) do
    new_timeout = fn ->
      time_elapsed = time() - start_time

      case timeout - time_elapsed do
        x when x < 0 -> 0
        x -> x
      end
    end

    case Mint.HTTP.stream(conn.conn, msg) do
      {:ok, mint_conn, resps} ->
        conn = %{conn | conn: mint_conn}
        response = apply_resps(response, resps)

        if response.complete do
          {:ok, response}
        else
          receive_response(conn, response, new_timeout.())
        end

      {:error, _, e, _} ->
        {:error, %Error{reason: e}}

      :unknown ->
        receive_response(conn, response, new_timeout.())
    end
  end

  defp apply_resps(response, []), do: response

  defp apply_resps(response, [mint_resp | rest]) do
    apply_resp(response, mint_resp) |> apply_resps(rest)
  end

  defp apply_resp(response, {:status, _request_ref, status_code}) do
    %{response | status_code: status_code}
  end

  defp apply_resp(response, {:headers, _request_ref, headers}) do
    %{response | headers: headers}
  end

  defp apply_resp(response, {:data, _request_ref, chunk}) do
    %{response | body: [response.body | [chunk]]}
  end

  defp apply_resp(response, {:done, _request_ref}) do
    %{response | complete: true, body: :erlang.iolist_to_binary(response.body)}
  end

  @doc ~S"""
  Checks for errors and returns a canonicalized version of the request.
  """
  @spec validate_request(map | %Mojito.Request{}) ::
          {:ok, Mojito.request()} | {:error, Mojito.error()}

  def validate_request(%{} = request) do
    cond do
      Map.get(request, :method) == nil ->
        {:error, %Error{message: "method cannot be nil"}}

      Map.get(request, :method) == "" ->
        {:error, %Error{message: "method cannot be blank"}}

      Map.get(request, :url) == nil ->
        {:error, %Error{message: "url cannot be nil"}}

      Map.get(request, :url) == "" ->
        {:error, %Error{message: "url cannot be blank"}}

      !is_list(Map.get(request, :headers, [])) ->
        {:error, %Error{message: "headers must be a list"}}

      !is_binary(Map.get(request, :payload, "")) ->
        {:error, %Error{message: "payload must be a UTF-8 string"}}

      :else ->
        {:ok,
         %Mojito.Request{
           method: request.method,
           url: request.url,
           headers: request.headers || [],
           payload: request.payload || "",
           opts: request.opts || [],
         }}
    end
  end

  def validate_request(request) do
    {:error, %Error{message: "request must be a map"}}
  end
end
