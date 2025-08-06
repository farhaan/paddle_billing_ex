defmodule PaddleBilling.Error do
  @moduledoc """
  Error handling for Paddle Billing API responses.

  Provides structured error types for different kinds of API failures.
  """

  alias PaddleBilling.JSON

  @type t :: %__MODULE__{
          type: error_type(),
          code: String.t() | nil,
          message: String.t(),
          details: map() | nil,
          meta: map() | nil
        }

  @type error_type ::
          :api_error
          | :authentication_error
          | :authorization_error
          | :validation_error
          | :rate_limit_error
          | :server_error
          | :network_error
          | :timeout_error
          | :not_found_error
          | :unknown_error

  defstruct [:type, :code, :message, :details, :meta]

  @doc """
  Creates a new API error from an HTTP response.
  """
  @spec from_response(any()) :: t()
  def from_response(%{"error" => error_data}) when is_map(error_data) do
    meta_data =
      case Map.get(error_data, "meta") do
        meta when is_map(meta) -> meta
        _ -> Map.drop(error_data, ["code", "detail", "message", "errors", "meta"])
      end

    %__MODULE__{
      type: determine_error_type(error_data, meta_data),
      code: Map.get(error_data, "code"),
      message:
        Map.get(error_data, "detail") || Map.get(error_data, "message") || "Unknown API error",
      details: Map.get(error_data, "errors"),
      meta: meta_data
    }
  end

  def from_response(%{"errors" => errors}) when is_list(errors) and length(errors) > 0 do
    # Handle validation errors with multiple error objects
    main_error = List.first(errors)
    safe_main_error = if is_map(main_error), do: main_error, else: %{}

    %__MODULE__{
      type: :validation_error,
      code: Map.get(safe_main_error, "code"),
      message: format_validation_errors(errors),
      details: errors,
      meta: %{}
    }
  end

  def from_response(response) do
    %__MODULE__{
      type: :unknown_error,
      code: nil,
      message: "Unexpected error response format",
      details: response,
      meta: %{}
    }
  end

  @doc """
  Creates an error from an HTTP status code and response.
  """
  @spec from_status(integer(), any()) :: t()
  def from_status(status, response_body) when status in 400..499 do
    # Try to parse as JSON first, fall back to status-based error
    case parse_response_body(response_body) do
      {:ok, parsed} when is_map(parsed) ->
        # If parsed JSON has error/errors structure, use it
        case parsed do
          %{"error" => _} -> from_response(parsed)
          %{"errors" => _} -> from_response(parsed)
          _ -> client_error(status, response_body)
        end

      {:error, _} ->
        client_error(status, response_body)
    end
  end

  def from_status(status, response_body) when status in 500..599 do
    safe_body =
      case response_body do
        nil -> "Unknown server error"
        body when is_binary(body) -> body
        body -> inspect(body)
      end

    %__MODULE__{
      type: :server_error,
      code: "server_error_#{status}",
      message: "Server error (#{status}): #{safe_body}",
      details: %{status: status, body: response_body},
      meta: %{}
    }
  end

  def from_status(status, response_body) do
    %__MODULE__{
      type: :unknown_error,
      code: "http_#{status}",
      message: "Unexpected HTTP status: #{status}",
      details: %{status: status, body: response_body},
      meta: %{}
    }
  end

  @doc """
  Creates a network error.
  """
  @spec network_error(String.t()) :: t()
  def network_error(reason) do
    %__MODULE__{
      type: :network_error,
      code: "network_error",
      message: "Network error: #{reason}",
      details: %{reason: reason},
      meta: %{}
    }
  end

  @doc """
  Creates a timeout error.
  """
  @spec timeout_error(non_neg_integer()) :: t()
  def timeout_error(timeout_ms) do
    %__MODULE__{
      type: :timeout_error,
      code: "timeout",
      message: "Request timed out after #{timeout_ms}ms",
      details: %{timeout: timeout_ms},
      meta: %{}
    }
  end

  @doc """
  Creates an authentication error.
  """
  @spec authentication_error(String.t()) :: t()
  def authentication_error(message \\ "Authentication failed") do
    %__MODULE__{
      type: :authentication_error,
      code: "authentication_failed",
      message: message,
      details: %{},
      meta: %{}
    }
  end

  # Private functions

  @spec parse_response_body(any()) :: {:ok, map()} | {:error, :invalid}
  defp parse_response_body(response_body) when is_map(response_body) do
    {:ok, response_body}
  end

  defp parse_response_body(response_body) do
    safe_body =
      case response_body do
        nil -> "{}"
        body when is_binary(body) -> body
        _ -> "{}"
      end

    case JSON.decode(safe_body) do
      {:ok, parsed} when is_map(parsed) -> {:ok, parsed}
      {:ok, _non_map} -> {:error, :invalid}
      {:error, _} -> {:error, :invalid}
    end
  end

  @spec determine_error_type(map(), map()) :: error_type()
  defp determine_error_type(error_data, meta_data) do
    # First check meta.type for validation errors
    case Map.get(meta_data, "type") do
      "validation_error" -> :validation_error
      _ -> determine_error_type_from_code(error_data)
    end
  end

  defp determine_error_type_from_code(error_data) do
    case Map.get(error_data, "code") do
      "authentication_failed" -> :authentication_error
      "unauthorized" -> :authentication_error
      "forbidden" -> :authorization_error
      "rate_limit_exceeded" -> :rate_limit_error
      "entity_not_found" -> :not_found_error
      "validation_failed" -> :validation_error
      _ -> :api_error
    end
  end

  @spec client_error(integer(), any()) :: t()

  defp client_error(401, _body) do
    authentication_error("Invalid API key or unauthorized access")
  end

  defp client_error(403, _body) do
    %__MODULE__{
      type: :authorization_error,
      code: "forbidden",
      message: "Insufficient permissions for this operation",
      details: %{},
      meta: %{}
    }
  end

  defp client_error(404, body) do
    safe_body =
      case body do
        nil -> "Unknown client error"
        body when is_binary(body) -> body
        body -> inspect(body)
      end

    %__MODULE__{
      type: :api_error,
      code: "client_error_404",
      message: "Client error (404): #{safe_body}",
      details: %{status: 404, body: body},
      meta: %{}
    }
  end

  defp client_error(429, body) do
    %__MODULE__{
      type: :rate_limit_error,
      code: "rate_limit_exceeded",
      message: "Rate limit exceeded",
      details: %{body: body},
      meta: %{}
    }
  end

  defp client_error(status, body) do
    safe_body =
      case body do
        nil -> "Unknown client error"
        body when is_binary(body) -> body
        body -> inspect(body)
      end

    %__MODULE__{
      type: :api_error,
      code: "client_error_#{status}",
      message: "Client error (#{status}): #{safe_body}",
      details: %{status: status, body: body},
      meta: %{}
    }
  end

  @spec format_validation_errors(list()) :: String.t()
  defp format_validation_errors(errors) when is_list(errors) do
    Enum.map_join(errors, "; ", &format_single_validation_error/1)
  end

  defp format_single_validation_error(error) when is_map(error) do
    field = Map.get(error, "field") || "unknown"
    message = extract_error_message(error)
    "#{field}: #{message}"
  end

  defp format_single_validation_error(_error) do
    "Invalid validation error format"
  end

  defp extract_error_message(error) do
    case {Map.get(error, "field"), Map.get(error, "detail"), Map.get(error, "message")} do
      {nil, _detail, _message} -> "Invalid value"
      {_field, detail, _message} when is_binary(detail) -> detail
      {_field, _detail, message} when is_binary(message) -> message
      _ -> "Invalid value"
    end
  end
end

defimpl String.Chars, for: PaddleBilling.Error do
  def to_string(%PaddleBilling.Error{type: type, code: code, message: message}) do
    safe_message =
      case message do
        nil -> ""
        msg when is_binary(msg) -> msg
        msg -> inspect(msg)
      end

    code_part = if code, do: " (#{code})", else: ""
    "[#{type}#{code_part}] #{safe_message}"
  end
end
