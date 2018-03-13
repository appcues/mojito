defmodule X1Client do
  @moduledoc ~S"""
  `X1Client` is a simplified HTTP 1.x client built using the
  low-level [`XHTTP` library](https://github.com/ericmj/xhttp).

  It provides an interface that will feel familiar to users of other
  Elixir HTTP client libraries.

      >>>> X1Client.request(:get, "https://jsonplaceholder.typicode.com/posts/1")
      {:ok,
       %X1Client.Response{
         body: "{\n  \"userId\": 1,\n  \"id\": 1,\n  \"title\": \"sunt aut facere repellat provident occaecati excepturi optio reprehenderit\",\n  \"body\": \"quia et suscipit\\nsuscipit recusandae consequuntur expedita et cum\\nreprehenderit molestiae ut ut quas totam\\nnostrum rerum est autem sunt rem eveniet architecto\"\n}",
         done: true,
         headers: [
           {"content-type", "application/json; charset=utf-8"},
           {"content-length", "292"},
           {"connection", "keep-alive"},
           ...
         ],
         status_code: 200
       }}
  """

  alias X1Client.Response

  @type headers :: [{String.t(), String.t()}]

  @type method :: :get | :post | :put | :patch | :delete | :options

  @request_timeout Application.get_env(:x1client, :request_timeout, 5000)

  @doc ~S"""
  Performs an HTTP 1.x request.
  """
  @spec request(method, String.t(), headers, String.t(), Keyword.t()) ::
          {:ok, %Response{}} | {:error, any}
  def request(method, url, headers \\ [], payload \\ "", opts \\ []) do
    timeout = opts[:timeout] || @request_timeout

    task =
      fn ->
        with {:ok, pid} <- X1Client.ConnServer.start_link(),
             :ok <- X1Client.ConnServer.request(pid, self(), method, url, headers, payload, opts) do
          receive do
            reply ->
              GenServer.stop(pid)
              reply
          after
            timeout ->
              GenServer.stop(pid)
              {:error, :timeout}
          end
        end
      end
      |> Task.async()

    case Task.yield(task, timeout + 100) || Task.shutdown(task) do
      {:ok, result} -> result
      _ -> {:error, :timeout}
    end
  end
end
