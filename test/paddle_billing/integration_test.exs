defmodule PaddleBilling.IntegrationTest do
  use ExUnit.Case, async: true
  import PaddleBilling.TestHelpers

  alias PaddleBilling.{Product, Error}

  describe "end-to-end product management" do
    setup do
      bypass = Bypass.open()
      config = create_bypass_config(bypass)
      {:ok, bypass: bypass, config: config}
    end

    test "complete product lifecycle", %{bypass: bypass, config: config} do
      product_data = generate_test_product_data(name: "Lifecycle Product")

      # Step 1: Create product
      setup_successful_response(bypass, "POST", "/products", %{
        "id" => "pro_lifecycle",
        "name" => "Lifecycle Product",
        "status" => "active"
      })

      assert {:ok, created_product} = Product.create(product_data, config: config)
      assert created_product.id == "pro_lifecycle"
      assert created_product.name == "Lifecycle Product"

      # Step 2: Get the created product
      setup_successful_response(bypass, "GET", "/products/pro_lifecycle", %{
        "id" => "pro_lifecycle",
        "name" => "Lifecycle Product",
        "description" => "A test product for unit testing",
        "status" => "active"
      })

      assert {:ok, fetched_product} = Product.get("pro_lifecycle", %{}, config: config)
      assert fetched_product.id == created_product.id
      assert fetched_product.name == created_product.name

      # Step 3: Update the product
      setup_successful_response(bypass, "PATCH", "/products/pro_lifecycle", %{
        "id" => "pro_lifecycle",
        "name" => "Updated Lifecycle Product",
        "description" => "Updated description",
        "status" => "active"
      })

      update_params = %{name: "Updated Lifecycle Product", description: "Updated description"}

      assert {:ok, updated_product} =
               Product.update("pro_lifecycle", update_params, config: config)

      assert updated_product.name == "Updated Lifecycle Product"
      assert updated_product.description == "Updated description"

      # Step 4: Archive the product
      setup_successful_response(bypass, "PATCH", "/products/pro_lifecycle", %{
        "id" => "pro_lifecycle",
        "name" => "Updated Lifecycle Product",
        "status" => "archived"
      })

      assert {:ok, archived_product} = Product.archive("pro_lifecycle", config: config)
      assert archived_product.status == "archived"
    end

    test "bulk operations with error handling", %{bypass: bypass, config: config} do
      # Set up multiple product creation scenarios
      products_to_create = [
        generate_test_product_data(name: "Bulk Product 1"),
        generate_test_product_data(name: "Bulk Product 2"),
        # This will fail
        generate_test_product_data(name: "Invalid Product")
      ]

      # Set up expectations for bulk operations - match by product name
      Bypass.expect(bypass, "POST", "/products", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        parsed = Jason.decode!(body)

        case parsed["name"] do
          "Bulk Product 1" ->
            response = %{"data" => %{"id" => "pro_bulk_1", "name" => "Bulk Product 1"}}
            Plug.Conn.resp(conn, 200, Jason.encode!(response))

          "Bulk Product 2" ->
            response = %{"data" => %{"id" => "pro_bulk_2", "name" => "Bulk Product 2"}}
            Plug.Conn.resp(conn, 200, Jason.encode!(response))

          "Invalid Product" ->
            error_response = %{
              "errors" => [
                %{
                  "field" => "name",
                  "code" => "invalid",
                  "detail" => "Product name contains invalid characters"
                }
              ]
            }

            Plug.Conn.resp(conn, 400, Jason.encode!(error_response))

          _ ->
            # Should not reach here with the test data
            error_response = %{
              "errors" => [
                %{
                  "field" => "name",
                  "code" => "unknown_product",
                  "detail" => "Unexpected product name: #{parsed["name"]}"
                }
              ]
            }

            Plug.Conn.resp(conn, 400, Jason.encode!(error_response))
        end
      end)

      # Process all products sequentially to ensure predictable order
      results =
        for product_data <- products_to_create do
          Product.create(product_data, config: config)
        end

      # Verify results
      assert {:ok, product1} = Enum.at(results, 0)
      assert {:ok, product2} = Enum.at(results, 1)
      assert {:error, %Error{type: :validation_error}} = Enum.at(results, 2)

      assert product1.id == "pro_bulk_1"
      assert product2.id == "pro_bulk_2"
    end

    test "concurrent operations safety", %{bypass: bypass, config: config} do
      # Set up expectations for concurrent requests
      # Use Bypass.expect (not expect_once) to handle multiple calls to the same endpoint
      Bypass.expect(bypass, "POST", "/products", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        parsed = Jason.decode!(body)
        product_name = parsed["name"]

        # Extract the number from the product name to generate consistent IDs
        product_number =
          case Regex.run(~r/Concurrent Product (\d+)/, product_name) do
            [_, num] -> num
            _ -> "unknown"
          end

        response = %{
          "data" => %{
            "id" => "pro_concurrent_#{product_number}",
            "name" => product_name,
            "status" => "active"
          }
        }

        Plug.Conn.resp(conn, 200, Jason.encode!(response))
      end)

      # Create products concurrently
      tasks =
        for i <- 1..5 do
          Task.async(fn ->
            product_data = generate_test_product_data(name: "Concurrent Product #{i}")
            Product.create(product_data, config: config)
          end)
        end

      results = Task.await_many(tasks, 10_000)

      # All should succeed
      assert length(results) == 5

      # Sort results by ID to ensure consistent testing
      sorted_results =
        results
        |> Enum.map(fn {:ok, product} -> product end)
        |> Enum.sort_by(& &1.id)

      for {product, index} <- Enum.with_index(sorted_results, 1) do
        assert product.id == "pro_concurrent_#{index}"
        assert product.name == "Concurrent Product #{index}"
      end
    end
  end

  describe "error scenarios and recovery" do
    setup do
      bypass = Bypass.open()
      config = create_bypass_config(bypass)
      {:ok, bypass: bypass, config: config}
    end

    test "handles network interruption gracefully", %{config: config} do
      # Use an unreachable host to simulate network error
      network_error_config = %{config | base_url: "http://localhost:1", timeout: 1000}

      assert {:error, %Error{type: error_type}} = Product.list(%{}, config: network_error_config)
      assert error_type in [:network_error, :timeout_error]
    end

    test "handles server errors with proper error types", %{bypass: bypass, config: config} do
      error_scenarios = [
        {400, %{"errors" => [%{"field" => "name", "detail" => "Required"}]}, :validation_error},
        {401, %{"error" => %{"code" => "unauthorized"}}, :authentication_error},
        {403, %{"error" => %{"code" => "forbidden"}}, :authorization_error},
        {429, %{"error" => %{"code" => "rate_limit_exceeded"}}, :rate_limit_error},
        {500, %{"error" => %{"code" => "internal_error"}}, :server_error}
      ]

      for {{status, error_body, expected_type}, index} <- Enum.with_index(error_scenarios) do
        setup_error_response(bypass, "GET", "/products/error_#{index}", status, error_body)

        assert {:error, %Error{type: ^expected_type}} =
                 Product.get("error_#{index}", %{}, config: config)
      end
    end

    test "validates configuration before making requests", %{config: config} do
      # Test with invalid API key
      invalid_config = %{config | api_key: "invalid_format"}

      assert_raise ArgumentError, ~r/Invalid API key format/, fn ->
        Product.list(%{}, config: invalid_config)
      end

      # Test with invalid environment
      invalid_env_config = %{config | environment: :invalid}

      assert_raise ArgumentError, ~r/Invalid environment/, fn ->
        Product.list(%{}, config: invalid_env_config)
      end
    end
  end

  describe "performance and resource management" do
    setup do
      bypass = Bypass.open()
      config = create_bypass_config(bypass)
      {:ok, bypass: bypass, config: config}
    end

    test "handles large response efficiently", %{bypass: bypass, config: config} do
      # Create large response with many products
      large_products =
        for i <- 1..1000 do
          %{
            "id" => "pro_large_#{i}",
            "name" => "Large Response Product #{i}",
            # 1KB description each
            "description" => create_large_string(1)
          }
        end

      Bypass.expect_once(bypass, "GET", "/products", fn conn ->
        response = %{"data" => large_products}
        Plug.Conn.resp(conn, 200, Jason.encode!(response))
      end)

      initial_memory = :erlang.memory(:total)

      {result, execution_time} =
        measure_execution_time(fn ->
          Product.list(%{}, config: config)
        end)

      # Should succeed
      assert {:ok, products} = result
      assert length(products) == 1000

      # Should complete in reasonable time (less than 5 seconds)
      # 5 seconds in microseconds
      assert execution_time < 5_000_000

      # Memory usage should be reasonable
      # Max 100MB growth
      assert_memory_within_bounds(initial_memory, 100)
    end

    @tag timeout: 5000
    test "handles timeout scenarios appropriately", %{bypass: _bypass, config: config} do
      # Use a non-existent port to force connection timeout
      timeout_config = %PaddleBilling.Config{
        config
        | timeout: 100,
          # Port 0 should not be accessible
          base_url: "http://localhost:0"
      }

      {result, execution_time} =
        measure_execution_time(fn ->
          Product.get("test", %{}, config: timeout_config)
        end)

      # Should timeout or get network error
      assert {:error, %Error{}} = result

      # Should not wait much longer than timeout (allow reasonable buffer for test environment)
      # 200ms in microseconds (100ms timeout + 100% buffer for CI environments)
      assert execution_time < 200_000
    end

    test "manages memory efficiently during repeated operations", %{
      bypass: bypass,
      config: config
    } do
      # Set up many small successful responses
      for i <- 1..100 do
        setup_successful_response(bypass, "GET", "/products/memory_#{i}", %{
          "id" => "pro_memory_#{i}",
          "name" => "Memory Test Product #{i}"
        })
      end

      initial_memory = :erlang.memory(:total)

      # Perform many operations
      results =
        for i <- 1..100 do
          Product.get("memory_#{i}", %{}, config: config)
        end

      # All should succeed
      assert length(results) == 100

      for {result, index} <- Enum.with_index(results, 1) do
        assert {:ok, product} = result
        assert product.id == "pro_memory_#{index}"
      end

      # Force garbage collection to get accurate memory measurement
      :erlang.garbage_collect()
      # Allow GC to complete
      Process.sleep(10)

      # Memory growth should be minimal
      # Increase limit to account for system variability and test overhead
      assert_memory_within_bounds(initial_memory, 50)
    end
  end

  describe "real-world usage patterns" do
    setup do
      bypass = Bypass.open()
      config = create_bypass_config(bypass)
      {:ok, bypass: bypass, config: config}
    end

    test "pagination and filtering workflow", %{bypass: bypass, config: config} do
      # First page
      page1_products = for i <- 1..10, do: %{"id" => "pro_page1_#{i}", "name" => "Product #{i}"}

      Bypass.expect_once(bypass, "GET", "/products", fn conn ->
        query_params = URI.decode_query(conn.query_string)
        assert query_params["per_page"] == "10"
        assert query_params["status"] == "active"

        Plug.Conn.resp(conn, 200, Jason.encode!(%{"data" => page1_products}))
      end)

      assert {:ok, page1} = Product.list(%{per_page: 10, status: ["active"]}, config: config)
      assert length(page1) == 10
      assert hd(page1).id == "pro_page1_1"

      # Second page
      page2_products = for i <- 11..15, do: %{"id" => "pro_page2_#{i}", "name" => "Product #{i}"}

      Bypass.expect_once(bypass, "GET", "/products", fn conn ->
        query_params = URI.decode_query(conn.query_string)
        assert query_params["after"] == "pro_page1_10"

        Plug.Conn.resp(conn, 200, Jason.encode!(%{"data" => page2_products}))
      end)

      assert {:ok, page2} = Product.list(%{after: "pro_page1_10", per_page: 10}, config: config)
      assert length(page2) == 5
      assert hd(page2).id == "pro_page2_11"
    end

    test "search and filter combination", %{bypass: bypass, config: config} do
      # Complex filtering scenario
      filtered_products = [
        %{"id" => "pro_premium_1", "name" => "Premium Product 1", "type" => "standard"},
        %{"id" => "pro_premium_2", "name" => "Premium Product 2", "type" => "standard"}
      ]

      Bypass.expect_once(bypass, "GET", "/products", fn conn ->
        query_params = URI.decode_query(conn.query_string)

        # Verify complex query parameters
        assert query_params["status"] == "active"
        assert query_params["type"] == "standard"
        assert query_params["include"] == "prices"

        Plug.Conn.resp(conn, 200, Jason.encode!(%{"data" => filtered_products}))
      end)

      filter_params = %{
        status: ["active"],
        type: ["standard"],
        include: ["prices"]
      }

      assert {:ok, products} = Product.list(filter_params, config: config)
      assert length(products) == 2
      assert Enum.all?(products, &(&1.type == "standard"))
    end

    test "product update workflow with validation", %{bypass: bypass, config: config} do
      # Get current product
      setup_successful_response(bypass, "GET", "/products/pro_update", %{
        "id" => "pro_update",
        "name" => "Original Product",
        "description" => "Original description"
      })

      assert {:ok, original} = Product.get("pro_update", %{}, config: config)
      assert original.name == "Original Product"

      # Attempt invalid update (should fail)
      setup_error_response(bypass, "PATCH", "/products/pro_update", 400, %{
        "errors" => [
          %{
            "field" => "name",
            "code" => "too_long",
            "detail" => "Name cannot exceed 255 characters"
          }
        ]
      })

      long_name = String.duplicate("A", 300)

      assert {:error, %Error{type: :validation_error}} =
               Product.update("pro_update", %{name: long_name}, config: config)

      # Valid update (should succeed)
      setup_successful_response(bypass, "PATCH", "/products/pro_update", %{
        "id" => "pro_update",
        "name" => "Updated Product",
        "description" => "Updated description"
      })

      valid_updates = %{
        name: "Updated Product",
        description: "Updated description"
      }

      assert {:ok, updated} = Product.update("pro_update", valid_updates, config: config)
      assert updated.name == "Updated Product"
      assert updated.description == "Updated description"
    end
  end

  describe "edge cases and boundary conditions" do
    setup do
      bypass = Bypass.open()
      config = create_bypass_config(bypass)
      {:ok, bypass: bypass, config: config}
    end

    test "handles empty and minimal responses", %{bypass: bypass, config: config} do
      # Empty list response
      Bypass.expect_once(bypass, "GET", "/products", fn conn ->
        Plug.Conn.resp(conn, 200, Jason.encode!(%{"data" => []}))
      end)

      assert {:ok, []} = Product.list(%{}, config: config)

      # Minimal product response
      setup_successful_response(bypass, "GET", "/products/minimal", %{
        "id" => "pro_minimal",
        # Single character name
        "name" => "M"
      })

      assert {:ok, minimal} = Product.get("minimal", %{}, config: config)
      assert minimal.id == "pro_minimal"
      assert minimal.name == "M"
    end

    test "handles unicode and special characters in all fields", %{bypass: bypass, config: config} do
      unicode_product = %{
        name: "🚀 Product 测试",
        description: "Description with special chars and spëcial chars: àáâãäå",
        custom_data: %{
          "unicode_field" => "Field with 中文字符 and symbols: ∀∃∇∈",
          "emoji_field" => "🌟⭐✨💫🔥"
        }
      }

      Bypass.expect_once(bypass, "POST", "/products", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        parsed = Jason.decode!(body)

        # Verify unicode is preserved
        assert String.contains?(parsed["name"], "🚀")
        assert String.contains?(parsed["name"], "测试")
        assert String.contains?(parsed["custom_data"]["emoji_field"], "🌟")

        Plug.Conn.resp(
          conn,
          201,
          Jason.encode!(%{
            "data" => %{
              "id" => "pro_unicode",
              "name" => parsed["name"],
              "description" => parsed["description"]
            }
          })
        )
      end)

      assert {:ok, product} = Product.create(unicode_product, config: config)
      assert product.id == "pro_unicode"
      assert String.contains?(product.name, "🚀")
    end

    test "handles maximum payload sizes", %{bypass: bypass, config: config} do
      # Create a large product payload (but reasonable)
      # 100KB description
      large_description = create_large_string(100)

      large_custom_data = %{
        "large_field" => create_large_string(50),
        "array_field" => Enum.to_list(1..1000),
        "nested_field" => create_nested_map(10)
      }

      large_product = %{
        name: "Large Product",
        description: large_description,
        custom_data: large_custom_data
      }

      Bypass.expect_once(bypass, "POST", "/products", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        parsed = Jason.decode!(body)

        # Verify large data is handled
        assert String.length(parsed["description"]) > 100_000
        assert length(parsed["custom_data"]["array_field"]) == 1000

        Plug.Conn.resp(
          conn,
          201,
          Jason.encode!(%{
            "data" => %{
              "id" => "pro_large",
              "name" => "Large Product"
            }
          })
        )
      end)

      initial_memory = :erlang.memory(:total)

      assert {:ok, product} = Product.create(large_product, config: config)
      assert product.id == "pro_large"

      # Memory usage should be reasonable even with large payloads
      # Max 50MB growth
      assert_memory_within_bounds(initial_memory, 50)
    end
  end
end
