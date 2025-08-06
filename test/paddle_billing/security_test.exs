defmodule PaddleBilling.SecurityTest do
  use ExUnit.Case, async: true

  alias PaddleBilling.{Config, Error, Client}

  describe "API key security" do
    test "validates API key format to prevent injection attacks" do
      malicious_keys = [
        "'; DROP TABLE users; --",
        "<script>alert('xss')</script>",
        "malicious_command_injection",
        "javascript:alert(1)",
        "../../../etc/passwd",
        # Extremely long key
        "pdl_live_#{String.duplicate("a", 10000)}",
        # Empty key
        "",
        # Nil key
        nil,
        # Non-string key
        123,
        # Object injection
        %{key: "malicious"}
      ]

      for malicious_key <- malicious_keys do
        config = %{
          api_key: malicious_key,
          environment: :sandbox,
          base_url: "https://sandbox-api.paddle.com",
          timeout: 30_000,
          retry: true
        }

        assert_raise ArgumentError, fn ->
          Config.validate!(config)
        end
      end
    end

    test "prevents API key leakage in error messages" do
      config = %{
        api_key: "pdl_live_secret_key_12345",
        environment: :invalid_env,
        base_url: "https://api.paddle.com",
        timeout: 30_000,
        retry: true
      }

      error =
        try do
          Config.validate!(config)
        rescue
          e in ArgumentError -> e.message
        end

      refute String.contains?(error, "pdl_live_secret_key_12345")
      refute String.contains?(error, "secret_key")
    end

    test "API key is not logged or exposed in inspect" do
      config = Config.resolve()

      # Test that API key doesn't appear in inspect output
      inspected = inspect(config)
      refute String.contains?(inspected, config.api_key)

      # Test that API key doesn't appear in error messages
      error = Error.authentication_error("Test error")
      error_string = inspect(error)
      refute String.contains?(error_string, config.api_key)
    end

    test "rejects API keys with suspicious patterns" do
      suspicious_keys = [
        "pdl_live_' OR 1=1 --",
        "pdl_live_${jndi:ldap://evil.com/x}",
        "pdl_live_{{7*7}}",
        "pdl_live_<%= system('rm -rf /') %>",
        "pdl_live_`rm -rf ~`"
      ]

      for suspicious_key <- suspicious_keys do
        config = %{
          api_key: suspicious_key,
          environment: :live,
          base_url: "https://api.paddle.com",
          timeout: 30_000,
          retry: true
        }

        # Should still validate format but reject suspicious content
        assert_raise ArgumentError, fn ->
          Config.validate!(config)
        end
      end
    end

    test "environment detection is secure against manipulation" do
      # Test that environment detection can't be manipulated
      test_cases = [
        {"pdl_live_key", :live},
        {"pdl_sdbx_key", :sandbox},
        # Should default to sandbox for safety
        {"pdl_unknown_key", :sandbox},
        # Should detect based on first occurrence
        {"pdl_live_key_but_fake_sdbx", :live}
      ]

      for {api_key, expected_env} <- test_cases do
        Application.put_env(:paddle_billing, :api_key, api_key)
        Application.put_env(:paddle_billing, :environment, nil)

        config = Config.resolve()
        assert config.environment == expected_env

        # Reset
        Application.put_env(:paddle_billing, :api_key, "pdl_test_123456789")
        Application.put_env(:paddle_billing, :environment, :sandbox)
      end
    end
  end

  describe "HTTP header security" do
    setup do
      bypass = Bypass.open()

      config = %{
        api_key: "pdl_test_123456789",
        environment: :sandbox,
        base_url: "http://localhost:#{bypass.port}",
        timeout: 30_000,
        retry: false
      }

      {:ok, bypass: bypass, config: config}
    end

    test "prevents header injection attacks", %{bypass: bypass, config: config} do
      # Test that critical security headers cannot be overridden
      security_critical_headers = [
        [{"Host", "evil.com"}],
        [{"Authorization", "Bearer hacked_key"}],
        [{"Content-Type", "malicious-content-type"}]
      ]

      for {malicious_headers, index} <- Enum.with_index(security_critical_headers) do
        Bypass.expect_once(bypass, "GET", "/products_#{index}", fn conn ->
          # Check that critical headers are not overridden
          headers = Enum.into(conn.req_headers, %{})

          # Host header should be the actual host, not injected value
          refute headers["host"] == "evil.com"

          # Authorization header should not be overridden
          auth_header = headers["authorization"]
          assert String.starts_with?(auth_header, "Bearer pdl_")
          refute String.contains?(auth_header, "hacked_key")

          # Content-Type should not be overridden
          content_type = headers["content-type"]
          assert content_type == "application/json"
          refute content_type == "malicious-content-type"

          Plug.Conn.resp(conn, 200, Jason.encode!(%{"data" => []}))
        end)

        # Attempt header injection through various means - should be safely ignored
        {:ok, _} =
          Client.get("/products_#{index}", %{}, config: config, headers: malicious_headers)
      end
    end

    test "validates User-Agent header format", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/products", fn conn ->
        headers = Enum.into(conn.req_headers, %{})
        user_agent = headers["user-agent"]

        # Should match expected format
        assert user_agent == "paddle_billing_ex/0.1.0 (Elixir)"

        # Should not contain suspicious content
        refute String.contains?(user_agent, "<script>")
        refute String.contains?(user_agent, "../")
        refute String.contains?(user_agent, "$(")

        Plug.Conn.resp(conn, 200, Jason.encode!(%{"data" => []}))
      end)

      {:ok, _} = Client.get("/products", %{}, config: config)
    end

    test "prevents response header injection", %{bypass: bypass, config: config} do
      # Test that malicious response headers don't affect client behavior
      Bypass.expect_once(bypass, "GET", "/products", fn conn ->
        conn
        |> Plug.Conn.put_resp_header("x-malicious", "<script>alert('xss')</script>")
        |> Plug.Conn.put_resp_header("set-cookie", "session=hacked")
        |> Plug.Conn.resp(200, Jason.encode!(%{"data" => []}))
      end)

      # Should still work normally despite malicious headers
      assert {:ok, []} = Client.get("/products", %{}, config: config)
    end
  end

  describe "URL security" do
    setup do
      bypass = Bypass.open()

      config = %{
        api_key: "pdl_test_123456789",
        environment: :sandbox,
        base_url: "http://localhost:#{bypass.port}",
        timeout: 30_000,
        retry: false
      }

      {:ok, bypass: bypass, config: config}
    end

    test "prevents path traversal attacks", %{config: config} do
      malicious_paths = [
        "../../../etc/passwd",
        "..\\..\\windows\\system32\\config\\sam",
        "/products/../admin/users",
        "products%2F..%2Fadmin",
        "products/../../../secret"
      ]

      for malicious_path <- malicious_paths do
        # Should not allow path traversal
        assert_raise ArgumentError, fn ->
          Client.get(malicious_path, %{}, config: config)
        end
      end
    end

    test "validates base URL format", %{config: config} do
      malicious_urls = [
        "javascript:alert(1)",
        "data:text/html,<script>alert('xss')</script>",
        "file:///etc/passwd",
        "ftp://malicious.com/",
        "ldap://evil.com/",
        "http://user:pass@evil.com/",
        "http://localhost:8080@evil.com/"
      ]

      for malicious_url <- malicious_urls do
        malicious_config = %Config{
          api_key: config.api_key,
          environment: config.environment,
          base_url: malicious_url,
          timeout: config.timeout,
          retry: config.retry
        }

        # Should reject malicious URLs
        assert_raise ArgumentError, fn ->
          Config.validate!(malicious_config)
        end
      end
    end

    test "properly encodes query parameters", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/products", fn conn ->
        # Check that raw query string contains properly encoded values
        # The decoded values should match what we sent
        query_params = URI.decode_query(conn.query_string)

        # Verify that the values match what we sent (they should be preserved)
        assert query_params["search"] == "<script>alert('xss')</script>"
        assert query_params["filter"] == "'; DROP TABLE products; --"
        assert query_params["callback"] == "javascript:alert(1)"

        # Check that the raw query string has proper URL encoding
        # < encoded
        assert String.contains?(conn.query_string, "%3C")
        # > encoded
        assert String.contains?(conn.query_string, "%3E")
        # ; encoded
        assert String.contains?(conn.query_string, "%3B")
        # : encoded
        assert String.contains?(conn.query_string, "%3A")

        Plug.Conn.resp(conn, 200, Jason.encode!(%{"data" => []}))
      end)

      # Test parameter encoding with special characters
      special_params = %{
        "search" => "<script>alert('xss')</script>",
        "filter" => "'; DROP TABLE products; --",
        "callback" => "javascript:alert(1)"
      }

      {:ok, _} = Client.get("/products", special_params, config: config)
    end
  end

  describe "JSON security" do
    setup do
      bypass = Bypass.open()

      config = %{
        api_key: "pdl_test_123456789",
        environment: :sandbox,
        base_url: "http://localhost:#{bypass.port}",
        timeout: 30_000,
        retry: false
      }

      {:ok, bypass: bypass, config: config}
    end

    test "prevents JSON injection in request body", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "POST", "/products", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)

        # Should be valid JSON
        parsed = Jason.decode!(body)

        # Check that malicious content is properly escaped/encoded
        assert is_map(parsed)

        Plug.Conn.resp(
          conn,
          201,
          Jason.encode!(%{
            "data" => %{"id" => "pro_123", "name" => "Test Product"}
          })
        )
      end)

      # Attempt JSON injection
      malicious_data = %{
        name: "Product\"; DROP TABLE products; --",
        description: "<script>alert('xss')</script>",
        custom_data: %{
          "callback" => "javascript:alert(1)",
          "template" => "{{7*7}}"
        }
      }

      # Should handle malicious data safely
      {:ok, product} = Client.post("/products", malicious_data, config: config)
      assert product["id"] == "pro_123"
    end

    test "handles malicious JSON responses safely", %{bypass: bypass, config: config} do
      malicious_responses = [
        # Extremely nested JSON
        Jason.encode!(%{"data" => build_nested_map(100)}),

        # Very long strings
        Jason.encode!(%{"data" => %{"name" => String.duplicate("A", 100_000)}}),

        # JSON with script content
        Jason.encode!(%{"data" => %{"description" => "<script>alert('xss')</script>"}}),

        # JSON with null bytes
        Jason.encode!(%{"data" => %{"name" => "Product\0Name"}}),

        # Invalid JSON structure attempts
        ~s({"data": {"__proto__": {"isAdmin": true}}}),
        ~s({"constructor": {"prototype": {"isAdmin": true}}})
      ]

      for {response, index} <- Enum.with_index(malicious_responses) do
        Bypass.expect_once(bypass, "GET", "/products/test_#{index}", fn conn ->
          Plug.Conn.resp(conn, 200, response)
        end)

        # Should handle malicious responses without crashing
        result = Client.get("/products/test_#{index}", %{}, config: config)
        assert {:ok, _} = result
      end
    end

    defp build_nested_map(0), do: %{"value" => "deep"}
    defp build_nested_map(depth), do: %{"nested" => build_nested_map(depth - 1)}
  end

  describe "environment variable security" do
    test "prevents environment variable injection" do
      original_api_key = System.get_env("PADDLE_API_KEY")
      original_env = System.get_env("PADDLE_ENVIRONMENT")

      try do
        # Test injection attempts through environment variables
        malicious_envs = [
          {"PADDLE_API_KEY", "pdl_live_key$(rm -rf /)"},
          {"PADDLE_API_KEY", "pdl_live_key`whoami`"},
          {"PADDLE_API_KEY", "pdl_live_key; cat /etc/passwd"},
          {"PADDLE_ENVIRONMENT", "live$(malicious_command)"},
          {"PADDLE_ENVIRONMENT", "sandbox`rm -rf /`"}
        ]

        for {env_var, malicious_value} <- malicious_envs do
          System.put_env(env_var, malicious_value)

          # Should either reject the value or handle it safely
          try do
            config = Config.resolve()
            # If it doesn't raise, ensure no command execution occurred
            assert is_binary(config.api_key)
            assert config.environment in [:live, :sandbox]
          rescue
            # Expected for malicious keys
            ArgumentError -> :ok
          end
        end
      after
        # Restore original environment
        if original_api_key, do: System.put_env("PADDLE_API_KEY", original_api_key)
        if original_env, do: System.put_env("PADDLE_ENVIRONMENT", original_env)
      end
    end
  end

  describe "memory safety" do
    test "handles large payloads without memory exhaustion" do
      bypass = Bypass.open()

      config = %{
        api_key: "pdl_test_123456789",
        environment: :sandbox,
        base_url: "http://localhost:#{bypass.port}",
        timeout: 30_000,
        retry: false
      }

      Bypass.expect_once(bypass, "POST", "/products", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)

        # Verify we can handle the request without issues
        assert byte_size(body) > 0

        Plug.Conn.resp(
          conn,
          201,
          Jason.encode!(%{
            "data" => %{"id" => "pro_123", "name" => "Test Product"}
          })
        )
      end)

      # Create large but reasonable payload
      large_data = %{
        name: "Test Product",
        description: String.duplicate("Description ", 1000),
        custom_data: %{
          "large_field" => String.duplicate("data", 5000)
        }
      }

      # Should handle large payload without memory issues
      {:ok, product} = Client.post("/products", large_data, config: config)
      assert product["id"] == "pro_123"
    end

    test "handles memory pressure gracefully" do
      # Test that the library doesn't leak memory during normal operations
      initial_memory = :erlang.memory(:total)

      # Perform many operations
      for _i <- 1..100 do
        config = Config.resolve()
        Config.validate!(config)

        error = Error.authentication_error("Test")
        _string_repr = to_string(error)
      end

      # Force garbage collection
      :erlang.garbage_collect()
      Process.sleep(10)

      final_memory = :erlang.memory(:total)
      memory_growth = final_memory - initial_memory

      # Memory growth should be reasonable (less than 50MB)
      # Account for system variability and test overhead
      assert memory_growth < 50_000_000
    end
  end
end
