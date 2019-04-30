defmodule Mojito.Request do
  @moduledoc false

  defstruct method: nil,
            url: nil,
            headers: [],
            payload: "",
            opts: []

  require Logger
  alias Mojito.{Error, Request}

  @doc ~S"""
  Checks for errors and returns a canonicalized version of the request.
  """
  @spec validate_request(map | Mojito.request()) ::
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
         %Request{
           method: request.method,
           url: request.url,
           headers: request.headers || [],
           payload: request.payload || "",
           opts: request.opts || [],
         }}
    end
  end

  def validate_request(_request) do
    {:error, %Error{message: "request must be a map"}}
  end

end
