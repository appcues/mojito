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
      {:error, {:error, e}} -> {:error, %Error{reason: e}}
      {:error, e} -> {:error, %Error{reason: e}}
      {:error, _mint_conn, error} -> {:error, %Error{reason: error}}
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
  """
  @spec decompose_url(String.t()) ::
          {:ok, String.t(), String.t(), non_neg_integer} | {:error, any}
  def decompose_url(url) do
    try do
      uri = URI.parse(url)

      cond do
        !uri.scheme || !uri.host || !uri.port ->
          {:error, %Error{message: "invalid URL: #{url}"}}

        :else ->
          {:ok, uri.scheme, uri.host, uri.port}
      end
    rescue
      e -> {:error, %Error{message: "invalid URL", reason: e}}
    end
  end

  @doc ~S"""
  Returns a relative URL including query parts, excluding the fragment, and any
  necessary auth headers (i.e., for HTTP Basic auth).

      iex> Mojito.Utils.get_relative_url_and_auth_headers("https://user:pass@example.com/this/is/awesome?foo=bar&baz")
      {:ok, "/this/is/awesome?foo=bar&baz", [{"authorization", "Basic dXNlcjpwYXNz"}]}

      iex> Mojito.Utils.get_relative_url_and_auth_headers("https://example.com/something.html#section42")
      {:ok, "/something.html", []}
  """
  @spec get_relative_url_and_auth_headers(String.t()) ::
          {:ok, String.t(), Mojito.headers()} | {:error, any}
  def get_relative_url_and_auth_headers(url) do
    try do
      uri = URI.parse(url)

      headers =
        case uri.userinfo do
          nil -> []
          userinfo -> [{"authorization", "Basic #{Base.encode64(userinfo)}"}]
        end

      joined_url =
        [
          if(uri.path, do: "#{uri.path}", else: ""),
          if(uri.query, do: "?#{uri.query}", else: "")
        ]
        |> Enum.join("")

      relative_url =
        if String.starts_with?(joined_url, "/") do
          joined_url
        else
          "/" <> joined_url
        end

      {:ok, relative_url, headers}
    rescue
      e -> {:error, %Error{message: "invalid URL", reason: e}}
    end
  end

  @doc ~S"""
  Returns the correct Erlang TCP transport module for the given protocol.
  """
  @spec protocol_to_transport(String.t()) :: {:ok, atom} | {:error, any}
  def protocol_to_transport("https"), do: {:ok, :ssl}

  def protocol_to_transport("http"), do: {:ok, :gen_tcp}

  def protocol_to_transport(proto),
    do: {:error, "unknown protocol #{inspect(proto)}"}
end
