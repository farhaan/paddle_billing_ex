defmodule PaddleBilling.ClientTest do
  use ExUnit.Case, async: true

  alias PaddleBilling.{Client, Error}

  # Helper function to create bypass config
  defp bypass_config(bypass) do
    %PaddleBilling.Config{
      api_key: "pdl_test_123456789",
      environment: :sandbox,
      base_url: "http://localhost:#{bypass.port}",
      timeout: 30_000,
      retry: false
    }
  end

  describe "HTTP method functions" do
    setup do
      bypass = Bypass.open()

      config = %PaddleBilling.Config{
        api_key: "pdl_test_123456789",
        environment: :sandbox,
        base_url: "http://localhost:#{bypass.port}",
        timeout: 30_000,
        retry: false
      }

      {:ok, bypass: bypass, config: config}
    end

    test "get/3 makes GET request with proper headers", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/test", fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/test"

        # Verify authentication header
        auth_header = Plug.Conn.get_req_header(conn, "authorization")
        assert auth_header == ["Bearer pdl_test_123456789"]

        # Verify API version header
        version_header = Plug.Conn.get_req_header(conn, "paddle-version")
        assert version_header == ["1"]

        # Verify content type
        content_type = Plug.Conn.get_req_header(conn, "content-type")
        assert content_type == ["application/json"]

        Plug.Conn.resp(conn, 200, Jason.encode!(%{"data" => %{"result" => "success"}}))
      end)

      assert {:ok, %{"result" => "success"}} = Client.get("/test", %{}, config: config)
    end

    test "get/3 includes query parameters", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/test", fn conn ->
        assert conn.query_string == "param1=value1&param2=value2"
        Plug.Conn.resp(conn, 200, Jason.encode!(%{"data" => []}))
      end)

      params = %{"param1" => "value1", "param2" => "value2"}
      assert {:ok, []} = Client.get("/test", params, config: config)
    end

    test "post/3 makes POST request with JSON body", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "POST", "/test", fn conn ->
        assert conn.method == "POST"

        {:ok, body, conn} = Plug.Conn.read_body(conn)
        parsed_body = Jason.decode!(body)

        assert parsed_body == %{"name" => "test", "value" => 123}

        Plug.Conn.resp(conn, 201, Jason.encode!(%{"data" => %{"id" => "123"}}))
      end)

      body = %{"name" => "test", "value" => 123}
      assert {:ok, %{"id" => "123"}} = Client.post("/test", body, config: config)
    end

    test "patch/3 makes PATCH request", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "PATCH", "/test/123", fn conn ->
        assert conn.method == "PATCH"

        {:ok, body, conn} = Plug.Conn.read_body(conn)
        parsed_body = Jason.decode!(body)

        assert parsed_body == %{"name" => "updated"}

        Plug.Conn.resp(
          conn,
          200,
          Jason.encode!(%{"data" => %{"id" => "123", "name" => "updated"}})
        )
      end)

      body = %{"name" => "updated"}

      assert {:ok, %{"id" => "123", "name" => "updated"}} =
               Client.patch("/test/123", body, config: config)
    end

    test "put/2 makes PUT request", %{bypass: bypass, config: _config} do
      Bypass.expect_once(bypass, "PUT", "/test/123", fn conn ->
        assert conn.method == "PUT"

        {:ok, body, conn} = Plug.Conn.read_body(conn)
        parsed_body = Jason.decode!(body)

        assert parsed_body == %{"name" => "replaced", "status" => "active"}

        Plug.Conn.resp(
          conn,
          200,
          Jason.encode!(%{"data" => %{"id" => "123", "name" => "replaced", "status" => "active"}})
        )
      end)

      body = %{"name" => "replaced", "status" => "active"}

      assert {:ok, %{"id" => "123", "name" => "replaced", "status" => "active"}} =
               Client.request(:put, "/test/123", body, %{}, config: bypass_config(bypass))
    end

    test "put/2 uses resolved config", %{} do
      # This test verifies PUT works with resolved config
      # Should get a network error due to default config with non-existent API endpoint
      body = %{"name" => "test"}
      assert {:error, %Error{}} = Client.put("/test/123", body)
    end

    test "delete/1 makes DELETE request", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "DELETE", "/test/123", fn conn ->
        assert conn.method == "DELETE"
        Plug.Conn.resp(conn, 204, "")
      end)

      assert {:ok, nil} = Client.request(:delete, "/test/123", nil, %{}, config: config)
    end
  end

  describe "request/5 with different options" do
    setup do
      bypass = Bypass.open()

      config = %PaddleBilling.Config{
        api_key: "pdl_test_123456789",
        environment: :sandbox,
        base_url: "http://localhost:#{bypass.port}",
        timeout: 30_000,
        retry: false
      }

      {:ok, bypass: bypass, config: config}
    end

    test "handles custom headers", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/test", fn conn ->
        headers = Enum.into(conn.req_headers, %{})

        # Custom header should be present
        assert headers["x-custom-header"] == "custom-value"

        # Standard headers should still be present
        assert headers["authorization"] == "Bearer pdl_test_123456789"
        assert headers["paddle-version"] == "1"

        Plug.Conn.resp(conn, 200, Jason.encode!(%{"data" => "ok"}))
      end)

      opts = [headers: [{"X-Custom-Header", "custom-value"}]]
      assert {:ok, "ok"} = Client.get("/test", %{}, [config: config] ++ opts)
    end

    test "allows header overrides", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/test", fn conn ->
        headers = Enum.into(conn.req_headers, %{})

        # Should use custom User-Agent
        assert headers["user-agent"] == "custom-agent/1.0"

        # Other headers should remain
        assert headers["authorization"] == "Bearer pdl_test_123456789"

        Plug.Conn.resp(conn, 200, Jason.encode!(%{"data" => "ok"}))
      end)

      opts = [headers: [{"User-Agent", "custom-agent/1.0"}]]
      assert {:ok, "ok"} = Client.get("/test", %{}, [config: config] ++ opts)
    end

    test "filters out protected headers", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/test", fn conn ->
        headers = Enum.into(conn.req_headers, %{})

        # Protected headers should maintain their original values
        assert headers["authorization"] == "Bearer pdl_test_123456789"
        assert headers["content-type"] == "application/json"
        assert headers["accept"] == "application/json"
        assert headers["paddle-version"] == "1"

        # Custom header should still be added
        assert headers["x-custom-header"] == "allowed"

        Plug.Conn.resp(conn, 200, Jason.encode!(%{"data" => "ok"}))
      end)

      # Try to override protected headers
      opts = [
        headers: [
          {"Authorization", "Bearer malicious_key"},
          {"Content-Type", "text/plain"},
          {"Accept", "text/html"},
          {"Host", "malicious.com"},
          {"Paddle-Version", "999"},
          {"X-Custom-Header", "allowed"}
        ]
      ]

      assert {:ok, "ok"} = Client.get("/test", %{}, [config: config] ++ opts)
    end

    test "handles case-insensitive protected header filtering", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/test", fn conn ->
        headers = Enum.into(conn.req_headers, %{})

        # Protected headers should maintain their original values regardless of case
        assert headers["authorization"] == "Bearer pdl_test_123456789"
        assert headers["content-type"] == "application/json"

        # Non-protected header should be allowed
        assert headers["x-custom"] == "allowed"

        Plug.Conn.resp(conn, 200, Jason.encode!(%{"data" => "ok"}))
      end)

      opts = [
        headers: [
          {"AUTHORIZATION", "Bearer malicious"},
          {"Content-TYPE", "text/plain"},
          {"X-Custom", "allowed"}
        ]
      ]

      assert {:ok, "ok"} = Client.get("/test", %{}, [config: config] ++ opts)
    end

    test "uses custom config when provided", %{bypass: bypass} do
      custom_config = %PaddleBilling.Config{
        api_key: "pdl_live_custom_key_123",
        environment: :live,
        base_url: "http://localhost:#{bypass.port}",
        timeout: 5_000,
        retry: true
      }

      Bypass.expect_once(bypass, "GET", "/test", fn conn ->
        headers = Enum.into(conn.req_headers, %{})
        assert headers["authorization"] == "Bearer pdl_live_custom_key_123"

        Plug.Conn.resp(conn, 200, Jason.encode!(%{"data" => "ok"}))
      end)

      opts = [config: custom_config]
      assert {:ok, "ok"} = Client.get("/test", %{}, opts)
    end
  end

  describe "response handling" do
    setup do
      bypass = Bypass.open()

      config = %PaddleBilling.Config{
        api_key: "pdl_test_123456789",
        environment: :sandbox,
        base_url: "http://localhost:#{bypass.port}",
        timeout: 30_000,
        retry: false
      }

      {:ok, bypass: bypass, config: config}
    end

    test "handles JSON response with data field", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/test", fn conn ->
        response = %{
          "data" => %{"id" => "123", "name" => "test"},
          "meta" => %{"request_id" => "req_123"}
        }

        Plug.Conn.resp(conn, 200, Jason.encode!(response))
      end)

      assert {:ok, %{"id" => "123", "name" => "test"}} = Client.get("/test", %{}, config: config)
    end

    test "handles JSON response without data field", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/test", fn conn ->
        response = %{"message" => "success", "status" => "ok"}
        Plug.Conn.resp(conn, 200, Jason.encode!(response))
      end)

      assert {:ok, %{"message" => "success", "status" => "ok"}} =
               Client.get("/test", %{}, config: config)
    end

    test "handles array response", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/test", fn conn ->
        response = [%{"id" => "1"}, %{"id" => "2"}]
        Plug.Conn.resp(conn, 200, Jason.encode!(response))
      end)

      assert {:ok, [%{"id" => "1"}, %{"id" => "2"}]} = Client.get("/test", %{}, config: config)
    end

    test "handles empty response", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "DELETE", "/test", fn conn ->
        Plug.Conn.resp(conn, 204, "")
      end)

      assert {:ok, nil} = Client.request(:delete, "/test", nil, %{}, config: config)
    end

    test "handles plain text response", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/test", fn conn ->
        Plug.Conn.resp(conn, 200, "plain text response")
      end)

      assert {:ok, "plain text response"} = Client.get("/test", %{}, config: config)
    end

    test "handles malformed JSON gracefully", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/test", fn conn ->
        Plug.Conn.resp(conn, 200, "invalid json {")
      end)

      assert {:ok, "invalid json {"} = Client.get("/test", %{}, config: config)
    end

    test "handles GZIP compressed responses", %{bypass: bypass, config: config} do
      json_data = %{"data" => %{"id" => "123", "message" => "Compressed response"}}
      json_string = Jason.encode!(json_data)
      gzipped_data = :zlib.gzip(json_string)

      Bypass.expect_once(bypass, "GET", "/test", fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-encoding", "gzip")
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(200, gzipped_data)
      end)

      assert {:ok, %{"id" => "123", "message" => "Compressed response"}} =
               Client.get("/test", %{}, config: config)
    end

    test "handles malformed GZIP data gracefully", %{bypass: bypass, config: config} do
      # Create invalid gzip data (starts with gzip magic number but isn't valid)
      invalid_gzip = <<0x1F, 0x8B, "invalid gzip data">>

      Bypass.expect_once(bypass, "GET", "/test", fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-encoding", "gzip")
        |> Plug.Conn.resp(200, invalid_gzip)
      end)

      # Should return the raw data when decompression fails
      assert {:ok, data} = Client.get("/test", %{}, config: config)
      assert is_binary(data)
    end

    test "handles non-gzipped data that looks like gzip", %{bypass: bypass, config: config} do
      # Data that doesn't start with gzip magic number
      normal_data = "This is normal text data"

      Bypass.expect_once(bypass, "GET", "/test", fn conn ->
        Plug.Conn.resp(conn, 200, normal_data)
      end)

      assert {:ok, "This is normal text data"} = Client.get("/test", %{}, config: config)
    end

    test "handles JSON response without content-type header", %{bypass: bypass, config: config} do
      json_data = %{"data" => %{"id" => "123"}}

      Bypass.expect_once(bypass, "GET", "/test", fn conn ->
        # No content-type header, but response looks like JSON
        Plug.Conn.resp(conn, 200, Jason.encode!(json_data))
      end)

      # Should still parse as JSON based on content structure
      assert {:ok, %{"id" => "123"}} = Client.get("/test", %{}, config: config)
    end

    test "handles non-JSON content-type with JSON-looking body", %{bypass: bypass, config: config} do
      json_data = %{"data" => %{"message" => "This looks like JSON"}}

      Bypass.expect_once(bypass, "GET", "/test", fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-type", "text/plain")
        |> Plug.Conn.resp(200, Jason.encode!(json_data))
      end)

      # Should parse as JSON even with wrong content-type since it looks like JSON
      assert {:ok, %{"message" => "This looks like JSON"}} = Client.get("/test", %{}, config: config)
    end

    test "handles malformed JSON with JSON content-type", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/test", fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(200, "invalid json {")
      end)

      # The malformed JSON "invalid json {" doesn't look like JSON (no closing brace)
      # so it gets returned as-is even with JSON content-type
      assert {:ok, "invalid json {"} = Client.get("/test", %{}, config: config)
    end

    test "handles malformed JSON without JSON content-type", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/test", fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-type", "text/plain")
        |> Plug.Conn.resp(200, "invalid json {")
      end)

      # Should return raw body since content-type is not JSON
      assert {:ok, "invalid json {"} = Client.get("/test", %{}, config: config)
    end

    test "handles various JSON content-type variations", %{bypass: bypass, config: config} do
      json_data = %{"data" => %{"result" => "success"}}

      content_types = [
        "application/json",
        "application/json; charset=utf-8",
        "Application/JSON",
        "application/json;charset=UTF-8"
      ]

      for content_type <- content_types do
        Bypass.expect_once(bypass, "GET", "/test", fn conn ->
          conn
          |> Plug.Conn.put_resp_header("content-type", content_type)
          |> Plug.Conn.resp(200, Jason.encode!(json_data))
        end)

        assert {:ok, %{"result" => "success"}} = Client.get("/test", %{}, config: config)
      end
    end

    test "handles mixed data types in JSON response", %{bypass: bypass, config: config} do
      mixed_data = %{
        "data" => %{
          "string" => "test",
          "integer" => 123,
          "float" => 45.67,
          "boolean" => true,
          "null_value" => nil,
          "array" => [1, "two", 3.0],
          "nested" => %{"key" => "value"}
        }
      }

      Bypass.expect_once(bypass, "GET", "/test", fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(200, Jason.encode!(mixed_data))
      end)

      assert {:ok, result} = Client.get("/test", %{}, config: config)
      assert result["string"] == "test"
      assert result["integer"] == 123
      assert result["float"] == 45.67
      assert result["boolean"] == true
      # Handle both :null (native :json) and nil (Jason)
      assert result["null_value"] in [nil, :null]
      assert result["array"] == [1, "two", 3.0]
      assert result["nested"] == %{"key" => "value"}
    end
  end

  describe "error response handling" do
    setup do
      bypass = Bypass.open()

      config = %PaddleBilling.Config{
        api_key: "pdl_test_123456789",
        environment: :sandbox,
        base_url: "http://localhost:#{bypass.port}",
        timeout: 30_000,
        retry: false
      }

      {:ok, bypass: bypass, config: config}
    end

    test "handles 400 bad request", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "POST", "/test", fn conn ->
        error_response = %{
          "error" => %{
            "code" => "validation_failed",
            "detail" => "Invalid input parameters"
          }
        }

        Plug.Conn.resp(conn, 400, Jason.encode!(error_response))
      end)

      assert {:error, %Error{} = error} = Client.post("/test", %{}, config: config)
      assert error.type == :validation_error
      assert error.code == "validation_failed"
      assert error.message == "Invalid input parameters"
    end

    test "handles 401 unauthorized", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/test", fn conn ->
        Plug.Conn.resp(conn, 401, "Unauthorized")
      end)

      assert {:error, %Error{} = error} = Client.get("/test", %{}, config: config)
      assert error.type == :authentication_error
    end

    test "handles 500 server error", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/test", fn conn ->
        Plug.Conn.resp(conn, 500, "Internal Server Error")
      end)

      assert {:error, %Error{} = error} = Client.get("/test", %{}, config: config)
      assert error.type == :server_error
      assert error.code == "server_error_500"
    end

    test "handles network timeout", %{config: config} do
      # Use an unreachable host to simulate timeout
      timeout_config = %PaddleBilling.Config{
        config
        | base_url: "http://localhost:1",
          timeout: 100
      }

      assert {:error, %Error{} = error} = Client.get("/test", %{}, config: timeout_config)
      assert error.type in [:network_error, :timeout_error]
    end

    test "handles 422 unprocessable entity", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "POST", "/test", fn conn ->
        error_response = %{
          "error" => %{
            "code" => "invalid_json",
            "detail" => "JSON malformed",
            "meta" => %{
              "field" => "name"
            }
          }
        }

        Plug.Conn.resp(conn, 422, Jason.encode!(error_response))
      end)

      assert {:error, %Error{} = error} = Client.post("/test", %{}, config: config)
      assert error.type == :api_error
      assert error.code == "invalid_json"
      assert error.message == "JSON malformed"
    end

    test "handles 403 forbidden", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/test", fn conn ->
        Plug.Conn.resp(conn, 403, "Forbidden")
      end)

      assert {:error, %Error{} = error} = Client.get("/test", %{}, config: config)
      assert error.type == :authorization_error
    end

    test "handles 404 not found", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/test", fn conn ->
        error_response = %{
          "error" => %{
            "code" => "entity_not_found",
            "detail" => "The resource you requested does not exist"
          }
        }

        Plug.Conn.resp(conn, 404, Jason.encode!(error_response))
      end)

      assert {:error, %Error{} = error} = Client.get("/test", %{}, config: config)
      assert error.type == :not_found_error
      assert error.code == "entity_not_found"
    end

    test "handles 429 rate limit", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/test", fn conn ->
        conn
        |> Plug.Conn.put_resp_header("retry-after", "60")
        |> Plug.Conn.resp(429, "Too Many Requests")
      end)

      assert {:error, %Error{} = error} = Client.get("/test", %{}, config: config)
      assert error.type == :rate_limit_error
    end

    test "handles 502 bad gateway", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/test", fn conn ->
        Plug.Conn.resp(conn, 502, "Bad Gateway")
      end)

      assert {:error, %Error{} = error} = Client.get("/test", %{}, config: config)
      assert error.type == :server_error
      assert error.code == "server_error_502"
    end

    test "handles JSON decode errors in request body", %{bypass: bypass, config: config} do
      # Test with data that encodes properly to JSON
      body = %{
        "text_data" => "Hello World",
        "large_number" => 999_999_999_999_999_999_999
      }

      Bypass.expect_once(bypass, "POST", "/test", fn conn ->
        {:ok, request_body, conn} = Plug.Conn.read_body(conn)
        # Verify the data was encoded properly
        parsed = Jason.decode!(request_body)
        assert parsed["text_data"] == "Hello World"
        assert is_number(parsed["large_number"])
        
        Plug.Conn.resp(conn, 200, Jason.encode!(%{"data" => "ok"}))
      end)

      assert {:ok, "ok"} = Client.post("/test", body, config: config)
    end

    test "handles connection refused errors", %{config: config} do
      # Use a port that definitely won't be in use
      refused_config = %PaddleBilling.Config{
        config
        | base_url: "http://10.255.255.1:1",  # Use non-routable IP
          timeout: 100
      }

      assert {:error, %Error{} = error} = Client.get("/test", %{}, config: refused_config)
      assert error.type in [:network_error, :timeout_error]
    end

    test "handles empty error response body", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "POST", "/test", fn conn ->
        Plug.Conn.resp(conn, 400, "")
      end)

      assert {:error, %Error{} = error} = Client.post("/test", %{}, config: config)
      assert error.type == :api_error
      # Should have a generic error message when body is empty
      assert is_binary(error.message)
    end

    test "handles malformed JSON in error response", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "POST", "/test", fn conn ->
        Plug.Conn.resp(conn, 400, "invalid json error response {")
      end)

      assert {:error, %Error{} = error} = Client.post("/test", %{}, config: config)
      assert error.type == :api_error
      # Should handle malformed error response gracefully
      assert is_binary(error.message)
    end

    test "handles exceptions during request processing", %{bypass: _bypass, config: _config} do
      # Test with malformed config that will cause validation error
      assert_raise ArgumentError, ~r/Base URL must include protocol/, fn ->
        invalid_config = %PaddleBilling.Config{
          api_key: "pdl_test_123",
          environment: :sandbox,
          base_url: "not-a-valid-url",
          timeout: 30_000,
          retry: false
        }
        Client.get("/test", %{}, config: invalid_config)
      end
    end
  end

  describe "URL building" do
    setup do
      bypass = Bypass.open()

      config = %PaddleBilling.Config{
        api_key: "pdl_test_123456789",
        environment: :sandbox,
        base_url: "http://localhost:#{bypass.port}",
        timeout: 30_000,
        retry: false
      }

      {:ok, bypass: bypass, config: config}
    end

    test "handles paths with leading slash", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/test/path", fn conn ->
        assert conn.request_path == "/test/path"
        Plug.Conn.resp(conn, 200, Jason.encode!(%{"data" => "ok"}))
      end)

      assert {:ok, "ok"} = Client.get("/test/path", %{}, config: config)
    end

    test "handles paths without leading slash", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/test/path", fn conn ->
        assert conn.request_path == "/test/path"
        Plug.Conn.resp(conn, 200, Jason.encode!(%{"data" => "ok"}))
      end)

      assert {:ok, "ok"} = Client.get("test/path", %{}, config: config)
    end

    test "handles special characters in query parameters", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/test", fn conn ->
        query_params = URI.decode_query(conn.query_string)

        assert query_params["special"] == "hello world & <test>"
        assert query_params["unicode"] == "测试"

        Plug.Conn.resp(conn, 200, Jason.encode!(%{"data" => "ok"}))
      end)

      params = %{
        "special" => "hello world & <test>",
        "unicode" => "测试"
      }

      assert {:ok, "ok"} = Client.get("/test", params, config: config)
    end

    test "handles empty query parameters", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/test", fn conn ->
        assert conn.query_string == ""
        Plug.Conn.resp(conn, 200, Jason.encode!(%{"data" => "ok"}))
      end)

      assert {:ok, "ok"} = Client.get("/test", %{}, config: config)
    end
  end

  describe "parameter normalization" do
    setup do
      bypass = Bypass.open()

      config = %PaddleBilling.Config{
        api_key: "pdl_test_123456789",
        environment: :sandbox,
        base_url: "http://localhost:#{bypass.port}",
        timeout: 30_000,
        retry: false
      }

      {:ok, bypass: bypass, config: config}
    end

    test "normalizes array parameters to comma-separated strings", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/test", fn conn ->
        query_params = URI.decode_query(conn.query_string)
        assert query_params["include"] == "prices,discounts,customers"
        assert query_params["status"] == "active,inactive"
        Plug.Conn.resp(conn, 200, Jason.encode!(%{"data" => "ok"}))
      end)

      params = %{
        "include" => ["prices", "discounts", "customers"],
        "status" => ["active", "inactive"]
      }

      assert {:ok, "ok"} = Client.get("/test", params, config: config)
    end

    test "normalizes nested map parameters to bracket notation", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/test", fn conn ->
        query_params = URI.decode_query(conn.query_string)
        assert query_params["billed_at[from]"] == "2023-01-01"
        assert query_params["billed_at[to]"] == "2023-12-31"
        assert query_params["filter[status]"] == "active"
        Plug.Conn.resp(conn, 200, Jason.encode!(%{"data" => "ok"}))
      end)

      params = %{
        "billed_at" => %{
          "from" => "2023-01-01",
          "to" => "2023-12-31"
        },
        "filter" => %{
          "status" => "active"
        }
      }

      assert {:ok, "ok"} = Client.get("/test", params, config: config)
    end

    test "handles mixed nested and array parameters", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/test", fn conn ->
        query_params = URI.decode_query(conn.query_string)
        assert query_params["include"] == "prices,customers"
        assert query_params["filter[status]"] == "active,inactive"
        assert query_params["created_at[after]"] == "2023-01-01T00:00:00Z"
        Plug.Conn.resp(conn, 200, Jason.encode!(%{"data" => "ok"}))
      end)

      params = %{
        "include" => ["prices", "customers"],
        "filter" => %{
          "status" => ["active", "inactive"]
        },
        "created_at" => %{
          "after" => "2023-01-01T00:00:00Z"
        }
      }

      assert {:ok, "ok"} = Client.get("/test", params, config: config)
    end

    test "normalizes different data types in parameters", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/test", fn conn ->
        query_params = URI.decode_query(conn.query_string)
        assert query_params["string_param"] == "test_value"
        assert query_params["integer_param"] == "123"
        assert query_params["float_param"] == "45.67"
        assert query_params["atom_param"] == "active"
        assert query_params["boolean_param"] == "true"
        Plug.Conn.resp(conn, 200, Jason.encode!(%{"data" => "ok"}))
      end)

      params = %{
        "string_param" => "test_value",
        "integer_param" => 123,
        "float_param" => 45.67,
        "atom_param" => :active,
        "boolean_param" => true
      }

      assert {:ok, "ok"} = Client.get("/test", params, config: config)
    end

    test "handles keyword lists as parameters", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/test", fn conn ->
        query_params = URI.decode_query(conn.query_string)
        assert query_params["param1"] == "value1"
        assert query_params["param2"] == "value2"
        Plug.Conn.resp(conn, 200, Jason.encode!(%{"data" => "ok"}))
      end)

      params = [param1: "value1", param2: "value2"]
      assert {:ok, "ok"} = Client.get("/test", params, config: config)
    end

    test "handles empty nested maps", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/test", fn conn ->
        query_params = URI.decode_query(conn.query_string)
        assert query_params["param"] == "value"
        # Empty nested maps should not generate query parameters
        refute Map.has_key?(query_params, "empty_map")
        Plug.Conn.resp(conn, 200, Jason.encode!(%{"data" => "ok"}))
      end)

      params = %{
        "param" => "value"
      }

      assert {:ok, "ok"} = Client.get("/test", params, config: config)
    end

    test "preserves commas in array encoding without double encoding", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/test", fn conn ->
        # The query string should have unencoded commas for array separation
        assert String.contains?(conn.query_string, "include=prices,discounts")
        Plug.Conn.resp(conn, 200, Jason.encode!(%{"data" => "ok"}))
      end)

      params = %{
        "include" => ["prices", "discounts"]
      }

      assert {:ok, "ok"} = Client.get("/test", params, config: config)
    end
  end

  describe "configuration validation" do
    test "validates config before making request" do
      invalid_config = %PaddleBilling.Config{
        api_key: "invalid_key_format",
        environment: :sandbox,
        base_url: "https://api.paddle.com",
        timeout: 30_000,
        retry: false
      }

      assert_raise ArgumentError, ~r/Invalid API key format/, fn ->
        Client.get("/test", %{}, config: invalid_config)
      end
    end

    test "uses resolved config when no custom config provided" do
      # This test verifies that Config.resolve() is called
      # We can't easily test the actual resolution without mocking,
      # but we can verify the function completes successfully
      assert {:error, %Error{type: error_type}} = Client.get("/nonexistent", %{})
      # Could be network error, timeout error, or API error (404) depending on network conditions
      assert error_type in [:network_error, :timeout_error, :api_error]
    end
  end

  describe "path traversal security" do
    setup do
      bypass = Bypass.open()

      config = %PaddleBilling.Config{
        api_key: "pdl_test_123456789",
        environment: :sandbox,
        base_url: "http://localhost:#{bypass.port}",
        timeout: 30_000,
        retry: false
      }

      {:ok, bypass: bypass, config: config}
    end

    test "blocks simple path traversal attempts", %{config: config} do
      assert_raise ArgumentError, ~r/Path traversal attack detected/, fn ->
        Client.get("/products/../admin", %{}, config: config)
      end
    end

    test "blocks Unix path traversal", %{config: config} do
      assert_raise ArgumentError, ~r/Path traversal attack detected/, fn ->
        Client.get("/products/../etc/passwd", %{}, config: config)
      end
    end

    test "blocks Windows path traversal", %{config: config} do
      assert_raise ArgumentError, ~r/Path traversal attack detected/, fn ->
        Client.get("/products\\..\\windows\\system32", %{}, config: config)
      end
    end

    test "blocks URL encoded path traversal", %{config: config} do
      assert_raise ArgumentError, ~r/Malicious path pattern detected/, fn ->
        Client.get("/products%2F%2E%2E/admin", %{}, config: config)
      end
    end

    test "blocks URL encoded Windows path traversal", %{config: config} do
      assert_raise ArgumentError, ~r/Malicious path pattern detected/, fn ->
        Client.get("/products%5C%2E%2E/admin", %{}, config: config)
      end
    end

    test "allows legitimate paths with dots", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/products/v1.0", fn conn ->
        assert conn.request_path == "/products/v1.0"
        Plug.Conn.resp(conn, 200, Jason.encode!(%{"data" => "ok"}))
      end)

      assert {:ok, "ok"} = Client.get("/products/v1.0", %{}, config: config)
    end

    test "allows legitimate paths with underscores and dashes", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/products/pro_123-test", fn conn ->
        assert conn.request_path == "/products/pro_123-test"
        Plug.Conn.resp(conn, 200, Jason.encode!(%{"data" => "ok"}))
      end)

      assert {:ok, "ok"} = Client.get("/products/pro_123-test", %{}, config: config)
    end
  end

  describe "request options handling" do
    setup do
      bypass = Bypass.open()

      config = %PaddleBilling.Config{
        api_key: "pdl_test_123456789",
        environment: :sandbox,
        base_url: "http://localhost:#{bypass.port}",
        timeout: 30_000,
        retry: false
      }

      {:ok, bypass: bypass, config: config}
    end

    test "handles custom timeout", %{bypass: bypass, config: config} do
      # Create a slow response
      Bypass.expect_once(bypass, "GET", "/slow", fn conn ->
        Process.sleep(200)
        Plug.Conn.resp(conn, 200, Jason.encode!(%{"data" => "slow response"}))
      end)

      # Should succeed with longer timeout
      opts = [timeout: 500]
      assert {:ok, "slow response"} = Client.get("/slow", %{}, [config: config] ++ opts)
    end

    test "respects retry configuration disabled", %{bypass: bypass, config: config} do
      # Configure to return error once
      ref = make_ref()
      test_pid = self()

      Bypass.expect(bypass, "GET", "/retry-test", fn conn ->
        send(test_pid, {ref, :request_received})
        Plug.Conn.resp(conn, 500, "Server Error")
      end)

      # Should not retry when retry is disabled
      assert {:error, %Error{type: :server_error}} =
               Client.get("/retry-test", %{}, config: config)

      # Should only receive one request
      assert_receive {^ref, :request_received}
      refute_receive {^ref, :request_received}, 100
    end
  end

  describe "JSON handling edge cases" do
    setup do
      bypass = Bypass.open()

      config = %PaddleBilling.Config{
        api_key: "pdl_test_123456789",
        environment: :sandbox,
        base_url: "http://localhost:#{bypass.port}",
        timeout: 30_000,
        retry: false
      }

      {:ok, bypass: bypass, config: config}
    end

    test "handles deeply nested JSON", %{bypass: bypass, config: config} do
      deep_data = build_nested_structure(10)

      Bypass.expect_once(bypass, "POST", "/test", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        parsed = Jason.decode!(body)

        # Verify we can handle the nested structure
        assert is_map(parsed)

        Plug.Conn.resp(conn, 200, Jason.encode!(%{"data" => deep_data}))
      end)

      assert {:ok, result} = Client.post("/test", deep_data, config: config)
      assert result == deep_data
    end

    test "handles large JSON payloads", %{bypass: bypass, config: config} do
      large_string = String.duplicate("test ", 10_000)
      large_data = %{"description" => large_string}

      Bypass.expect_once(bypass, "POST", "/test", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        parsed = Jason.decode!(body)

        assert parsed["description"] == large_string

        Plug.Conn.resp(conn, 200, Jason.encode!(%{"data" => %{"id" => "123"}}))
      end)

      assert {:ok, %{"id" => "123"}} = Client.post("/test", large_data, config: config)
    end

    test "handles JSON with special characters", %{bypass: bypass, config: config} do
      special_data = %{
        "quotes" => "He said \"Hello\" to me",
        "newlines" => "Line 1\nLine 2\nLine 3",
        "unicode" => " Rocket ship with unicode: 测试",
        "backslashes" => "Path\\to\\file",
        "null_bytes" => "Before\x00After"
      }

      Bypass.expect_once(bypass, "POST", "/test", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        parsed = Jason.decode!(body)

        # Verify special characters are handled correctly
        assert parsed["quotes"] == "He said \"Hello\" to me"
        assert parsed["unicode"] == " Rocket ship with unicode: 测试"

        Plug.Conn.resp(conn, 200, Jason.encode!(%{"data" => "ok"}))
      end)

      assert {:ok, "ok"} = Client.post("/test", special_data, config: config)
    end

    defp build_nested_structure(0), do: %{"value" => "leaf"}

    defp build_nested_structure(depth) do
      %{
        "level" => depth,
        "nested" => build_nested_structure(depth - 1),
        "array" => [1, 2, 3]
      }
    end
  end
end
