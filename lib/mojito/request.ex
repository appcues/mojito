defmodule Mojito.Request do
  @moduledoc false

  defstruct method: nil,
            url: nil,
            headers: [],
            body: "",
            opts: []

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

      !is_binary(Map.get(request, :body, "")) ->
        {:error, %Error{message: "body must be a UTF-8 string"}}

      :else ->
        {:ok,
         %Request{
           method: request.method,
           url: request.url,
           headers: Map.get(request, :headers, []),
           body: Map.get(request, :body, ""),
           opts: Map.get(request, :opts, []),
         }}
    end
  end

  def validate_request(request) when is_list(request) do
    request |> Enum.into(%{}) |> validate_request
  end

  def validate_request(_request) do
    {:error, %Error{message: "request must be a map"}}
  end
end
