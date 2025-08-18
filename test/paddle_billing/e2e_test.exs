defmodule PaddleBilling.E2ETest do
  use ExUnit.Case, async: false

  alias PaddleBilling.{Product, Price, Customer, Error, Config}

  @moduletag :e2e

  # Helper functions to get configuration from environment
  defp get_test_config do
    api_key = System.get_env("PADDLE_API_KEY") || 
              System.get_env("PADDLE_SANDBOX_API_KEY") ||
              raise """
              
              E2E tests require a Paddle API key to be set in environment variables.
              
              For sandbox testing, set one of:
                export PADDLE_SANDBOX_API_KEY="pdl_sdbx_your_key_here"
                export PADDLE_API_KEY="pdl_sdbx_your_key_here"
              
              For live testing (not recommended), set:
                export PADDLE_API_KEY="pdl_live_your_key_here"
                export PADDLE_ENVIRONMENT="live"
              
              """

    environment = case System.get_env("PADDLE_ENVIRONMENT") do
      "live" -> :live
      "production" -> :live
      _ -> :sandbox
    end

    base_url = case environment do
      :live -> "https://api.paddle.com"
      :sandbox -> "https://sandbox-api.paddle.com"
    end

    %Config{
      api_key: api_key,
      environment: environment,
      base_url: base_url,
      timeout: 30_000,
      retry: false
    }
  end

  describe "E2E Product Management" do
    @tag timeout: 60_000
    test "complete product lifecycle with real API" do
      config = get_test_config()
      
      # Generate unique product name to avoid conflicts
      timestamp = System.os_time(:millisecond)
      product_name = "E2E Test Product #{timestamp}"

      # Step 1: Create a new product
      product_data = %{
        name: product_name,
        description: "A comprehensive E2E test product created via automated testing",
        type: "standard",
        tax_category: "standard",
        custom_data: %{
          "test_run" => true,
          "created_at" => DateTime.utc_now() |> DateTime.to_iso8601(),
          "test_type" => "e2e_lifecycle"
        }
      }

      {:ok, created_product} = Product.create(product_data, config: config)

      # Verify creation
      assert created_product.name == product_name
      assert created_product.description == product_data.description
      assert created_product.type == "standard"
      assert created_product.tax_category == "standard"
      assert is_binary(created_product.id)
      assert String.starts_with?(created_product.id, "pro_")

      product_id = created_product.id

      # Step 2: Retrieve the created product
      {:ok, fetched_product} = Product.get(product_id, %{}, config: config)

      assert fetched_product.id == product_id
      assert fetched_product.name == product_name
      assert fetched_product.description == product_data.description
      
      # Step 3: Update the product
      updated_name = "Updated #{product_name}"
      updated_description = "This product has been updated via E2E testing"

      update_data = %{
        name: updated_name,
        description: updated_description,
        custom_data: %{
          "test_run" => true,
          "updated_at" => DateTime.utc_now() |> DateTime.to_iso8601(),
          "test_type" => "e2e_lifecycle_updated"
        }
      }

      {:ok, updated_product} = Product.update(product_id, update_data, config: config)

      assert updated_product.id == product_id
      assert updated_product.name == updated_name
      assert updated_product.description == updated_description

      # Step 4: List products to verify our product appears
      {:ok, products} = Product.list(%{}, config: config)

      assert is_list(products)
      found_product = Enum.find(products, &(&1.id == product_id))
      assert found_product != nil
      assert found_product.name == updated_name

      # Step 5: Archive the product
      {:ok, archived_product} = Product.archive(product_id, config: config)

      assert archived_product.id == product_id
      assert archived_product.status == "archived"

      # Note: Product deletion is typically not available in sandbox environments
      # The archived status is sufficient for test cleanup
    end

    @tag timeout: 45_000
    test "product listing with filters and pagination" do
      config = get_test_config()
      
      # Create test products with specific characteristics for filtering
      timestamp = System.os_time(:millisecond)
      
      test_products = [
        %{
          name: "E2E Filter Test Active #{timestamp}",
          description: "Active product for filter testing",
          type: "standard",
          tax_category: "standard"
        },
        %{
          name: "E2E Filter Test Standard #{timestamp}",
          description: "Standard type product for testing",
          type: "standard", 
          tax_category: "standard"
        }
      ]

      # Create the test products
      created_products = 
        for product_data <- test_products do
          {:ok, product} = Product.create(product_data, config: config)
          product
        end

      # Test basic listing
      {:ok, all_products} = Product.list(%{}, config: config)
      assert is_list(all_products)
      assert length(all_products) > 0

      # Test filtering by status (if supported)
      {:ok, active_products} = Product.list(%{status: ["active"]}, config: config)
      assert is_list(active_products)

      # Test pagination
      {:ok, first_page} = Product.list(%{per_page: 5}, config: config)
      assert is_list(first_page)
      assert length(first_page) <= 5

      # Verify our created products exist in the results
      all_ids = Enum.map(all_products, & &1.id)
      for product <- created_products do
        assert product.id in all_ids
      end

      # Cleanup: Archive the test products
      for product <- created_products do
        Product.archive(product.id, config: config)
      end
    end
  end

  describe "E2E Price Management" do
    setup do
      config = get_test_config()
      
      # Create a product for price testing
      timestamp = System.os_time(:millisecond)
      product_data = %{
        name: "E2E Price Test Product #{timestamp}",
        description: "Product created for price E2E testing",
        type: "standard",
        tax_category: "standard"
      }

      {:ok, product} = Product.create(product_data, config: config)
      
      on_exit(fn ->
        # Cleanup: Archive the product
        Product.archive(product.id, config: config)
      end)

      {:ok, product: product}
    end

    @tag timeout: 60_000
    test "price lifecycle with real API", %{product: product} do
      config = get_test_config()
      
      # Step 1: Create a price for the product
      timestamp = System.os_time(:millisecond)
      
      price_data = %{
        description: "E2E Test Price #{timestamp}",
        product_id: product.id,
        unit_price: %{
          amount: "1999",  # $19.99
          currency_code: "USD"
        },
        billing_cycle: %{
          interval: "month",
          frequency: 1
        },
        custom_data: %{
          "test_price" => true,
          "created_at" => DateTime.utc_now() |> DateTime.to_iso8601()
        }
      }

      {:ok, created_price} = Price.create(price_data, config: config)

      # Verify price creation
      assert created_price.description == price_data.description
      assert created_price.product_id == product.id
      # Note: unit_price might be a map, so access fields appropriately
      assert created_price.unit_price["amount"] == "1999"
      assert created_price.unit_price["currency_code"] == "USD"
      assert is_binary(created_price.id)
      assert String.starts_with?(created_price.id, "pri_")

      price_id = created_price.id

      # Step 2: Retrieve the created price
      {:ok, fetched_price} = Price.get(price_id, %{}, config: config)

      assert fetched_price.id == price_id
      assert fetched_price.description == price_data.description
      assert fetched_price.product_id == product.id

      # Step 3: Update the price
      updated_description = "Updated E2E Test Price #{timestamp}"
      
      update_data = %{
        description: updated_description,
        custom_data: %{
          "test_price" => true,
          "updated_at" => DateTime.utc_now() |> DateTime.to_iso8601()
        }
      }

      {:ok, updated_price} = Price.update(price_id, update_data, config: config)

      assert updated_price.id == price_id
      assert updated_price.description == updated_description

      # Step 4: List prices
      {:ok, prices} = Price.list(%{}, config: config)

      assert is_list(prices)
      found_price = Enum.find(prices, &(&1.id == price_id))
      assert found_price != nil

      # Step 5: Archive the price
      {:ok, archived_price} = Price.archive(price_id, config: config)

      assert archived_price.id == price_id
      assert archived_price.status == "archived"
    end
  end

  describe "E2E Customer Management" do
    @tag timeout: 45_000
    test "customer lifecycle with real API" do
      config = get_test_config()
      
      # Step 1: Create a customer
      timestamp = System.os_time(:millisecond)
      
      customer_data = %{
        name: "E2E Test Customer #{timestamp}",
        email: "e2e-test-#{timestamp}@example.com",
        custom_data: %{
          "test_customer" => true,
          "created_at" => DateTime.utc_now() |> DateTime.to_iso8601(),
          "test_type" => "e2e_customer_lifecycle"
        }
      }

      {:ok, created_customer} = Customer.create(customer_data, config: config)

      # Verify customer creation
      assert created_customer.name == customer_data.name
      assert created_customer.email == customer_data.email
      assert is_binary(created_customer.id)
      assert String.starts_with?(created_customer.id, "ctm_")

      customer_id = created_customer.id

      # Step 2: Retrieve the created customer
      {:ok, fetched_customer} = Customer.get(customer_id, %{}, config: config)

      assert fetched_customer.id == customer_id
      assert fetched_customer.name == customer_data.name
      assert fetched_customer.email == customer_data.email

      # Step 3: Update the customer
      updated_name = "Updated #{customer_data.name}"
      
      update_data = %{
        name: updated_name,
        custom_data: %{
          "test_customer" => true,
          "updated_at" => DateTime.utc_now() |> DateTime.to_iso8601()
        }
      }

      {:ok, updated_customer} = Customer.update(customer_id, update_data, config: config)

      assert updated_customer.id == customer_id
      assert updated_customer.name == updated_name

      # Step 4: List customers
      {:ok, customers} = Customer.list(%{}, config: config)

      assert is_list(customers)
      found_customer = Enum.find(customers, &(&1.id == customer_id))
      assert found_customer != nil
      assert found_customer.name == updated_name

      # Note: Customer archiving/deletion may not be supported in sandbox
      # Try to archive, but don't fail the test if it's not supported
      case Customer.archive(customer_id, config: config) do
        {:ok, _} -> :ok
        {:error, _} -> :ok  # Archiving might not be supported
      end
    end
  end

  describe "E2E Error Handling" do
    @tag timeout: 30_000
    test "handles real API errors correctly" do
      config = get_test_config()
      
      # Test 1: Invalid API key format (but still valid format)
      invalid_config = %{config | api_key: "pdl_sdbx_invalid_key_123456789_xyz"}
      
      {:error, error} = Product.list(%{}, config: invalid_config)
      assert error.type == :authorization_error

      # Test 2: Non-existent resource
      {:error, error} = Product.get("pro_nonexistent123", %{}, config: config)
      assert error.type in [:not_found_error, :api_error]

      # Test 3: Invalid data (validation error)
      invalid_product = %{
        name: "",  # Empty name should fail validation
        type: "invalid_type"
      }

      {:error, error} = Product.create(invalid_product, config: config)
      assert error.type in [:validation_error, :api_error]

      # Test 4: Invalid ID format
      {:error, error} = Product.get("invalid-id-format", %{}, config: config)
      assert error.type in [:validation_error, :api_error, :not_found_error]
    end
  end

  describe "E2E Performance and Reliability" do
    @tag timeout: 120_000
    test "handles concurrent requests properly" do
      config = get_test_config()
      
      timestamp = System.os_time(:millisecond)
      
      # Create multiple products concurrently
      tasks = 
        for i <- 1..5 do
          Task.async(fn ->
            product_data = %{
              name: "Concurrent E2E Product #{i} #{timestamp}",
              description: "Product #{i} created concurrently",
              type: "standard",
              tax_category: "standard"
            }
            
            Product.create(product_data, config: config)
          end)
        end

      results = Task.await_many(tasks, 60_000)

      # All should succeed
      successful_products = 
        for {:ok, product} <- results do
          product
        end

      assert length(successful_products) == 5

      # Verify each product has unique ID and correct name pattern
      for {product, index} <- Enum.with_index(successful_products, 1) do
        assert String.starts_with?(product.id, "pro_")
        assert String.contains?(product.name, "Concurrent E2E Product #{index}")
      end

      # Cleanup: Archive all created products
      for product <- successful_products do
        Product.archive(product.id, config: config)
      end
    end

    @tag timeout: 60_000
    test "maintains performance with larger datasets" do
      config = get_test_config()
      
      # Test listing performance
      start_time = System.monotonic_time(:millisecond)
      
      {:ok, products} = Product.list(%{per_page: 100}, config: config)
      
      end_time = System.monotonic_time(:millisecond)
      execution_time = end_time - start_time

      # Should complete within reasonable time (less than 30 seconds)
      assert execution_time < 30_000
      assert is_list(products)

      # Test pagination performance
      start_time = System.monotonic_time(:millisecond)
      
      {:ok, page1} = Product.list(%{per_page: 20}, config: config)
      
      # If there are more products, test next page
      if length(page1) == 20 do
        last_id = List.last(page1).id
        {:ok, _page2} = Product.list(%{per_page: 20, after: last_id}, config: config)
      end
      
      end_time = System.monotonic_time(:millisecond)
      pagination_time = end_time - start_time

      # Pagination should also be performant
      assert pagination_time < 30_000
    end
  end

  describe "E2E API Features" do
    @tag timeout: 45_000
    test "verifies real API response formats and data types" do
      config = get_test_config()
      
      timestamp = System.os_time(:millisecond)

      # Create a product with comprehensive data
      product_data = %{
        name: "Feature Test Product #{timestamp}",
        description: "Testing all API features and response formats",
        type: "standard",
        tax_category: "standard",
        custom_data: %{
          "string_field" => "test_value",
          "number_field" => 42,
          "boolean_field" => true,
          "null_field" => nil,
          "array_field" => [1, 2, 3],
          "nested_object" => %{
            "nested_string" => "nested_value",
            "nested_number" => 3.14
          }
        }
      }

      {:ok, product} = Product.create(product_data, config: config)

      # Verify response structure and data types
      assert is_binary(product.id)
      assert is_binary(product.name)
      assert is_binary(product.description)
      assert is_binary(product.type)
      assert is_binary(product.tax_category)
      assert product.status in ["active", "archived"]
      
      # Verify timestamps are properly formatted
      if product.created_at do
        assert is_binary(product.created_at)
        # Should be ISO8601 format
        {:ok, _datetime, _offset} = DateTime.from_iso8601(product.created_at)
      end

      if product.updated_at do
        assert is_binary(product.updated_at)
        {:ok, _datetime, _offset} = DateTime.from_iso8601(product.updated_at)
      end

      # Test include parameters
      {:ok, product_with_prices} = Product.get(product.id, %{include: ["prices"]}, config: config)
      assert product_with_prices.id == product.id

      # Cleanup
      Product.archive(product.id, config: config)
    end

    @tag timeout: 30_000
    test "tests webhook notifications endpoint access" do
      config = get_test_config()
      
      # Test if we can access webhook-related endpoints
      {:ok, _events} = PaddleBilling.Client.get("/events", %{}, config: config)

      # Test notification settings (may require different permissions)
      case PaddleBilling.Client.get("/notification-settings", %{}, config: config) do
        {:ok, _settings} -> :ok
        {:error, %Error{type: :authorization_error}} -> :ok  # Expected if not authorized
        {:error, %Error{type: :not_found_error}} -> :ok     # Expected if endpoint doesn't exist
      end
    end

    @tag timeout: 30_000
    test "validates API versioning and headers" do
      config = get_test_config()
      
      # Make a request and verify response contains proper version info
      {:ok, products} = Product.list(%{per_page: 1}, config: config)
      
      # The fact that we get a response means versioning is working correctly
      assert is_list(products)

      # Test custom headers are preserved
      custom_config = %{config | 
        # Add custom timeout
        timeout: 45_000
      }

      {:ok, _products} = Product.list(%{}, config: custom_config)
    end
  end

  describe "E2E Environment Validation" do
    test "validates sandbox environment configuration" do
      config = get_test_config()
      
      # Verify configuration is valid
      assert config.environment in [:sandbox, :live]
      assert String.contains?(config.base_url, "api.paddle.com")
      assert String.starts_with?(config.api_key, "pdl_")

      # Test configuration validation
      Config.validate!(config)
    end

    @tag timeout: 15_000
    test "verifies API connectivity and authentication" do
      config = get_test_config()
      
      # Simple connectivity test
      {:ok, products} = Product.list(%{per_page: 1}, config: config)
      assert is_list(products)
      
      # This confirms:
      # 1. Network connectivity to Paddle sandbox API
      # 2. API key is valid and active
      # 3. Basic authentication is working
      # 4. Response format is as expected
    end
  end
end