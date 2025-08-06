defmodule PaddleBilling.Client do
  @moduledoc """
  HTTP client for making requests to the Paddle Billing API.

  Handles authentication, request/response formatting, error handling,
  and provides a clean interface for API operations.
  """

  alias PaddleBilling.{Config, Error, JSON}

  @type method :: :get | :post | :patch | :put | :delete
  @type headers :: [{String.t(), String.t()}]
  @type params :: map() | keyword()
  @type response :: {:ok, any()} | {:error, Error.t()}

  @doc """
  Makes a GET request to the Paddle API.

  ## Examples

      PaddleBilling.Client.get("/products")
      {:ok, %{"data" => [%{"id" => "pro_123", "name" => "My Product"}]}}
      
      PaddleBilling.Client.get("/products", %{include: "prices"})
      {:ok, %{"data" => [...], "meta" => %{"request_id" => "..."}}}
  """
  @spec get(String.t(), params(), keyword()) :: response()
  def get(path, params \\ %{}, opts \\ []) do
    request(:get, path, nil, params, opts)
  end

  @doc """
  Makes a POST request to the Paddle API.

  ## Examples

      PaddleBilling.Client.post("/products", %{name: "New Product"})
      {:ok, %{"data" => %{"id" => "pro_123", "name" => "New Product"}}}
  """
  @spec post(String.t(), map(), keyword()) :: response()
  def post(path, body \\ %{}, opts \\ []) do
    request(:post, path, body, %{}, opts)
  end

  @doc """
  Makes a PATCH request to the Paddle API.

  ## Examples

      PaddleBilling.Client.patch("/products/pro_123", %{name: "Updated Product"})
      {:ok, %{"data" => %{"id" => "pro_123", "name" => "Updated Product"}}}
  """
  @spec patch(String.t(), map(), keyword()) :: response()
  def patch(path, body, opts \\ []) do
    request(:patch, path, body, %{}, opts)
  end

  @doc """
  Makes a PUT request to the Paddle API.
  """
  @spec put(String.t(), map()) :: response()
  def put(path, body) do
    request(:put, path, body, %{}, [])
  end

  @doc """
  Makes a DELETE request to the Paddle API.

  ## Examples

      PaddleBilling.Client.delete("/products/pro_123")
      {:ok, nil}
  """
  @spec delete(String.t()) :: response()
  def delete(path) do
    request(:delete, path, nil, %{}, [])
  end

  @doc """
  Makes a generic HTTP request to the Paddle API.

  ## Options

  * `:config` - Custom configuration (overrides default)
  * `:headers` - Additional headers to send
  * `:timeout` - Request timeout in milliseconds
  """
  @spec request(method(), String.t(), map() | nil, params(), keyword()) :: response()
  def request(method, path, body \\ nil, params \\ %{}, opts \\ []) do
    config = Keyword.get(opts, :config, Config.resolve())
    Config.validate!(config)

    url = build_url(config.base_url, path, params)
    headers = build_headers(config, Keyword.get(opts, :headers, []))
    timeout = Keyword.get(opts, :timeout, config.timeout)

    request_opts = [
      receive_timeout: timeout,
      headers: headers,
      retry: if(config.retry, do: :transient, else: false),
      # Disable automatic JSON decoding to handle malformed responses
      raw: true
    ]

    request_opts =
      if should_include_body?(body, method) do
        [{:json, body} | request_opts]
      else
        request_opts
      end

    try do
      case Req.request([method: method, url: url] ++ request_opts) do
        {:ok, %{status: status} = response} when status in 200..299 ->
          body = Map.get(response, :body)
          headers = Map.get(response, :headers, [])
          handle_success_response(body, headers)

        {:ok, %{status: status} = response} ->
          body = Map.get(response, :body)
          decoded_body = decode_error_body(body)
          {:error, Error.from_status(status, decoded_body)}

        {:error, %{reason: :timeout}} ->
          {:error, Error.timeout_error(timeout)}

        {:error, %{reason: reason}} ->
          {:error, Error.network_error(inspect(reason))}

        {:error, reason} ->
          {:error, Error.network_error(inspect(reason))}
      end
    rescue
      error ->
        {:error, Error.network_error("JSON decode error: #{inspect(error)}")}
    end
  end

  # Private functions

  @spec build_url(String.t(), String.t(), params()) :: String.t()
  defp build_url(base_url, path, params) when params == %{} or params == [] do
    validated_path = validate_path!(path)
    base_url <> ensure_leading_slash(validated_path)
  end

  defp build_url(base_url, path, params) do
    validated_path = validate_path!(path)
    normalized_params = normalize_query_params(params)
    query_string = encode_query_with_comma_arrays(normalized_params)
    base_url <> ensure_leading_slash(validated_path) <> "?" <> query_string
  end

  @spec validate_path!(String.t()) :: String.t() | no_return()
  defp validate_path!(path) do
    # Check for path traversal attempts
    if String.contains?(path, "..") do
      raise ArgumentError, "Path traversal attack detected in path: #{path}"
    end

    # Check for suspicious patterns
    malicious_patterns = [
      # Path traversal
      ~r/\.\./,
      # Unix path traversal
      ~r/\/\.\./,
      # Windows path traversal
      ~r/\\\.\./,
      # URL encoded path traversal
      ~r/%2F%2E%2E/i,
      # URL encoded Windows path traversal
      ~r/%5C%2E%2E/i
    ]

    for pattern <- malicious_patterns do
      if Regex.match?(pattern, path) do
        raise ArgumentError, "Malicious path pattern detected: #{path}"
      end
    end

    path
  end

  @spec ensure_leading_slash(String.t()) :: String.t()
  defp ensure_leading_slash("/" <> _ = path), do: path
  defp ensure_leading_slash(path), do: "/" <> path

  # Normalize query parameters for Paddle API
  # Arrays should be converted to comma-separated strings
  # Nested maps should be flattened to bracket notation (e.g., billed_at[from])
  @spec normalize_query_params(params()) :: map()
  defp normalize_query_params(params) when is_map(params) do
    Enum.reduce(params, %{}, fn {key, value}, acc ->
      case value do
        %{} = nested_map when map_size(nested_map) > 0 ->
          flatten_nested_map(nested_map, key, acc)

        _ ->
          normalized_value = normalize_param_value(value)
          Map.put(acc, key, normalized_value)
      end
    end)
  end

  defp normalize_query_params(params) when is_list(params) do
    params
    |> Enum.into(%{})
    |> normalize_query_params()
  end

  defp normalize_query_params(_params), do: %{}

  @spec should_include_body?(any(), method()) :: boolean()
  defp should_include_body?(nil, _method), do: false

  defp should_include_body?(body, method) when method in [:post, :patch, :put] do
    case body do
      %{} = map when map_size(map) == 0 -> false
      _ -> true
    end
  end

  defp should_include_body?(_body, _method), do: false

  @spec normalize_param_value(any()) :: String.t()
  defp normalize_param_value(value) when is_list(value) do
    Enum.map_join(value, ",", &to_string/1)
  end

  defp normalize_param_value(value) when is_atom(value) do
    Atom.to_string(value)
  end

  defp normalize_param_value(value) when is_number(value) do
    to_string(value)
  end

  defp normalize_param_value(value) when is_binary(value) do
    value
  end

  defp normalize_param_value(value) when is_map(value) do
    # Nested maps should be handled in normalize_query_params via bracket notation
    # If we reach here, it means the map wasn't properly flattened, so convert to string
    to_string(value)
  end

  defp normalize_param_value(value) do
    to_string(value)
  end

  @spec encode_query_with_comma_arrays(Enumerable.t()) :: String.t()
  defp encode_query_with_comma_arrays(params) do
    params
    |> Enum.map_join("&", fn {key, value} ->
      encoded_key = URI.encode_www_form(to_string(key))
      encoded_value = encode_query_value_preserving_commas(value)
      "#{encoded_key}=#{encoded_value}"
    end)
  end

  defp encode_query_value_preserving_commas(value) do
    # Split on commas, encode each part, then rejoin with unencoded commas
    case String.split(to_string(value), ",") do
      [single_value] ->
        # No commas, encode normally
        URI.encode_www_form(single_value)

      parts ->
        # Has commas, encode each part and rejoin with raw commas
        parts
        |> Enum.map_join(",", &URI.encode_www_form/1)
    end
  end

  @spec build_headers(Config.config(), headers()) :: headers()
  defp build_headers(config, additional_headers) do
    base_headers = [
      {"Authorization", "Bearer #{config.api_key}"},
      {"Content-Type", "application/json"},
      {"Accept", "application/json"},
      {"User-Agent", "paddle_billing_ex/0.1.0 (Elixir)"}
    ]

    # Add Paddle-Version header for API versioning
    versioned_headers = [{"Paddle-Version", "1"} | base_headers]

    # Filter out security-critical headers that should not be overridden
    safe_additional_headers = filter_safe_headers(additional_headers)

    # Merge safe additional headers only
    Enum.reduce(safe_additional_headers, versioned_headers, fn {key, value}, acc ->
      [{key, value} | Enum.reject(acc, fn {k, _} -> k == key end)]
    end)
  end

  # List of headers that should not be overridden for security reasons
  @protected_headers ["authorization", "host", "content-type", "accept", "paddle-version"]

  @spec filter_safe_headers(headers()) :: headers()
  defp filter_safe_headers(headers) do
    Enum.reject(headers, fn {key, _value} ->
      String.downcase(key) in @protected_headers
    end)
  end

  @spec handle_success_response(any(), list()) :: {:ok, any()} | {:error, Error.t()}
  defp handle_success_response("", _headers), do: {:ok, nil}
  defp handle_success_response(nil, _headers), do: {:ok, nil}

  defp handle_success_response(body, headers) when is_binary(body) do
    if content_type_is_json?(headers) or looks_like_json?(body) do
      case JSON.decode(body) do
        {:ok, parsed} -> handle_parsed_success_response(parsed)
        {:error, _jason_error} -> handle_json_decode_error(body, headers)
      end
    else
      # Return plain text as-is
      {:ok, body}
    end
  end

  defp handle_success_response(body, _headers) when is_map(body) do
    handle_parsed_success_response(body)
  end

  defp handle_success_response(body, _headers) when is_list(body) do
    {:ok, body}
  end

  defp handle_success_response(body, _headers) do
    {:ok, body}
  end

  defp handle_json_decode_error(body, headers) do
    # If JSON parsing fails but content-type says it's JSON, return error
    # Otherwise, return the raw body for plain text responses
    if content_type_is_json?(headers) do
      {:error, Error.network_error("JSON decode error: malformed JSON response")}
    else
      {:ok, body}
    end
  end

  defp flatten_nested_map(nested_map, key, acc) do
    # Flatten nested maps to bracket notation
    Enum.reduce(nested_map, acc, fn {nested_key, nested_value}, nested_acc ->
      flattened_key = "#{key}[#{nested_key}]"
      normalized_value = normalize_param_value(nested_value)
      Map.put(nested_acc, flattened_key, normalized_value)
    end)
  end

  @spec handle_parsed_success_response(any()) :: {:ok, any()}
  defp handle_parsed_success_response(body) when is_map(body) do
    # Paddle API typically returns data in a "data" field
    case Map.get(body, "data") do
      nil -> {:ok, body}
      data -> {:ok, data}
    end
  end

  defp handle_parsed_success_response(body) when is_list(body) do
    {:ok, body}
  end

  defp handle_parsed_success_response(body) do
    {:ok, body}
  end

  @spec decode_error_body(any()) :: any()
  defp decode_error_body(body) when is_binary(body) do
    case JSON.decode(body) do
      {:ok, parsed} -> parsed
      {:error, _decode_error} -> body
    end
  end

  defp decode_error_body(body), do: body

  @spec content_type_is_json?(list()) :: boolean()
  defp content_type_is_json?(headers) do
    content_type =
      headers
      |> Enum.find_value(fn
        {"content-type", value} -> value
        {"Content-Type", value} -> value
        _ -> nil
      end)

    case content_type do
      nil -> false
      value when is_binary(value) -> String.contains?(String.downcase(value), "application/json")
      _ -> false
    end
  end

  @spec looks_like_json?(binary()) :: boolean()
  defp looks_like_json?(body) when is_binary(body) do
    trimmed = String.trim(body)

    (String.starts_with?(trimmed, "{") and String.ends_with?(trimmed, "}")) or
      (String.starts_with?(trimmed, "[") and String.ends_with?(trimmed, "]"))
  end


end
