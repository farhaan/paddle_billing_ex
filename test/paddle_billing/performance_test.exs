defmodule PaddleBilling.PerformanceTest do
  use ExUnit.Case, async: true

  alias PaddleBilling.{Client, Product, Config, Error}

  describe "timeout handling" do
    setup do
      bypass = Bypass.open()

      config = %{
        api_key: "pdl_test_123456789",
        environment: :sandbox,
        base_url: "http://localhost:#{bypass.port}",
        # Short timeout for testing
        timeout: 1000,
        retry: false
      }

      {:ok, bypass: bypass, config: config}
    end

    @tag timeout: 10_000
    test "respects configured timeout", %{config: _config} do
      # Use an unreachable address to test timeout behavior
      timeout_config = %{
        api_key: "pdl_test_123456789",
        environment: :sandbox,
        # RFC 5737 reserved address
        base_url: "http://192.0.2.1:1234",
        timeout: 1000,
        retry: false
      }

      start_time = System.monotonic_time(:millisecond)

      assert {:error, %Error{type: error_type}} = Client.get("/slow", %{}, config: timeout_config)

      end_time = System.monotonic_time(:millisecond)
      elapsed = end_time - start_time

      # Should timeout and error type should be timeout or network error
      assert error_type in [:timeout_error, :network_error]

      # Should respect the timeout period (1000ms) with some buffer
      assert elapsed >= 900
      assert elapsed < 2000
    end

    @tag timeout: 5_000
    test "handles very short timeouts", %{config: _config} do
      # 50ms timeout (more realistic but still very short)
      very_short_config = %{
        api_key: "pdl_test_123456789",
        environment: :sandbox,
        # RFC 5737 reserved address
        base_url: "http://192.0.2.1:1234",
        timeout: 50,
        retry: false
      }

      start_time = System.monotonic_time(:millisecond)
      assert {:error, %Error{}} = Client.get("/test", %{}, config: very_short_config)
      end_time = System.monotonic_time(:millisecond)
      elapsed = end_time - start_time

      # Should timeout quickly, allow some buffer for network stack
      assert elapsed < 500
    end

    @tag timeout: 5_000
    test "handles timeout during request body processing", %{config: _config} do
      short_config = %{
        api_key: "pdl_test_123456789",
        environment: :sandbox,
        # RFC 5737 reserved address
        base_url: "http://192.0.2.1:1234",
        timeout: 100,
        retry: false
      }

      large_body = %{
        name: "Large Product",
        description: String.duplicate("Large description ", 1000)
      }

      start_time = System.monotonic_time(:millisecond)

      assert {:error, %Error{}} =
               Client.post("/slow-processing", large_body, config: short_config)

      end_time = System.monotonic_time(:millisecond)
      elapsed = end_time - start_time

      # Should timeout within reasonable time
      assert elapsed < 500
    end

    test "allows custom timeout override", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/custom-timeout", fn conn ->
        # Delay longer than default config timeout but less than custom
        Process.sleep(1200)
        Plug.Conn.resp(conn, 200, Jason.encode!(%{"data" => "custom timeout worked"}))
      end)

      # Override with longer timeout
      custom_opts = [timeout: 2000]

      assert {:ok, "custom timeout worked"} =
               Client.get("/custom-timeout", %{}, [config: config] ++ custom_opts)
    end
  end

  describe "concurrent request handling" do
    setup do
      bypass = Bypass.open()

      config = %{
        api_key: "pdl_test_123456789",
        environment: :sandbox,
        base_url: "http://localhost:#{bypass.port}",
        timeout: 5000,
        retry: false
      }

      {:ok, bypass: bypass, config: config}
    end

    test "handles multiple concurrent requests", %{bypass: bypass, config: config} do
      # Set up expectations for multiple requests
      for i <- 1..10 do
        Bypass.expect_once(bypass, "GET", "/concurrent/#{i}", fn conn ->
          # Small random delay to simulate network variance
          Process.sleep(:rand.uniform(50))
          Plug.Conn.resp(conn, 200, Jason.encode!(%{"data" => %{"id" => i}}))
        end)
      end

      # Start concurrent requests
      tasks =
        for i <- 1..10 do
          Task.async(fn ->
            Client.get("/concurrent/#{i}", %{}, config: config)
          end)
        end

      # Wait for all requests to complete
      results = Task.await_many(tasks, 10_000)

      # All requests should succeed
      assert length(results) == 10

      for {result, index} <- Enum.with_index(results, 1) do
        assert {:ok, %{"id" => ^index}} = result
      end
    end

    test "handles concurrent requests with shared resources", %{bypass: bypass, config: config} do
      # Test that concurrent requests don't interfere with each other
      request_count = 20

      # Use a shared counter to track requests
      counter_pid = spawn(fn -> counter_process(0) end)

      # Use Bypass.expect (not expect_once) to handle multiple requests
      Bypass.expect(bypass, "POST", "/products", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        send(counter_pid, :increment)
        # Small delay
        Process.sleep(10)

        # Parse the body to get a unique ID based on the request
        parsed = Jason.decode!(body)
        # Create response with the product structure expected by Product module
        response_data = %{
          "id" => "shared",
          "name" => parsed["name"],
          "description" => parsed["description"] || "",
          "type" => "standard",
          "tax_category" => "standard",
          "image_url" => nil,
          "custom_data" => %{},
          "status" => "active",
          "created_at" => "2024-01-01T00:00:00.000Z",
          "updated_at" => "2024-01-01T00:00:00.000Z"
        }

        Plug.Conn.resp(conn, 201, Jason.encode!(%{"data" => response_data}))
      end)

      # Make concurrent requests
      tasks =
        for i <- 1..request_count do
          Task.async(fn ->
            Product.create(%{name: "Concurrent #{i}"}, config: config)
          end)
        end

      results = Task.await_many(tasks, 15_000)

      # Verify all requests completed
      assert length(results) == request_count

      for result <- results do
        assert {:ok, %Product{id: "shared"}} = result
      end

      # Check that all requests were processed
      send(counter_pid, {:get_count, self()})
      assert_receive {:count, ^request_count}, 1000
    end

    defp counter_process(count) do
      receive do
        :increment ->
          counter_process(count + 1)

        {:get_count, from} ->
          send(from, {:count, count})
          counter_process(count)
      end
    end
  end

  describe "memory and resource usage" do
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

    test "handles large response payloads efficiently", %{bypass: bypass, config: config} do
      # Create a large response payload
      large_products =
        for i <- 1..1000 do
          %{
            "id" => "pro_#{i}",
            "name" => "Product #{i}",
            "description" => String.duplicate("Description for product #{i} ", 50),
            "custom_data" => %{
              "field_1" => String.duplicate("data", 100),
              "field_2" => Enum.to_list(1..100)
            }
          }
        end

      large_response = %{"data" => large_products}

      Bypass.expect_once(bypass, "GET", "/large-response", fn conn ->
        response_json = Jason.encode!(large_response)
        Plug.Conn.resp(conn, 200, response_json)
      end)

      # Measure memory before request
      initial_memory = :erlang.memory(:total)

      assert {:ok, products} = Client.get("/large-response", %{}, config: config)

      # Verify we got the data
      assert length(products) == 1000
      assert hd(products)["id"] == "pro_1"

      # Force garbage collection
      :erlang.garbage_collect()
      Process.sleep(100)

      # Measure memory after cleanup
      final_memory = :erlang.memory(:total)
      memory_growth = final_memory - initial_memory

      # Memory growth should be reasonable (less than 50MB for this test)
      assert memory_growth < 50_000_000
    end

    test "handles many small requests efficiently", %{bypass: bypass, config: config} do
      num_requests = 100

      for i <- 1..num_requests do
        Bypass.expect_once(bypass, "GET", "/small/#{i}", fn conn ->
          Plug.Conn.resp(conn, 200, Jason.encode!(%{"data" => %{"id" => i}}))
        end)
      end

      initial_memory = :erlang.memory(:total)
      start_time = System.monotonic_time(:millisecond)

      # Make many sequential requests
      results =
        for i <- 1..num_requests do
          Client.get("/small/#{i}", %{}, config: config)
        end

      end_time = System.monotonic_time(:millisecond)
      elapsed = end_time - start_time

      # All requests should succeed
      assert length(results) == num_requests

      for {result, index} <- Enum.with_index(results, 1) do
        assert {:ok, %{"id" => ^index}} = result
      end

      # Should complete in reasonable time (less than 10 seconds)
      assert elapsed < 10_000

      # Clean up and check memory
      :erlang.garbage_collect()
      Process.sleep(100)
      final_memory = :erlang.memory(:total)
      memory_growth = final_memory - initial_memory

      # Memory growth should be minimal
      assert memory_growth < 10_000_000
    end

    test "handles streaming-like response processing", %{bypass: bypass, config: config} do
      # Test processing of responses that come in chunks
      chunks = [
        "{\"data\": [",
        "{\"id\": \"1\", \"name\": \"First\"},",
        "{\"id\": \"2\", \"name\": \"Second\"},",
        "{\"id\": \"3\", \"name\": \"Third\"}",
        "]}"
      ]

      Bypass.expect_once(bypass, "GET", "/chunked", fn conn ->
        # Send response in chunks with delays
        conn = Plug.Conn.send_chunked(conn, 200)

        Enum.reduce(chunks, conn, fn chunk, acc ->
          # Small delay between chunks
          Process.sleep(10)
          {:ok, acc} = Plug.Conn.chunk(acc, chunk)
          acc
        end)
      end)

      # Should handle chunked response correctly
      assert {:ok, products} = Client.get("/chunked", %{}, config: config)
      assert length(products) == 3
      assert hd(products)["id"] == "1"
    end
  end

  describe "rate limiting and backoff" do
    setup do
      bypass = Bypass.open()

      config = %{
        api_key: "pdl_test_123456789",
        environment: :sandbox,
        base_url: "http://localhost:#{bypass.port}",
        timeout: 5000,
        # Disable automatic retries for these tests
        retry: false
      }

      {:ok, bypass: bypass, config: config}
    end

    test "handles rate limit responses appropriately", %{bypass: bypass, config: config} do
      # Track request count to simulate rate limiting
      Agent.start_link(fn -> 0 end, name: :rate_limit_counter)

      # Use Bypass.expect to handle multiple requests to the same endpoint
      Bypass.expect(bypass, "GET", "/rate-limited", fn conn ->
        count = Agent.get_and_update(:rate_limit_counter, fn c -> {c, c + 1} end)

        if count == 0 do
          # First request succeeds
          Plug.Conn.resp(conn, 200, Jason.encode!(%{"data" => "success"}))
        else
          # Subsequent requests get rate limited
          conn
          |> Plug.Conn.put_resp_header("retry-after", "60")
          |> Plug.Conn.resp(
            429,
            Jason.encode!(%{
              "error" => %{
                "code" => "rate_limit_exceeded",
                "detail" => "Too many requests"
              }
            })
          )
        end
      end)

      # First request should succeed
      assert {:ok, "success"} = Client.get("/rate-limited", %{}, config: config)

      # Second request should return rate limit error
      assert {:error, %Error{type: :rate_limit_error}} =
               Client.get("/rate-limited", %{}, config: config)

      # Clean up
      Agent.stop(:rate_limit_counter)
    end

    test "handles burst traffic patterns", %{bypass: bypass, config: config} do
      # Set up expectations for burst requests
      num_burst_requests = 10

      # Track request count to simulate burst rate limiting
      Agent.start_link(fn -> 0 end, name: :burst_counter)

      # Use Bypass.expect to handle multiple requests to the same endpoint
      Bypass.expect(bypass, "POST", "/products", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        parsed = Jason.decode!(body)

        count = Agent.get_and_update(:burst_counter, fn c -> {c, c + 1} end)

        if count < 5 do
          # First 5 succeed
          response_data = %{
            "id" => "burst_#{count + 1}",
            "name" => parsed["name"],
            "description" => parsed["description"] || "",
            "type" => "standard",
            "tax_category" => "standard",
            "image_url" => nil,
            "custom_data" => %{},
            "status" => "active",
            "created_at" => "2024-01-01T00:00:00.000Z",
            "updated_at" => "2024-01-01T00:00:00.000Z"
          }

          Plug.Conn.resp(conn, 201, Jason.encode!(%{"data" => response_data}))
        else
          # Rest get rate limited
          Plug.Conn.resp(
            conn,
            429,
            Jason.encode!(%{
              "error" => %{"code" => "rate_limit_exceeded", "detail" => "Rate limited"}
            })
          )
        end
      end)

      # Make burst requests
      results =
        for i <- 1..num_burst_requests do
          Product.create(%{name: "Burst #{i}"}, config: config)
        end

      # Count successes and rate limit errors
      successes =
        Enum.count(results, fn
          {:ok, _} -> true
          _ -> false
        end)

      rate_limits =
        Enum.count(results, fn
          {:error, %Error{type: :rate_limit_error}} -> true
          _ -> false
        end)

      assert successes == 5
      assert rate_limits == 5

      # Clean up
      Agent.stop(:burst_counter)
    end
  end

  describe "configuration performance" do
    test "config resolution is efficient for repeated calls" do
      # Time multiple config resolutions
      start_time = System.monotonic_time(:microsecond)

      configs =
        for _i <- 1..1000 do
          Config.resolve()
        end

      end_time = System.monotonic_time(:microsecond)
      elapsed_microseconds = end_time - start_time

      # All configs should be identical
      unique_configs = Enum.uniq(configs)
      assert length(unique_configs) == 1

      # Should be fast (less than 100ms for 1000 calls)
      assert elapsed_microseconds < 100_000
    end

    test "config validation is efficient" do
      config = Config.resolve()

      start_time = System.monotonic_time(:microsecond)

      # Validate the same config many times
      for _i <- 1..1000 do
        Config.validate!(config)
      end

      end_time = System.monotonic_time(:microsecond)
      elapsed_microseconds = end_time - start_time

      # Should be reasonably fast (less than 60ms for 1000 validations)
      # Allow more time for CI environments and system variability
      assert elapsed_microseconds < 60_000
    end
  end

  describe "JSON processing performance" do
    test "handles large JSON encoding efficiently" do
      # Create a large data structure
      large_data = %{
        name: "Performance Test Product",
        description: String.duplicate("Large description ", 1000),
        custom_data: %{
          "array" => Enum.to_list(1..10_000),
          "nested" => create_nested_data(100),
          "strings" => Enum.map(1..1000, fn i -> "String #{i}" end)
        }
      }

      start_time = System.monotonic_time(:microsecond)

      # Encode to JSON (what happens before HTTP request)
      json_string = Jason.encode!(large_data)

      encode_time = System.monotonic_time(:microsecond)

      # Decode back (what happens after HTTP response)
      decoded_data = Jason.decode!(json_string)

      end_time = System.monotonic_time(:microsecond)

      encode_elapsed = encode_time - start_time
      decode_elapsed = end_time - encode_time

      # Verify data integrity
      assert decoded_data["name"] == large_data.name
      assert length(decoded_data["custom_data"]["array"]) == 10_000

      # Should be reasonably fast (less than 100ms each)
      # 100ms
      assert encode_elapsed < 100_000
      # 100ms
      assert decode_elapsed < 100_000
    end

    defp create_nested_data(0), do: %{"leaf" => "value"}

    defp create_nested_data(depth) do
      %{
        "level" => depth,
        "data" => "Level #{depth} data",
        "nested" => create_nested_data(depth - 1)
      }
    end
  end

  describe "connection pooling and reuse" do
    setup do
      bypass = Bypass.open()

      config = %{
        api_key: "pdl_test_123456789",
        environment: :sandbox,
        base_url: "http://localhost:#{bypass.port}",
        timeout: 5000,
        retry: false
      }

      {:ok, bypass: bypass, config: config}
    end

    test "reuses connections efficiently", %{bypass: bypass, config: config} do
      # Set up multiple endpoints
      for i <- 1..10 do
        Bypass.expect_once(bypass, "GET", "/connection-test/#{i}", fn conn ->
          Plug.Conn.resp(conn, 200, Jason.encode!(%{"data" => %{"id" => i}}))
        end)
      end

      start_time = System.monotonic_time(:millisecond)

      # Make multiple requests sequentially
      results =
        for i <- 1..10 do
          Client.get("/connection-test/#{i}", %{}, config: config)
        end

      end_time = System.monotonic_time(:millisecond)
      elapsed = end_time - start_time

      # All requests should succeed
      assert length(results) == 10

      for {result, index} <- Enum.with_index(results, 1) do
        assert {:ok, %{"id" => ^index}} = result
      end

      # Should complete relatively quickly due to connection reuse
      # This is a loose assertion since timing can vary
      # 5 seconds should be plenty
      assert elapsed < 5000
    end
  end
end
