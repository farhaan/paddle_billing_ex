defmodule PaddleBilling.ErrorTest do
  use ExUnit.Case, async: true

  alias PaddleBilling.Error

  describe "from_response/1" do
    test "handles standard API error format" do
      response = %{
        "error" => %{
          "code" => "product_not_found",
          "detail" => "The product with ID 'pro_123' was not found",
          "meta" => %{"request_id" => "req_123"}
        }
      }

      error = Error.from_response(response)

      assert error.type == :api_error
      assert error.code == "product_not_found"
      assert error.message == "The product with ID 'pro_123' was not found"
      assert error.details == nil
      assert error.meta == %{"request_id" => "req_123"}
    end

    test "handles authentication errors" do
      response = %{
        "error" => %{
          "code" => "authentication_failed",
          "detail" => "Invalid API key provided"
        }
      }

      error = Error.from_response(response)

      assert error.type == :authentication_error
      assert error.code == "authentication_failed"
      assert error.message == "Invalid API key provided"
    end

    test "handles authorization errors" do
      response = %{
        "error" => %{
          "code" => "forbidden",
          "detail" => "Insufficient permissions for this operation"
        }
      }

      error = Error.from_response(response)

      assert error.type == :authorization_error
      assert error.code == "forbidden"
      assert error.message == "Insufficient permissions for this operation"
    end

    test "handles validation errors with multiple fields" do
      response = %{
        "errors" => [
          %{
            "field" => "name",
            "code" => "required",
            "detail" => "Name is required"
          },
          %{
            "field" => "price",
            "code" => "invalid_format",
            "detail" => "Price must be a positive number"
          }
        ]
      }

      error = Error.from_response(response)

      assert error.type == :validation_error
      # From first error
      assert error.code == "required"
      assert error.message == "name: Name is required; price: Price must be a positive number"
      assert error.details == response["errors"]
    end

    test "handles validation errors with missing fields" do
      response = %{
        "errors" => [
          %{
            "code" => "validation_failed",
            "detail" => "Validation failed"
          },
          %{
            "field" => "description"
            # Missing detail/message
          }
        ]
      }

      error = Error.from_response(response)

      assert error.type == :validation_error
      assert String.contains?(error.message, "unknown: Invalid value")
      assert String.contains?(error.message, "description: Invalid value")
    end

    test "handles rate limit errors" do
      response = %{
        "error" => %{
          "code" => "rate_limit_exceeded",
          "detail" => "Too many requests",
          "retry_after" => 60
        }
      }

      error = Error.from_response(response)

      assert error.type == :rate_limit_error
      assert error.code == "rate_limit_exceeded"
      assert error.message == "Too many requests"
      assert error.meta["retry_after"] == 60
    end

    test "handles malformed error responses" do
      malformed_responses = [
        %{"error" => nil},
        %{"error" => "string instead of map"},
        %{"error" => []},
        %{"errors" => nil},
        %{"errors" => "string"},
        %{"errors" => %{}},
        %{},
        nil,
        "not a map",
        42
      ]

      for response <- malformed_responses do
        error = Error.from_response(response)

        assert error.type == :unknown_error
        assert error.code == nil
        assert error.message == "Unexpected error response format"
        assert error.details == response
      end
    end

    test "handles empty error responses" do
      response = %{"error" => %{}}

      error = Error.from_response(response)

      assert error.type == :api_error
      assert error.code == nil
      assert error.message == "Unknown API error"
      assert error.details == nil
    end

    test "handles error with legacy message field" do
      response = %{
        "error" => %{
          "code" => "legacy_error",
          "message" => "Legacy error message"
          # No "detail" field
        }
      }

      error = Error.from_response(response)

      assert error.type == :api_error
      assert error.code == "legacy_error"
      assert error.message == "Legacy error message"
    end
  end

  describe "from_status/2" do
    test "handles 401 unauthorized" do
      error = Error.from_status(401, nil)

      assert error.type == :authentication_error
      assert error.code == "authentication_failed"
      assert error.message == "Invalid API key or unauthorized access"
    end

    test "handles 403 forbidden" do
      error = Error.from_status(403, "Access denied")

      assert error.type == :authorization_error
      assert error.code == "forbidden"
      assert error.message == "Insufficient permissions for this operation"
    end

    test "handles 429 rate limit" do
      error = Error.from_status(429, "Rate limit exceeded")

      assert error.type == :rate_limit_error
      assert error.code == "rate_limit_exceeded"
      assert error.message == "Rate limit exceeded"
      assert error.details.body == "Rate limit exceeded"
    end

    test "handles 400 with JSON error" do
      json_body =
        Jason.encode!(%{
          "error" => %{
            "code" => "validation_failed",
            "detail" => "Invalid parameters"
          }
        })

      error = Error.from_status(400, json_body)

      assert error.type == :validation_error
      assert error.code == "validation_failed"
      assert error.message == "Invalid parameters"
    end

    test "handles 400 with invalid JSON" do
      error = Error.from_status(400, "invalid json {")

      assert error.type == :api_error
      assert error.code == "client_error_400"
      assert error.message == "Client error (400): invalid json {"
    end

    test "handles 500 server errors" do
      error = Error.from_status(500, "Internal server error")

      assert error.type == :server_error
      assert error.code == "server_error_500"
      assert error.message == "Server error (500): Internal server error"
      assert error.details.status == 500
      assert error.details.body == "Internal server error"
    end

    test "handles unknown status codes" do
      error = Error.from_status(999, "Unknown status")

      assert error.type == :unknown_error
      assert error.code == "http_999"
      assert error.message == "Unexpected HTTP status: 999"
      assert error.details.status == 999
    end

    test "handles nil response body" do
      error = Error.from_status(404, nil)

      assert error.type == :api_error
      assert error.code == "client_error_404"
      assert String.contains?(error.message, "Unknown client error")
    end
  end

  describe "network_error/1" do
    test "creates network error with reason" do
      error = Error.network_error("Connection refused")

      assert error.type == :network_error
      assert error.code == "network_error"
      assert error.message == "Network error: Connection refused"
      assert error.details.reason == "Connection refused"
    end

    test "handles complex error reasons" do
      complex_reason = %{
        reason: :econnrefused,
        host: "api.paddle.com",
        port: 443
      }

      error = Error.network_error(inspect(complex_reason))

      assert error.type == :network_error
      assert error.code == "network_error"
      assert String.contains?(error.message, "econnrefused")
    end
  end

  describe "timeout_error/1" do
    test "creates timeout error with duration" do
      error = Error.timeout_error(30_000)

      assert error.type == :timeout_error
      assert error.code == "timeout"
      assert error.message == "Request timed out after 30000ms"
      assert error.details.timeout == 30_000
    end
  end

  describe "authentication_error/1" do
    test "creates authentication error with default message" do
      error = Error.authentication_error()

      assert error.type == :authentication_error
      assert error.code == "authentication_failed"
      assert error.message == "Authentication failed"
    end

    test "creates authentication error with custom message" do
      error = Error.authentication_error("Invalid API key format")

      assert error.type == :authentication_error
      assert error.code == "authentication_failed"
      assert error.message == "Invalid API key format"
    end
  end

  describe "String.Chars implementation" do
    test "formats error as string" do
      error = %Error{
        type: :authentication_error,
        code: "auth_failed",
        message: "Invalid credentials",
        details: nil,
        meta: nil
      }

      assert to_string(error) == "[authentication_error (auth_failed)] Invalid credentials"
    end

    test "formats error without code" do
      error = %Error{
        type: :network_error,
        code: nil,
        message: "Connection failed",
        details: nil,
        meta: nil
      }

      assert to_string(error) == "[network_error] Connection failed"
    end

    test "handles nil message" do
      error = %Error{
        type: :unknown_error,
        code: nil,
        message: nil,
        details: nil,
        meta: nil
      }

      assert to_string(error) == "[unknown_error] "
    end
  end

  describe "error chaining and context" do
    test "preserves error context through transformations" do
      # Start with a network error
      network_error = Error.network_error("DNS resolution failed")

      # Transform to API error (simulating retry logic)
      api_response = %{
        "error" => %{
          "code" => "network_timeout",
          "detail" => "Request failed due to network issues"
        }
      }

      api_error = Error.from_response(api_response)

      # Both errors should maintain their distinct contexts
      assert network_error.type == :network_error
      assert api_error.type == :api_error
      assert network_error.details.reason == "DNS resolution failed"
      assert api_error.code == "network_timeout"
    end

    test "handles nested error scenarios" do
      # Simulate a scenario where multiple errors occur
      errors = [
        Error.timeout_error(5000),
        Error.network_error("Connection reset"),
        Error.from_status(500, "Internal server error")
      ]

      for error <- errors do
        assert %Error{} = error
        assert error.type in [:timeout_error, :network_error, :server_error]
        assert is_binary(error.message)
      end
    end
  end

  describe "error message sanitization" do
    test "handles potentially dangerous error messages" do
      dangerous_messages = [
        "<script>alert('xss')</script>",
        "'; DROP TABLE users; --",
        "javascript:alert(1)",
        # Control characters
        "\x00\x01\x02\x03",
        # Very long message
        String.duplicate("A", 100_000)
      ]

      for dangerous_message <- dangerous_messages do
        response = %{
          "error" => %{
            "code" => "test_error",
            "detail" => dangerous_message
          }
        }

        error = Error.from_response(response)

        # Should preserve the message (sanitization is client responsibility)
        assert error.message == dangerous_message
        assert error.type == :api_error

        # But to_string should handle it safely
        string_repr = to_string(error)
        assert is_binary(string_repr)
      end
    end

    test "handles unicode and special characters" do
      unicode_messages = [
        # Chinese
        "错误信息",
        # Japanese
        "エラーメッセージ",
        # Russian
        "сообщение об ошибке",
        # Emojis
        "Error occurred!",
        "Message with\nnewlines\tand\ttabs"
      ]

      for unicode_message <- unicode_messages do
        error = Error.authentication_error(unicode_message)

        assert error.message == unicode_message
        assert String.valid?(to_string(error))
      end
    end
  end

  describe "error details preservation" do
    test "preserves all error details from API response" do
      complex_response = %{
        "error" => %{
          "code" => "validation_failed",
          "detail" => "Multiple validation errors",
          "type" => "validation_error",
          "request_id" => "req_123456789",
          "timestamp" => "2023-01-01T00:00:00Z",
          "documentation_url" => "https://docs.paddle.com/errors/validation",
          "errors" => [
            %{"field" => "name", "code" => "required"},
            %{"field" => "price", "code" => "invalid"}
          ]
        }
      }

      error = Error.from_response(complex_response)

      assert error.code == "validation_failed"
      assert error.message == "Multiple validation errors"
      assert error.details == complex_response["error"]["errors"]

      # Meta should contain additional fields
      assert error.meta["type"] == "validation_error"
      assert error.meta["request_id"] == "req_123456789"
      assert error.meta["timestamp"] == "2023-01-01T00:00:00Z"
      assert error.meta["documentation_url"] == "https://docs.paddle.com/errors/validation"
    end

    test "handles minimal error responses" do
      minimal_response = %{
        "error" => %{
          "detail" => "Something went wrong"
        }
      }

      error = Error.from_response(minimal_response)

      assert error.code == nil
      assert error.message == "Something went wrong"
      assert error.details == nil
      assert error.meta == %{}
    end
  end
end
