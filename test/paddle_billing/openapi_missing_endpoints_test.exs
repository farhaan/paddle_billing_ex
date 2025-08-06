defmodule PaddleBilling.OpenApiMissingEndpointsTest do
  @moduledoc """
  Tests for Paddle API endpoints that are defined in the OpenAPI specification
  but not yet implemented in the PaddleBilling client library.

  These tests serve as:
  1. Documentation of required endpoints per OpenAPI spec
  2. Validation framework for future implementations
  3. Compliance checking against official Paddle API

  Based on: https://github.com/PaddleHQ/paddle-openapi/blob/main/v1/openapi.yaml

  Priority Implementation Order (based on API importance):
  1. Prices - Product pricing management  
  2. Customers - Customer lifecycle management
  3. Subscriptions - Recurring billing and subscription management
  4. Transactions - Payment history and transaction details
  5. Addresses - Customer address management
  6. Adjustments - Post-billing modifications
  """

  use ExUnit.Case, async: true
  import PaddleBilling.TestHelpers

  alias PaddleBilling.{Client, Price, Customer, Subscription, Transaction, Error}

  describe "Prices API compliance (Priority 1)" do
    setup do
      bypass = Bypass.open()
      config = create_bypass_config(bypass)
      {:ok, bypass: bypass, config: config}
    end

    test "GET /prices - List prices", %{bypass: bypass, config: config} do
      # OpenAPI spec: List prices with filtering and pagination
      prices_response = %{
        "data" => [
          %{
            "id" => "pri_01gsz4t5hdjse780zja8vvr7jg",
            "description" => "Monthly subscription",
            "product_id" => "pro_01gsz4t5hdjse780zja8vvr7jg",
            "type" => "standard",
            "billing_cycle" => %{
              "interval" => "month",
              "frequency" => 1
            },
            "trial_period" => nil,
            "tax_mode" => "account_setting",
            "unit_price" => %{
              "amount" => "2400",
              "currency_code" => "USD"
            },
            "custom_data" => nil,
            "status" => "active",
            "created_at" => "2023-06-01T13:30:50.302Z",
            "updated_at" => "2023-06-01T13:30:50.302Z"
          }
        ],
        "meta" => %{
          "request_id" => "req_01gsz4t5hdjse780zja8vvr7jg",
          "pagination" => %{
            "per_page" => 50,
            "next" => nil,
            "has_more" => false,
            "estimated_total" => 1
          }
        }
      }

      Bypass.expect_once(bypass, "GET", "/prices", fn conn ->
        assert_valid_paddle_headers(conn)

        query_params = URI.decode_query(conn.query_string)
        # Validate common price filtering parameters
        if query_params["product_id"],
          do: assert(String.starts_with?(query_params["product_id"], "pro_"))

        if query_params["status"], do: assert(query_params["status"] in ["active", "archived"])
        if query_params["include"], do: assert(query_params["include"] in ["product"])

        Plug.Conn.resp(conn, 200, Jason.encode!(prices_response))
      end)

      # Now using the implemented PaddleBilling.Price module
      {:ok, prices} = Price.list(%{product_id: ["pro_123"]}, config: config)

      assert length(prices) == 1
      price = hd(prices)
      assert price.id == "pri_01gsz4t5hdjse780zja8vvr7jg"
      assert price.unit_price["amount"] == "2400"
      assert price.unit_price["currency_code"] == "USD"
    end

    test "POST /prices - Create price", %{bypass: bypass, config: config} do
      # OpenAPI spec: Create a new price
      price_data = %{
        description: "Monthly Pro Plan",
        product_id: "pro_01gsz4t5hdjse780zja8vvr7jg",
        type: "standard",
        billing_cycle: %{
          interval: "month",
          frequency: 1
        },
        unit_price: %{
          amount: "2999",
          currency_code: "USD"
        },
        tax_mode: "account_setting"
      }

      create_response = %{
        "data" => %{
          "id" => "pri_01h123456789abcdefghijklmn",
          "description" => "Monthly Pro Plan",
          "product_id" => "pro_01gsz4t5hdjse780zja8vvr7jg",
          "type" => "standard",
          "billing_cycle" => %{
            "interval" => "month",
            "frequency" => 1
          },
          "unit_price" => %{
            "amount" => "2999",
            "currency_code" => "USD"
          },
          "tax_mode" => "account_setting",
          "status" => "active",
          "created_at" => "2023-06-01T13:30:50.302Z",
          "updated_at" => "2023-06-01T13:30:50.302Z"
        }
      }

      Bypass.expect_once(bypass, "POST", "/prices", fn conn ->
        assert_valid_paddle_headers(conn)

        {:ok, body, conn} = Plug.Conn.read_body(conn)
        parsed_body = Jason.decode!(body)

        # Validate required fields per OpenAPI spec
        assert parsed_body["description"] == "Monthly Pro Plan"
        assert parsed_body["product_id"] == "pro_01gsz4t5hdjse780zja8vvr7jg"
        assert parsed_body["type"] == "standard"
        assert is_map(parsed_body["billing_cycle"])
        assert is_map(parsed_body["unit_price"])
        assert parsed_body["unit_price"]["amount"] == "2999"

        Plug.Conn.resp(conn, 201, Jason.encode!(create_response))
      end)

      # Now using the implemented PaddleBilling.Price module
      {:ok, price} = Price.create(price_data, config: config)

      assert price.id == "pri_01h123456789abcdefghijklmn"
      assert price.unit_price["amount"] == "2999"
    end
  end

  describe "Customers API compliance (Priority 2)" do
    setup do
      bypass = Bypass.open()
      config = create_bypass_config(bypass)
      {:ok, bypass: bypass, config: config}
    end

    test "GET /customers - List customers", %{bypass: bypass, config: config} do
      # OpenAPI spec: List customers with filtering
      customers_response = %{
        "data" => [
          %{
            "id" => "ctm_01gsz4t5hdjse780zja8vvr7jg",
            "name" => "John Doe",
            "email" => "john.doe@example.com",
            "locale" => "en",
            "status" => "active",
            "custom_data" => nil,
            "created_at" => "2023-06-01T13:30:50.302Z",
            "updated_at" => "2023-06-01T13:30:50.302Z",
            "marketing_consent" => false,
            "import_meta" => nil
          }
        ],
        "meta" => %{
          "request_id" => "req_01gsz4t5hdjse780zja8vvr7jg",
          "pagination" => %{
            "per_page" => 50,
            "next" => nil,
            "has_more" => false,
            "estimated_total" => 1
          }
        }
      }

      Bypass.expect_once(bypass, "GET", "/customers", fn conn ->
        assert_valid_paddle_headers(conn)

        query_params = URI.decode_query(conn.query_string)
        # Validate customer filtering parameters per OpenAPI spec
        if query_params["email"], do: assert(String.contains?(query_params["email"], "@"))
        if query_params["status"], do: assert(query_params["status"] in ["active", "archived"])

        if query_params["include"],
          do: assert(query_params["include"] in ["addresses", "businesses"])

        Plug.Conn.resp(conn, 200, Jason.encode!(customers_response))
      end)

      # Now using the implemented PaddleBilling.Customer module
      {:ok, customers} = Customer.list(%{}, config: config)

      assert length(customers) == 1
      customer = hd(customers)
      assert customer.id == "ctm_01gsz4t5hdjse780zja8vvr7jg"
      assert customer.email == "john.doe@example.com"
    end

    test "POST /customers - Create customer", %{bypass: bypass, config: config} do
      # OpenAPI spec: Create a new customer
      customer_data = %{
        name: "Jane Smith",
        email: "jane.smith@example.com",
        locale: "en",
        custom_data: %{
          "source" => "website",
          "campaign" => "summer2024"
        }
      }

      create_response = %{
        "data" => %{
          "id" => "ctm_01h123456789abcdefghijklmn",
          "name" => "Jane Smith",
          "email" => "jane.smith@example.com",
          "locale" => "en",
          "status" => "active",
          "custom_data" => %{
            "source" => "website",
            "campaign" => "summer2024"
          },
          "created_at" => "2023-06-01T13:30:50.302Z",
          "updated_at" => "2023-06-01T13:30:50.302Z",
          "marketing_consent" => false,
          "import_meta" => nil
        }
      }

      Bypass.expect_once(bypass, "POST", "/customers", fn conn ->
        assert_valid_paddle_headers(conn)

        {:ok, body, conn} = Plug.Conn.read_body(conn)
        parsed_body = Jason.decode!(body)

        # Validate required fields per OpenAPI spec
        assert parsed_body["email"] == "jane.smith@example.com"
        assert String.contains?(parsed_body["email"], "@")
        if parsed_body["name"], do: assert(is_binary(parsed_body["name"]))

        Plug.Conn.resp(conn, 201, Jason.encode!(create_response))
      end)

      # Now using the implemented PaddleBilling.Customer module
      {:ok, customer} = Customer.create(customer_data, config: config)

      assert customer.id == "ctm_01h123456789abcdefghijklmn"
      assert customer.email == "jane.smith@example.com"
    end
  end

  describe "Subscriptions API compliance (Priority 3)" do
    setup do
      bypass = Bypass.open()
      config = create_bypass_config(bypass)
      {:ok, bypass: bypass, config: config}
    end

    test "GET /subscriptions - List subscriptions", %{bypass: bypass, config: config} do
      # OpenAPI spec: List subscriptions with comprehensive filtering
      subscriptions_response = %{
        "data" => [
          %{
            "id" => "sub_01gsz4t5hdjse780zja8vvr7jg",
            "status" => "active",
            "customer_id" => "ctm_01gsz4t5hdjse780zja8vvr7jg",
            "address_id" => "add_01gsz4t5hdjse780zja8vvr7jg",
            "business_id" => nil,
            "currency_code" => "USD",
            "created_at" => "2023-06-01T13:30:50.302Z",
            "updated_at" => "2023-06-01T13:30:50.302Z",
            "started_at" => "2023-06-01T13:30:50.302Z",
            "first_billed_at" => "2023-06-01T13:30:50.302Z",
            "next_billed_at" => "2023-07-01T13:30:50.302Z",
            "paused_at" => nil,
            "canceled_at" => nil,
            "custom_data" => nil,
            "collection_mode" => "automatic",
            "billing_details" => nil,
            "current_billing_period" => %{
              "starts_at" => "2023-06-01T13:30:50.302Z",
              "ends_at" => "2023-07-01T13:30:50.302Z"
            },
            "billing_cycle" => %{
              "interval" => "month",
              "frequency" => 1
            },
            "recurring_transaction_details" => %{
              "tax_rates_used" => [],
              "totals" => %{
                "subtotal" => "2400",
                "discount" => "0",
                "tax" => "240",
                "total" => "2640",
                "credit" => "0",
                "balance" => "2640",
                "grand_total" => "2640",
                "fee" => nil,
                "earnings" => nil,
                "currency_code" => "USD"
              },
              "line_items" => []
            },
            "scheduled_change" => nil,
            "items" => [
              %{
                "status" => "active",
                "quantity" => 1,
                "recurring" => true,
                "created_at" => "2023-06-01T13:30:50.302Z",
                "updated_at" => "2023-06-01T13:30:50.302Z",
                "previously_billed_at" => "2023-06-01T13:30:50.302Z",
                "next_billed_at" => "2023-07-01T13:30:50.302Z",
                "trial_dates" => nil,
                "price" => %{
                  "id" => "pri_01gsz4t5hdjse780zja8vvr7jg",
                  "description" => "Monthly Pro Plan",
                  "type" => "standard"
                }
              }
            ],
            "discount" => nil,
            "import_meta" => nil
          }
        ],
        "meta" => %{
          "request_id" => "req_01gsz4t5hdjse780zja8vvr7jg",
          "pagination" => %{
            "per_page" => 50,
            "next" => nil,
            "has_more" => false,
            "estimated_total" => 1
          }
        }
      }

      Bypass.expect_once(bypass, "GET", "/subscriptions", fn conn ->
        assert_valid_paddle_headers(conn)

        query_params = URI.decode_query(conn.query_string)
        # Validate subscription filtering parameters per OpenAPI spec
        if query_params["status"] do
          valid_statuses = ["active", "canceled", "past_due", "paused", "trialing"]
          assert query_params["status"] in valid_statuses
        end

        if query_params["customer_id"],
          do: assert(String.starts_with?(query_params["customer_id"], "ctm_"))

        if query_params["price_id"],
          do: assert(String.starts_with?(query_params["price_id"], "pri_"))

        Plug.Conn.resp(conn, 200, Jason.encode!(subscriptions_response))
      end)

      # Now using the implemented PaddleBilling.Subscription module
      {:ok, subscriptions} = Subscription.list(%{status: ["active"]}, config: config)

      assert length(subscriptions) == 1
      subscription = hd(subscriptions)
      assert subscription.id == "sub_01gsz4t5hdjse780zja8vvr7jg"
      assert subscription.status == "active"
      assert subscription.currency_code == "USD"
    end

    test "POST /subscriptions/{subscription_id}/cancel - Cancel subscription", %{
      bypass: bypass,
      config: config
    } do
      # OpenAPI spec: Cancel a subscription with optional effective time
      subscription_id = "sub_01gsz4t5hdjse780zja8vvr7jg"

      cancel_params = %{
        effective_from: "next_billing_period",
        proration_billing_mode: "prorated_immediately"
      }

      cancel_response = %{
        "data" => %{
          "id" => subscription_id,
          "status" => "canceled",
          "customer_id" => "ctm_01gsz4t5hdjse780zja8vvr7jg",
          "canceled_at" => "2023-07-01T13:30:50.302Z",
          "updated_at" => "2023-06-15T10:20:30.123Z"
        }
      }

      Bypass.expect_once(bypass, "POST", "/subscriptions/#{subscription_id}/cancel", fn conn ->
        assert_valid_paddle_headers(conn)

        {:ok, body, conn} = Plug.Conn.read_body(conn)
        parsed_body = Jason.decode!(body)

        # Validate cancellation parameters per OpenAPI spec
        if parsed_body["effective_from"] do
          valid_options = ["immediately", "next_billing_period"]
          assert parsed_body["effective_from"] in valid_options
        end

        Plug.Conn.resp(conn, 200, Jason.encode!(cancel_response))
      end)

      # Now using the implemented PaddleBilling.Subscription module
      {:ok, subscription} = Subscription.cancel(subscription_id, cancel_params, config: config)

      assert subscription.status == "canceled"
      assert subscription.canceled_at == "2023-07-01T13:30:50.302Z"
    end
  end

  describe "Transactions API compliance (Priority 4)" do
    setup do
      bypass = Bypass.open()
      config = create_bypass_config(bypass)
      {:ok, bypass: bypass, config: config}
    end

    test "GET /transactions - List transactions", %{bypass: bypass, config: config} do
      # OpenAPI spec: List transactions with comprehensive filtering
      transactions_response = %{
        "data" => [
          %{
            "id" => "txn_01gsz4t5hdjse780zja8vvr7jg",
            "status" => "completed",
            "customer_id" => "ctm_01gsz4t5hdjse780zja8vvr7jg",
            "address_id" => "add_01gsz4t5hdjse780zja8vvr7jg",
            "business_id" => nil,
            "custom_data" => nil,
            "currency_code" => "USD",
            "origin" => "api",
            "subscription_id" => "sub_01gsz4t5hdjse780zja8vvr7jg",
            "invoice_id" => nil,
            "invoice_number" => nil,
            "collection_mode" => "automatic",
            "discount_id" => nil,
            "billing_details" => nil,
            "billing_period" => %{
              "starts_at" => "2023-06-01T13:30:50.302Z",
              "ends_at" => "2023-07-01T13:30:50.302Z"
            },
            "items" => [
              %{
                "price_id" => "pri_01gsz4t5hdjse780zja8vvr7jg",
                "quantity" => 1,
                "proration" => nil
              }
            ],
            "details" => %{
              "tax_rates_used" => [],
              "totals" => %{
                "subtotal" => "2400",
                "discount" => "0",
                "tax" => "240",
                "total" => "2640",
                "credit" => "0",
                "balance" => "2640",
                "grand_total" => "2640",
                "fee" => nil,
                "earnings" => nil,
                "currency_code" => "USD"
              },
              "adjusted_totals" => %{
                "subtotal" => "2400",
                "tax" => "240",
                "total" => "2640",
                "grand_total" => "2640",
                "fee" => nil,
                "earnings" => nil,
                "breakdown" => [],
                "currency_code" => "USD"
              },
              "payout_totals" => nil,
              "adjusted_payout_totals" => nil,
              "line_items" => []
            },
            "payments" => [],
            "checkout" => nil,
            "created_at" => "2023-06-01T13:30:50.302Z",
            "updated_at" => "2023-06-01T13:30:50.302Z"
          }
        ],
        "meta" => %{
          "request_id" => "req_01gsz4t5hdjse780zja8vvr7jg",
          "pagination" => %{
            "per_page" => 50,
            "next" => nil,
            "has_more" => false,
            "estimated_total" => 1
          }
        }
      }

      Bypass.expect_once(bypass, "GET", "/transactions", fn conn ->
        assert_valid_paddle_headers(conn)

        query_params = URI.decode_query(conn.query_string)
        # Validate transaction filtering parameters per OpenAPI spec
        if query_params["status"] do
          valid_statuses = [
            "draft",
            "ready",
            "billed",
            "paid",
            "completed",
            "canceled",
            "past_due"
          ]

          assert query_params["status"] in valid_statuses
        end

        if query_params["customer_id"],
          do: assert(String.starts_with?(query_params["customer_id"], "ctm_"))

        if query_params["subscription_id"],
          do: assert(String.starts_with?(query_params["subscription_id"], "sub_"))

        Plug.Conn.resp(conn, 200, Jason.encode!(transactions_response))
      end)

      # Now using the implemented PaddleBilling.Transaction module
      {:ok, transactions} = Transaction.list(%{status: ["completed"]}, config: config)

      assert length(transactions) == 1
      transaction = hd(transactions)
      assert transaction.id == "txn_01gsz4t5hdjse780zja8vvr7jg"
      assert transaction.status == "completed"
      assert transaction.currency_code == "USD"
    end
  end

  describe "Error handling for missing endpoints" do
    setup do
      bypass = Bypass.open()
      config = create_bypass_config(bypass)
      {:ok, bypass: bypass, config: config}
    end

    test "handles not found errors consistently across endpoints", %{
      bypass: bypass,
      config: config
    } do
      # Test that all endpoints return consistent error format per OpenAPI spec
      endpoints_to_test = [
        {"GET", "/prices/pri_nonexistent"},
        {"GET", "/customers/ctm_nonexistent"},
        {"GET", "/subscriptions/sub_nonexistent"},
        {"GET", "/transactions/txn_nonexistent"}
      ]

      not_found_response = %{
        "error" => %{
          "type" => "request_error",
          "code" => "entity_not_found",
          "detail" => "Unable to find the requested resource.",
          "documentation_url" => "https://developer.paddle.com/errors/entity-not-found"
        }
      }

      for {method, path} <- endpoints_to_test do
        Bypass.expect_once(bypass, method, path, fn conn ->
          assert_valid_paddle_headers(conn)
          Plug.Conn.resp(conn, 404, Jason.encode!(not_found_response))
        end)

        result =
          case method do
            "GET" -> Client.get(path, %{}, config: config)
            "POST" -> Client.post(path, %{}, config: config)
            "PATCH" -> Client.patch(path, %{}, config: config)
          end

        assert {:error, %Error{type: :not_found_error}} = result
      end
    end
  end
end
