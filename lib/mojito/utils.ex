defmodule Mojito.Utils do
  @moduledoc false

  alias Mojito.Error

  @doc ~S"""
  Ensures that the return value errors are of the form
  `{:error, %Mojito.Error{}}`.  Values `:ok` and `{:ok, val}` are
  considered successful; other values are treated as errors.
  """
  @spec wrap_return_value(any) :: :ok | {:ok, any} | {:error, Mojito.error()}
  def wrap_return_value(rv) do
    case rv do
      :ok -> rv
      {:ok, _} -> rv
      {:error, %Error{}} -> rv
      {:error, e} -> {:error, %Error{reason: e}}
      other -> {:error, %Error{reason: :unknown, message: other}}
    end
  end

  @doc ~S"""
  Returns the protocol, hostname, and port (express or implied) from a
  web URL.

      iex> Mojito.Utils.decompose_url("http://example.com:8888/test")
      {:ok, "http", "example.com", 8888}

      iex> Mojito.Utils.decompose_url("https://user:pass@example.com")
      {:ok, "https", "example.com", 443}

      iex> Mojito.Utils.decompose_url("ssh://example.com")
      {:error, "unsupported URL protocol ssh"}
  """
  @spec decompose_url(String.t()) ::
          {:ok, String.t(), String.t(), non_neg_integer} | {:error, any}
  def decompose_url(url) do
    with {:ok, fu} <- fuzzyurl_from_string(url),
         {:ok, protocol} <- get_protocol(fu),
         {:ok, hostname} <- get_hostname(fu),
         {:ok, port} <- get_port(fu) do
      {:ok, protocol, hostname, port}
    end
  end

  @doc ~S"""
  Returns a relative URL including query and fragment parts, and any
  necessary auth headers (i.e., for HTTP Basic auth).
  """
  @spec get_relative_url_and_auth_headers(String.t()) ::
          {:ok, String.t(), Mojito.headers()} | {:error, any}
  def get_relative_url_and_auth_headers(url) do
    with {:ok, fu} <- fuzzyurl_from_string(url) do
      headers =
        if !(fu.username in ["", nil]) do
          user = fu.username || ""
          pass = fu.password || ""
          credentials = "#{user}:#{pass}" |> Base.encode64()
          [{"authorization", "Basic #{credentials}"}]
        else
          []
        end

      url_pieces = [
        if(fu.path, do: "#{fu.path}", else: ""),
        if(fu.query, do: "?#{fu.query}", else: ""),
        if(fu.fragment, do: "##{fu.fragment}", else: "")
      ]

      joined_url = url_pieces |> Enum.join("")

      relative_url =
        if String.starts_with?(joined_url, "/") do
          joined_url
        else
          "/" <> joined_url
        end

      {:ok, relative_url, headers}
    end
  end

  @doc ~S"""
  Returns the correct Erlang TCP transport module for the given protocol.
  """
  @spec protocol_to_transport(String.t()) :: {:ok, atom} | {:error, any}
  def protocol_to_transport("https"), do: {:ok, :ssl}

  def protocol_to_transport("http"), do: {:ok, :gen_tcp}

  def protocol_to_transport(proto), do: {:error, "unknown protocol #{inspect(proto)}"}

  @spec fuzzyurl_from_string(String.t()) :: {:ok, Fuzzyurl.t()} | {:error, any}
  defp fuzzyurl_from_string(url) do
    try do
      {:ok, Fuzzyurl.from_string(url)}
    rescue
      e -> {:error, e}
    end
  end

  @spec get_protocol(Fuzzyurl.t()) :: {:ok, String.t()} | {:error, any}
  defp get_protocol(fu) do
    cond do
      !fu.protocol -> {:error, "URL is missing protocol"}
      String.downcase(fu.protocol) == "http" -> {:ok, "http"}
      String.downcase(fu.protocol) == "https" -> {:ok, "https"}
      :else -> {:error, "unsupported URL protocol #{fu.protocol}"}
    end
  end

  @spec get_hostname(Fuzzyurl.t()) :: {:ok, String.t()} | {:error, any}
  defp get_hostname(fu) do
    cond do
      !(fu.hostname in ["", nil]) -> {:ok, fu.hostname}
      :else -> {:error, "no hostname found in URL"}
    end
  end

  @spec get_port(Fuzzyurl.t()) :: {:ok, non_neg_integer} | {:error, any}
  defp get_port(fu) do
    cond do
      !(fu.port in ["", nil]) -> {:ok, String.to_integer(fu.port)}
      fu.protocol == "http" -> {:ok, 80}
      fu.protocol == "https" -> {:ok, 443}
      :else -> {:error, "couldn't determine URL port"}
    end
  end
end
