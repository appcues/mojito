defmodule Mojito.Headers do
  @moduledoc ~S"""
  Functions for working with HTTP request and response headers, as described
  in the [HTTP 1.1 specification](https://www.w3.org/Protocols/rfc2616/rfc2616.html).

  Headers are represented in Elixir as a list of `{"header_name", "value"}`
  tuples.  Multiple entries for the same header name are allowed.

  Capitalization of header names is preserved during insertion,
  however header names are handled case-insensitively during
  lookup and deletion.
  """

  @type headers :: Mojito.headers()

  @doc ~S"""
  Returns the value for the given HTTP request or response header,
  or `nil` if not found.

  Header names are matched case-insensitively.

  If more than one matching header is found, the values are joined with
  `","` as specified in [RFC 2616](https://www.w3.org/Protocols/rfc2616/rfc2616-sec4.html#sec4.2).

  Example:

      iex> headers = [
      ...>   {"header1", "foo"},
      ...>   {"header2", "bar"},
      ...>   {"Header1", "baz"}
      ...> ]
      iex> Mojito.Headers.get(headers, "header2")
      "bar"
      iex> Mojito.Headers.get(headers, "HEADER1")
      "foo,baz"
      iex> Mojito.Headers.get(headers, "header3")
      nil
  """
  @spec get(headers, String.t()) :: String.t() | nil
  def get(headers, name) do
    case get_values(headers, name) do
      [] -> nil
      values -> values |> Enum.join(",")
    end
  end

  @doc ~S"""
  Returns all values for the given HTTP request or response header.
  Returns an empty list if none found.

  Header names are matched case-insensitively.

  Example:

      iex> headers = [
      ...>   {"header1", "foo"},
      ...>   {"header2", "bar"},
      ...>   {"Header1", "baz"}
      ...> ]
      iex> Mojito.Headers.get_values(headers, "header2")
      ["bar"]
      iex> Mojito.Headers.get_values(headers, "HEADER1")
      ["foo", "baz"]
      iex> Mojito.Headers.get_values(headers, "header3")
      []
  """
  @spec get_values(headers, String.t()) :: [String.t()]
  def get_values(headers, name) do
    get_values(headers, String.downcase(name), [])
  end

  defp get_values([], _name, values), do: values

  defp get_values([{key, value} | rest], name, values) do
    new_values =
      if String.downcase(key) == name do
        values ++ [value]
      else
        values
      end

    get_values(rest, name, new_values)
  end

  @doc ~S"""
  Puts the given header `value` under `name`, removing any values previously
  stored under `name`.  The new header is placed at the end of the list.

  Header names are matched case-insensitively, but case of `name` is preserved
  when adding the header.

  Example:

      iex> headers = [
      ...>   {"header1", "foo"},
      ...>   {"header2", "bar"},
      ...>   {"Header1", "baz"}
      ...> ]
      iex> Mojito.Headers.put(headers, "HEADER1", "quux")
      [{"header2", "bar"}, {"HEADER1", "quux"}]
  """
  @spec put(headers, String.t(), String.t()) :: headers
  def put(headers, name, value) do
    delete(headers, name) ++ [{name, value}]
  end

  @doc ~S"""
  Removes all instances of the given header.

  Header names are matched case-insensitively.

  Example:

      iex> headers = [
      ...>   {"header1", "foo"},
      ...>   {"header2", "bar"},
      ...>   {"Header1", "baz"}
      ...> ]
      iex> Mojito.Headers.delete(headers, "HEADER1")
      [{"header2", "bar"}]
  """
  @spec delete(headers, String.t()) :: headers
  def delete(headers, name) do
    name = String.downcase(name)
    Enum.filter(headers, fn {key, _value} -> String.downcase(key) != name end)
  end

  @doc ~S"""
  Returns an ordered list of the header names from the given headers.
  Header names are returned in lowercase.

  Example:

      iex> headers = [
      ...>   {"header1", "foo"},
      ...>   {"header2", "bar"},
      ...>   {"Header1", "baz"}
      ...> ]
      iex> Mojito.Headers.keys(headers)
      ["header1", "header2"]
  """
  @spec keys(headers) :: [String.t()]
  def keys(headers) do
    keys(headers, [])
  end

  defp keys([], names), do: Enum.reverse(names)

  defp keys([{name, _value} | rest], names) do
    name = String.downcase(name)

    if name in names do
      keys(rest, names)
    else
      keys(rest, [name | names])
    end
  end

  @doc ~S"""
  Returns a copy of the given headers where all header names are lowercased
  and multiple values for the same header have been joined with `","`.

  Example:

      iex> headers = [
      ...>   {"header1", "foo"},
      ...>   {"header2", "bar"},
      ...>   {"Header1", "baz"}
      ...> ]
      iex> Mojito.Headers.normalize(headers)
      [{"header1", "foo,baz"}, {"header2", "bar"}]
  """
  @spec normalize(headers) :: headers
  def normalize(headers) do
    headers_map =
      Enum.reduce(headers, %{}, fn {name, value}, acc ->
        name = String.downcase(name)
        values = Map.get(acc, name, [])
        Map.put(acc, name, values ++ [value])
      end)

    headers
    |> keys
    |> Enum.map(fn name ->
      {name, Map.get(headers_map, name) |> Enum.join(",")}
    end)
  end
end
