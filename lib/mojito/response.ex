defmodule Mojito.Response do
  @moduledoc false

  defstruct status_code: nil,
            headers: [],
            body: "",
            complete: false,
            size: 0

  @type t :: Mojito.response()

  @doc ~S"""
  Applies responses received from `Mint.HTTP.stream/2` to a %Mojito.Response{}.
  """
  @spec apply_resps(t, [Mint.Types.response()]) :: t
  def apply_resps(response, []), do: response

  def apply_resps(response, [mint_resp | rest]) do
    apply_resp(response, mint_resp) |> apply_resps(rest)
  end

  defp apply_resp(response, {:status, _request_ref, status_code}) do
    %{response | status_code: status_code}
  end

  defp apply_resp(response, {:headers, _request_ref, headers}) do
    %{response | headers: headers}
  end

  defp apply_resp(response, {:data, _request_ref, chunk}) do
    {:ok, resp} = Utils.put_chunk(response, chunk)
    resp
  end

  defp apply_resp(response, {:done, _request_ref}) do
    %{response | complete: true, body: :erlang.iolist_to_binary(response.body)}
  end
end
