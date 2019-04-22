defmodule Mojito.Request do
  @moduledoc ~S"""
  Represents an HTTP/HTTPS request to be performed.
  """

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

  defp receive_response(conn, response, timeout) do
    receive do
      msg ->
        case Mint.HTTP.stream(conn.conn, msg) do
          {:ok, mint_conn, resps} ->
            conn = %{conn | conn: mint_conn}
            response = apply_resps(response, resps)

            if response.complete do
              {:ok, response}
            else
              receive_response(conn, response, timeout)
            end

          {:error, %{state: :closed}, %{reason: :closed}, _} ->
            {:error, %Error{reason: :closed}}

          :unknown ->
            receive_response(conn, response, timeout)
        end
    after
      timeout -> {:error, %Error{reason: :timeout}}
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
    %{response | body: [response.body || "" | [chunk]]}
  end

  defp apply_resp(response, {:done, _request_ref}) do
    %{response | complete: true, body: :erlang.iolist_to_binary(response.body)}
  end
end
