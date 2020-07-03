defmodule Mojito.Response do
  @moduledoc false

  alias Mojito.{Error, Response}

  defstruct status_code: nil,
            headers: [],
            body: "",
            complete: false,
            size: 0

  @type t :: Mojito.response()

  @doc ~S"""
  Applies responses received from `Mint.HTTP.stream/2` to a `%Mojito.Response{}`.
  """
  @spec apply_resps(t, [Mint.Types.response()]) :: {:ok, t} | {:error, any}
  def apply_resps(response, []), do: {:ok, response}

  def apply_resps(response, [mint_resp | rest]) do
    with {:ok, response} <- apply_resp(response, mint_resp) do
      apply_resps(response, rest)
    end
  end

  @doc ~S"""
  Applies a response received from `Mint.HTTP.stream/2` to a `%Mojito.Response{}`.
  """
  @spec apply_resps(t, Mint.Types.response()) :: {:ok, t} | {:error, any}
  def apply_resp(response, {:status, _request_ref, status_code}) do
    {:ok, %{response | status_code: status_code}}
  end

  def apply_resp(response, {:headers, _request_ref, headers}) do
    {:ok, %{response | headers: headers}}
  end

  def apply_resp(response, {:data, _request_ref, chunk}) do
    with {:ok, response} <- put_chunk(response, chunk) do
      {:ok, response}
    end
  end

  def apply_resp(response, {:done, _request_ref}) do
    body = :erlang.iolist_to_binary(response.body)
    size = byte_size(body)
    {:ok, %{response | complete: true, body: body, size: size}}
  end

  @doc ~S"""
  Adds chunks to a response body, respecting the `response.size` field.
  `response.size` should be set to the maximum number of bytes to accept
  as the response body, or `nil` for no limit.
  """
  @spec put_chunk(t, binary) :: {:ok, %Response{}} | {:error, any}
  def put_chunk(%Response{size: nil} = response, chunk) do
    {:ok, %{response | body: [response.body | [chunk]]}}
  end

  def put_chunk(%Response{size: remaining} = response, chunk) do
    case remaining - byte_size(chunk) do
      over_limit when over_limit < 0 ->
        {:error, %Error{reason: :max_body_size_exceeded}}

      new_remaining ->
        {:ok,
         %{response | body: [response.body | [chunk]], size: new_remaining}}
    end
  end
end
