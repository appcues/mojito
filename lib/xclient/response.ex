defmodule XClient.Response do
  @moduledoc ~S"""
  Represents the response to a request.
  """

  defstruct status_code: nil,
            headers: [],
            body: []

  @type t :: %__MODULE__{
          status_code: non_neg_integer,
          headers: XClient.headers(),
          body: String.t()
        }

  @doc ~S"""
  Returns the value of the given response header, or `nil` if not present.
  """
  @spec get_header(%__MODULE__{} | [{String.t(), String.t()}], String.t()) :: String.t() | nil

  def get_header(%__MODULE__{} = response, header_name) do
    header(response.headers, String.downcase(header_name))
  end

  def get_header(headers, header_name) when is_list(headers) do
    header(headers, String.downcase(header_name))
  end

  defp header([], _header_name), do: nil

  defp header([{name, value} | rest], header_name) do
    if name == header_name do
      value
    else
      header(rest, header_name)
    end
  end
end
