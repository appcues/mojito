defmodule Mojito.Redirects do
  def maybe_follow_redirect(
        last_request,
        %{status_code: status_code} = last_response
      ) do
    case last_request.opts[:follow_redirects] do
      true ->
        new_location = Mojito.Headers.get(last_response.headers, "location")

        new_request = %{
          last_request
          | url: assemble_redirect_url(last_request.url, new_location)
        }

        Mojito.request(new_request)

      _ ->
        {:ok, last_response}
    end
  end

  defp assemble_redirect_url(previous_url, location) do
    previous_uri = URI.parse(previous_url)
    location_uri = URI.parse(location)

    case location_uri.host do
      nil ->
        # relative redirect
        next_uri = %{
          previous_uri
          | path: location_uri.path,
            query: location_uri.query
        }

        URI.to_string(next_uri)

      _host ->
        location
    end
  end
end
