defmodule Mojito.Base do
  @moduledoc ~S"""
  Provides a default implementation for Mojito functions.

  This module is meant to be `use`'d in custom modules in order to wrap the
  functionalities provided by Mojiti. For example, this is very useful to
  build custom API clients around Mojito:

      defmodule CustomAPI do
        use Mojito.Base
      end

  """

  @type method ::
          :head
          | :get
          | :post
          | :put
          | :patch
          | :delete
          | :options
          | String.t()

  @type header :: {String.t(), String.t()}

  @type headers :: [header]

  @type request :: %Mojito.Request{
          method: method,
          url: String.t(),
          headers: headers | nil,
          body: String.t() | nil,
          opts: Keyword.t() | nil
        }

  @type request_kwlist :: [request_field]

  @type request_field ::
          {:method, method}
          | {:url, String.t()}
          | {:headers, headers}
          | {:body, String.t()}
          | {:opts, Keyword.t()}

  @type response :: %Mojito.Response{
          status_code: pos_integer,
          headers: headers,
          body: String.t(),
          complete: boolean
        }

  @type error :: %Mojito.Error{
          reason: any,
          message: String.t() | nil
        }

  @type pool_opts :: [pool_opt | {:destinations, [{atom, pool_opts}]}]

  @type pool_opt ::
          {:size, pos_integer}
          | {:max_overflow, non_neg_integer}
          | {:pools, pos_integer}
          | {:strategy, :lifo | :fifo}

  @type url :: String.t()
  @type body :: String.t()
  @type payload :: String.t()

  @callback request(method, url) ::
              {:ok, response} | {:error, error} | no_return
  @callback request(method, url, headers) ::
              {:ok, response} | {:error, error} | no_return
  @callback request(method, url, headers, body) ::
              {:ok, response} | {:error, error} | no_return
  @callback request(method, url, headers, body, Keyword.t()) ::
              {:ok, response} | {:error, error} | no_return
  @callback request(request | request_kwlist) ::
              {:ok, response} | {:error, error}

  @callback head(url) :: {:ok, response} | {:error, error} | no_return
  @callback head(url, headers) :: {:ok, response} | {:error, error} | no_return
  @callback head(url, headers, Keyword.t()) ::
              {:ok, response} | {:error, error} | no_return

  @callback get(url) :: {:ok, response} | {:error, error} | no_return
  @callback get(url, headers) :: {:ok, response} | {:error, error} | no_return
  @callback get(url, headers, Keyword.t()) ::
              {:ok, response} | {:error, error} | no_return

  @callback post(url) :: {:ok, response} | {:error, error} | no_return
  @callback post(url, headers) :: {:ok, response} | {:error, error} | no_return
  @callback post(url, headers, payload) ::
              {:ok, response} | {:error, error} | no_return
  @callback post(url, headers, payload, Keyword.t()) ::
              {:ok, response} | {:error, error} | no_return

  @callback put(url) :: {:ok, response} | {:error, error} | no_return
  @callback put(url, headers) :: {:ok, response} | {:error, error} | no_return
  @callback put(url, headers, payload) ::
              {:ok, response} | {:error, error} | no_return
  @callback put(url, headers, payload, Keyword.t()) ::
              {:ok, response} | {:error, error} | no_return

  @callback patch(url) :: {:ok, response} | {:error, error} | no_return
  @callback patch(url, headers) :: {:ok, response} | {:error, error} | no_return
  @callback patch(url, headers, payload) ::
              {:ok, response} | {:error, error} | no_return
  @callback patch(url, headers, payload, Keyword.t()) ::
              {:ok, response} | {:error, error} | no_return

  @callback delete(url) :: {:ok, response} | {:error, error} | no_return
  @callback delete(url, headers) ::
              {:ok, response} | {:error, error} | no_return
  @callback delete(url, headers, Keyword.t()) ::
              {:ok, response} | {:error, error} | no_return

  @callback options(url) :: {:ok, response} | {:error, error} | no_return
  @callback options(url, headers) ::
              {:ok, response} | {:error, error} | no_return
  @callback options(url, headers, Keyword.t()) ::
              {:ok, response} | {:error, error} | no_return

  defmacro __using__(_) do
    quote do
      @behaviour Mojito.Base

      @type method :: Mojito.Base.method()
      @type header :: Mojito.Base.header()
      @type headers :: Mojito.Base.headers()
      @type request :: Mojito.Base.request()
      @type request_kwlist :: Mojito.Base.request_kwlist()
      @type request_fields :: Mojito.Base.request_field()
      @type response :: Mojito.Base.response()
      @type error :: Mojito.Base.error()
      @type pool_opts :: Mojito.Base.pool_opts()
      @type pool_opt :: Mojito.Base.pool_opt()
      @type url :: Mojito.Base.url()
      @type body :: Mojito.Base.body()
      @type payload :: Mojito.Base.payload()

      @doc ~S"""
      Performs an HTTP request and returns the response.

      See `request/1` for details.
      """
      @spec request(method, url, headers, body | nil, Keyword.t()) ::
              {:ok, response} | {:error, error} | no_return
      def request(method, url, headers \\ [], body \\ "", opts \\ []) do
        %Mojito.Request{
          method: method,
          url: url,
          headers: headers,
          body: body,
          opts: opts
        }
        |> request
      end

      @doc ~S"""
      Performs an HTTP request and returns the response.

      If the `pool: true` option is given, or `:pool` is not specified, the
      request will be made using Mojito's automatic connection pooling system.
      For more details, see `Mojito.Pool.request/1`.  This is the default
      mode of operation, and is recommended for best performance.

      If `pool: false` is given as an option, the request will be made on
      a brand new connection.  This does not spawn an additional process.
      Messages of the form `{:tcp, _, _}` or `{:ssl, _, _}` will be sent to
      and handled by the caller.  If the caller process expects to receive
      other `:tcp` or `:ssl` messages at the same time, conflicts can occur;
      in this case, it is recommended to wrap `request/1` in `Task.async/1`,
      or use one of the pooled request modes.

      Options:

      * `:pool` - See above.
      * `:timeout` - Response timeout in milliseconds, or `:infinity`.
        Defaults to `Application.get_env(:mojito, :timeout, 5000)`.
      * `:raw` - Set this to `true` to prevent the decompression of
        `gzip` or `compress`-encoded responses.
      * `:transport_opts` - Options to be passed to either `:gen_tcp` or `:ssl`.
        Most commonly used to perform insecure HTTPS requests via
        `transport_opts: [verify: :verify_none]`.
      """
      @spec request(request | request_kwlist) ::
              {:ok, response} | {:error, error}
      def request(request) do
        with {:ok, valid_request} <- Mojito.Request.validate_request(request),
             {:ok, valid_request} <-
               Mojito.Request.convert_headers_values_to_string(valid_request) do
          case Keyword.get(valid_request.opts, :pool, true) do
            true ->
              Mojito.Pool.Poolboy.request(valid_request)

            false ->
              Mojito.Request.Single.request(valid_request)

            pid when is_pid(pid) ->
              Mojito.Pool.Poolboy.Single.request(pid, valid_request)

            impl when is_atom(impl) ->
              impl.request(valid_request)
          end
          |> maybe_decompress(valid_request.opts)
        end
      end

      defp maybe_decompress({:ok, response}, opts) do
        case Keyword.get(opts, :raw) do
          true ->
            {:ok, response}

          _ ->
            case Enum.find(response.headers, fn {k, _v} ->
                   k == "content-encoding"
                 end) do
              {"content-encoding", "gzip"} ->
                {:ok,
                 %Mojito.Response{response | body: :zlib.gunzip(response.body)}}

              {"content-encoding", "deflate"} ->
                {:ok,
                 %Mojito.Response{
                   response
                   | body: :zlib.uncompress(response.body)
                 }}

              _ ->
                # we don't have a decompressor for this so just returning
                {:ok, response}
            end
        end
      end

      defp maybe_decompress(response, _opts) do
        response
      end

      @doc ~S"""
      Performs an HTTP HEAD request and returns the response.

      See `request/1` for documentation.
      """
      @spec head(url, headers, Keyword.t()) ::
              {:ok, response} | {:error, error} | no_return
      def head(url, headers \\ [], opts \\ []) do
        request(:head, url, headers, nil, opts)
      end

      @doc ~S"""
      Performs an HTTP GET request and returns the response.

      ## Examples

      Assemble a URL with a query string params and fetch it with GET request:

          >>>> "https://www.google.com/search"
          ...> |> URI.parse()
          ...> |> Map.put(:query, URI.encode_query(%{"q" => "mojito elixir"}))
          ...> |> URI.to_string()
          ...> |> Mojito.get()
          {:ok,
          %Mojito.Response{
            body: "<!doctype html><html lang=\"en\"><head><meta charset=\"UTF-8\"> ...",
            complete: true,
            headers: [
              {"content-type", "text/html; charset=ISO-8859-1"},
              ...
            ],
            status_code: 200
          }}


      See `request/1` for detailed documentation.
      """
      @spec get(url, headers, Keyword.t()) ::
              {:ok, response} | {:error, error} | no_return
      def get(url, headers \\ [], opts \\ []) do
        request(:get, url, headers, nil, opts)
      end

      @doc ~S"""
      Performs an HTTP POST request and returns the response.

      ## Examples

      Submitting a form with POST request:

          >>>> Mojito.post(
          ...>   "http://localhost:4000/messages",
          ...>   [{"content-type", "application/x-www-form-urlencoded"}],
          ...>   URI.encode_query(%{"message[subject]" => "Contact request", "message[content]" => "data"}))
          {:ok,
          %Mojito.Response{
            body: "Thank you!",
            complete: true,
            headers: [
              {"server", "Cowboy"},
              {"connection", "keep-alive"},
              ...
            ],
            status_code: 200
          }}

      Submitting a JSON payload as POST request body:

          >>>> Mojito.post(
          ...>   "http://localhost:4000/api/messages",
          ...>   [{"content-type", "application/json"}],
          ...>   Jason.encode!(%{"message" => %{"subject" => "Contact request", "content" => "data"}}))
          {:ok,
          %Mojito.Response{
            body: "{\"message\": \"Thank you!\"}",
            complete: true,
            headers: [
              {"server", "Cowboy"},
              {"connection", "keep-alive"},
              ...
            ],
            status_code: 200
          }}

      See `request/1` for detailed documentation.
      """
      @spec post(url, headers, payload, Keyword.t()) ::
              {:ok, response} | {:error, error} | no_return
      def post(url, headers \\ [], payload \\ "", opts \\ []) do
        request(:post, url, headers, payload, opts)
      end

      @doc ~S"""
      Performs an HTTP PUT request and returns the response.

      See `request/1` and `post/4` for documentation and examples.
      """
      @spec put(url, headers, payload, Keyword.t()) ::
              {:ok, response} | {:error, error} | no_return
      def put(url, headers \\ [], payload \\ "", opts \\ []) do
        request(:put, url, headers, payload, opts)
      end

      @doc ~S"""
      Performs an HTTP PATCH request and returns the response.

      See `request/1` and `post/4` for documentation and examples.
      """
      @spec patch(url, headers, payload, Keyword.t()) ::
              {:ok, response} | {:error, error} | no_return
      def patch(url, headers \\ [], payload \\ "", opts \\ []) do
        request(:patch, url, headers, payload, opts)
      end

      @doc ~S"""
      Performs an HTTP DELETE request and returns the response.

      See `request/1` for documentation and examples.
      """
      @spec delete(url, headers, Keyword.t()) ::
              {:ok, response} | {:error, error} | no_return
      def delete(url, headers \\ [], opts \\ []) do
        request(:delete, url, headers, nil, opts)
      end

      @doc ~S"""
      Performs an HTTP OPTIONS request and returns the response.

      See `request/1` for documentation.
      """
      @spec options(url, headers, Keyword.t()) ::
              {:ok, response} | {:error, error} | no_return
      def options(url, headers \\ [], opts \\ []) do
        request(:options, url, headers, nil, opts)
      end
    end
  end
end
