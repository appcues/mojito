defmodule Mojito.Response do
  @moduledoc false

  alias Mojito.Utils

  defstruct status_code: nil,
            headers: [],
            body: "",
            complete: false,
            size: 0

  @type t :: Mojito.response()

  @doc ~S"""
  Applies responses received from `Mint.HTTP.stream/2` to a %Mojito.Response{}.
  """
  @spec apply_resps(t, [Mint.Types.response()]) :: {:ok, t} | {:error, any}
  def apply_resps(response, []), do: {:ok, response}

  def apply_resps(response, [mint_resp | rest]) do
    with {:ok, response} <- apply_resp(response, mint_resp) do
      apply_resps(response, rest)
    end
  end

  @doc ~S"""
  Applies a response received from `Mint.HTTP.stream/2` to a %Mojito.Response{}.
  """
  @spec apply_resps(t, Mint.Types.response()) :: {:ok, t} | {:error, any}
  def apply_resp(response, {:status, _request_ref, status_code}) do
    {:ok, %{response | status_code: status_code}}
  end

  def apply_resp(response, {:headers, _request_ref, headers}) do
    {:ok, %{response | headers: headers}}
  end

  def apply_resp(response, {:data, _request_ref, chunk}) do
    with {:ok, response} <- Utils.put_chunk(response, chunk) do
      {:ok, response}
    end
  end

  def apply_resp(response, {:done, _request_ref}) do
    body = :erlang.iolist_to_binary(response.body)
    size = byte_size(body)
    {:ok, %{response | complete: true, body: body, size: size}}
  end
end
