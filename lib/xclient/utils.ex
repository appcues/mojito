defmodule XClient.Utils do
  @moduledoc false

  @url_regex ~r"
    ^
    (?<protocol> https?)
    ://
    (?<hostname> [^:/]+)
    :?
    (?<port> \d+)?
    (?<relative> / .*)?
    $
  "xi

  @doc ~S"""
  Returns the protocol, hostname, and port (express or implied) from a URL.

      iex> XClient.Utils.decompose_url("http://example.com:8888/test")
      {:ok, "http", "example.com", 8888}

      iex> XClient.Utils.decompose_url("https://example.com")
      {:ok, "https", "example.com", 443}
  """
  @spec decompose_url(String.t()) ::
          {:ok, String.t(), String.t(), non_neg_integer} | {:error, any}
  def decompose_url(url) do
    case Regex.named_captures(@url_regex, url) do
      nil ->
        {:error, "could not parse url #{url}"}

      nc ->
        protocol = String.downcase(nc["protocol"])

        port =
          if nc["port"] == "" do
            case protocol do
              "https" -> "443"
              "http" -> "80"
            end
          else
            nc["port"]
          end

        {:ok, protocol, nc["hostname"], String.to_integer(port)}
    end
  end

  @doc ~S"""
  Strips the protocol, hostname, and port from a URL.  Returned path always
  begins with `/`.

      iex> XClient.Utils.make_relative_url("http://google.com/search?q=news")
      {:ok, "/search?q=news"}

      iex> XClient.Utils.make_relative_url("https://example.com")
      {:ok, "/"}
  """
  @spec make_relative_url(String.t()) :: {:ok, String.t()} | {:error, any}
  def make_relative_url(url) do
    case Regex.named_captures(@url_regex, url) do
      nil ->
        {:error, "could not parse url #{url}"}

      nc ->
        relative = if nc["relative"] == "", do: "/", else: nc["relative"]
        {:ok, relative}
    end
  end

  @doc ~S"""
  Returns the correct Erlang TCP transport module for the given protocol.
  """
  @spec protocol_to_transport(String.t()) :: {:ok, atom} | {:error, any}
  def protocol_to_transport("https"), do: {:ok, :ssl}

  def protocol_to_transport("http"), do: {:ok, :gen_tcp}

  def protocol_to_transport(proto), do: {:error, "unknown protocol #{inspect(proto)}"}
end
