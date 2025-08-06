defmodule PaddleBilling.ClientTest do
  use ExUnit.Case, async: true

  alias PaddleBilling.{Client, Error}

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
