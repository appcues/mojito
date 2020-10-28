defmodule Mojito.Request do
  @moduledoc false

  defstruct method: nil,
            url: nil,
            headers: [],
            body: "",
            opts: []

  alias Mojito.{Error, Headers, Request}

  @doc ~S"""
  Checks for errors and returns a canonicalized version of the request.
  """
  @spec validate_request(map | Mojito.request() | Mojito.request_kwlist()) ::
          {:ok, Mojito.request()} | {:error, Mojito.error()}

  def validate_request(%{} = request) do
    method = Map.get(request, :method)
    url = Map.get(request, :url)
    headers = Map.get(request, :headers, [])
    body = Map.get(request, :body)
    opts = Map.get(request, :opts, [])

    cond do
      method == nil ->
        {:error, %Error{message: "method cannot be nil"}}

      method == "" ->
        {:error, %Error{message: "method cannot be blank"}}

      url == nil ->
        {:error, %Error{message: "url cannot be nil"}}

      url == "" ->
        {:error, %Error{message: "url cannot be blank"}}

      !is_list(headers) ->
        {:error, %Error{message: "headers must be a list"}}

      !is_binary(body) && !is_nil(body) ->
        {:error, %Error{message: "body must be `nil` or a UTF-8 string"}}

      :else ->
        method_atom = method_to_atom(method)

        ## Prevent bug #58, where sending "" with HEAD/GET/OPTIONS
        ## can screw up HTTP/2 handling
        valid_body =
          case method_atom do
            :get -> nil
            :head -> nil
            :delete -> nil
            :options -> nil
            _ -> request.body || ""
          end

        {:ok,
         %Request{
           method: method_atom,
           url: url,
           headers: headers,
           body: valid_body,
           opts: opts
         }}
    end
  end

  def validate_request(request) when is_list(request) do
    request |> Enum.into(%{}) |> validate_request
  end

  def validate_request(_request) do
    {:error, %Error{message: "request must be a map"}}
  end

  defp method_to_atom(method) when is_atom(method), do: method

  defp method_to_atom(method) when is_binary(method) do
    method |> String.downcase() |> String.to_atom()
  end

  @doc ~S"""
  Converts non-string header values to UTF-8 string if possible.
  """
  @spec convert_headers_values_to_string(Mojito.request()) ::
          {:ok, Mojito.request()}
  def convert_headers_values_to_string(%{headers: headers} = request) do
    {:ok, %{request | headers: Headers.convert_values_to_string(headers)}}
  end
end
