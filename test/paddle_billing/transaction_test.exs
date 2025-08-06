defmodule PaddleBilling.TransactionTest do
  use ExUnit.Case, async: true
  import PaddleBilling.TestHelpers

  alias PaddleBilling.{Transaction, Error}

  describe "list/2" do
    setup do
      bypass = Bypass.open()
      config = create_bypass_config(bypass)
      {:ok, bypass: bypass, config: config}
    end

    test "returns list of transactions", %{bypass: bypass, config: config} do
      transactions_response = %{
        "data" => [
          %{
            "id" => "txn_01gsz4t5hdjse780zja8vvr7jg",
            "status" => "completed",
            "customer_id" => "ctm_01gsz4t5hdjse780zja8vvr7jg",
            "address_id" => "add_01gsz4t5hdjse780zja8vvr7jg",
            "business_id" => nil,
            "custom_data" => %{
              "order_id" => "ORD-2024-001",
              "sales_rep" => "jane.doe@company.com"
            },
            "currency_code" => "USD",
            "origin" => "subscription_recurring",
            "subscription_id" => "sub_01gsz4t5hdjse780zja8vvr7jg",
            "invoice_id" => "inv_01gsz4t5hdjse780zja8vvr7jg",
            "invoice_number" => "INV-2024-001",
            "collection_mode" => "automatic",
            "discount_id" => nil,
            "billing_details" => %{
              "enable_checkout" => true,
              "purchase_order_number" => "PO-2024-001"
            },
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
              "tax_rates_used" => [
                %{
                  "tax_rate" => "0.10",
                  "totals" => %{
                    "subtotal" => "2400",
                    "tax" => "240",
                    "total" => "2640"
                  }
                }
              ],
              "totals" => %{
                "subtotal" => "2400",
                "discount" => "0",
                "tax" => "240",
                "total" => "2640",
                "credit" => "0",
                "balance" => "2640",
                "grand_total" => "2640",
                "fee" => "72",
                "earnings" => "2328",
                "currency_code" => "USD"
              },
              "adjusted_totals" => %{
                "subtotal" => "2400",
                "tax" => "240",
                "total" => "2640",
                "grand_total" => "2640",
                "fee" => "72",
                "earnings" => "2328",
                "currency_code" => "USD",
                "breakdown" => []
              },
              "payout_totals" => nil,
              "adjusted_payout_totals" => nil,
              "line_items" => []
            },
            "payments" => [
              %{
                "amount" => "2640",
                "status" => "captured",
                "method_details" => %{
                  "type" => "card",
                  "card" => %{
                    "type" => "visa",
                    "last4" => "4242"
                  }
                }
              }
            ],
            "checkout" => nil,
            "created_at" => "2023-06-01T13:30:50.302Z",
            "updated_at" => "2023-06-01T13:30:50.302Z",
            "billed_at" => "2023-06-01T13:30:50.302Z",
            "import_meta" => nil
          },
          %{
            "id" => "txn_01h123456789abcdefghijklmn",
            "status" => "draft",
            "customer_id" => "ctm_01h123456789abcdefghijklmn",
            "address_id" => nil,
            "business_id" => "biz_01gsz4t5hdjse780zja8vvr7jg",
            "custom_data" => nil,
            "currency_code" => "EUR",
            "origin" => "api",
            "subscription_id" => nil,
            "invoice_id" => nil,
            "invoice_number" => nil,
            "collection_mode" => "manual",
            "discount_id" => "dsc_enterprise_discount",
            "billing_details" => %{
              "enable_checkout" => false,
              "purchase_order_number" => "PO-ENT-2024-001",
              "additional_information" => "Net-30 payment terms",
              "payment_terms" => %{
                "interval" => "month",
                "frequency" => 1
              }
            },
            "billing_period" => nil,
            "items" => [
              %{
                "price_id" => "pri_enterprise_license",
                "quantity" => 5,
                "proration" => %{
                  "rate" => "0.75",
                  "billing_period" => %{
                    "starts_at" => "2024-01-15T00:00:00Z",
                    "ends_at" => "2024-02-01T00:00:00Z"
                  }
                }
              }
            ],
            "details" => nil,
            "payments" => [],
            "checkout" => %{
              "url" => "https://checkout.paddle.com/draft-txn-123"
            },
            "created_at" => "2023-06-02T10:15:30.123Z",
            "updated_at" => "2023-06-02T10:15:30.123Z",
            "billed_at" => nil,
            "import_meta" => %{
              "external_id" => "legacy_txn_456",
              "source" => "migration_2023"
            }
          }
        ]
      }

      Bypass.expect_once(bypass, "GET", "/transactions", fn conn ->
        assert_valid_paddle_headers(conn)
        Plug.Conn.resp(conn, 200, Jason.encode!(transactions_response))
      end)

      assert {:ok, transactions} = Transaction.list(%{}, config: config)
      assert length(transactions) == 2

      [transaction1, transaction2] = transactions

      # Test completed transaction
      assert transaction1.id == "txn_01gsz4t5hdjse780zja8vvr7jg"
      assert transaction1.status == "completed"
      assert transaction1.customer_id == "ctm_01gsz4t5hdjse780zja8vvr7jg"
      assert transaction1.currency_code == "USD"
      assert transaction1.origin == "subscription_recurring"
      assert transaction1.subscription_id == "sub_01gsz4t5hdjse780zja8vvr7jg"
      assert transaction1.invoice_number == "INV-2024-001"
      assert transaction1.collection_mode == "automatic"
      assert transaction1.custom_data["order_id"] == "ORD-2024-001"
      assert transaction1.billing_details["purchase_order_number"] == "PO-2024-001"
      assert transaction1.details["totals"]["grand_total"] == "2640"
      assert length(transaction1.items) == 1
      assert length(transaction1.payments) == 1
      assert hd(transaction1.payments)["status"] == "captured"

      # Test draft transaction
      assert transaction2.id == "txn_01h123456789abcdefghijklmn"
      assert transaction2.status == "draft"
      assert transaction2.currency_code == "EUR"
      assert transaction2.origin == "api"
      assert transaction2.collection_mode == "manual"
      assert transaction2.discount_id == "dsc_enterprise_discount"
      assert transaction2.billing_details["additional_information"] == "Net-30 payment terms"
      assert transaction2.billing_details["payment_terms"]["interval"] == "month"
      assert transaction2.checkout["url"] == "https://checkout.paddle.com/draft-txn-123"
      assert transaction2.import_meta["external_id"] == "legacy_txn_456"

      item = hd(transaction2.items)
      assert item["quantity"] == 5
      assert item["proration"]["rate"] == "0.75"
    end

    test "handles filtering parameters", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/transactions", fn conn ->
        query_params = URI.decode_query(conn.query_string)

        assert query_params["customer_id"] == "ctm_123,ctm_456"
        assert query_params["subscription_id"] == "sub_789"
        assert query_params["status"] == "completed,paid"
        assert query_params["collection_mode"] == "automatic"
        assert query_params["origin"] == "api"
        assert query_params["include"] == "customer,adjustments"
        assert query_params["per_page"] == "25"

        Plug.Conn.resp(conn, 200, Jason.encode!(%{"data" => []}))
      end)

      assert {:ok, []} =
               Transaction.list(
                 %{
                   customer_id: ["ctm_123", "ctm_456"],
                   subscription_id: ["sub_789"],
                   status: ["completed", "paid"],
                   collection_mode: ["automatic"],
                   origin: ["api"],
                   include: ["customer", "adjustments"],
                   per_page: 25
                 },
                 config: config
               )
    end

    test "handles date range filtering", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/transactions", fn conn ->
        query_params = URI.decode_query(conn.query_string)

        # Date ranges are typically handled as nested parameters
        assert query_params["billed_at[from]"] == "2023-01-01T00:00:00Z"
        assert query_params["billed_at[to]"] == "2023-12-31T23:59:59Z"

        Plug.Conn.resp(conn, 200, Jason.encode!(%{"data" => []}))
      end)

      assert {:ok, []} =
               Transaction.list(
                 %{
                   billed_at: %{
                     from: "2023-01-01T00:00:00Z",
                     to: "2023-12-31T23:59:59Z"
                   }
                 },
                 config: config
               )
    end

    test "handles empty list", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/transactions", fn conn ->
        Plug.Conn.resp(conn, 200, Jason.encode!(%{"data" => []}))
      end)

      assert {:ok, []} = Transaction.list(%{}, config: config)
    end

    test "handles API errors", %{bypass: bypass, config: config} do
      setup_error_response(bypass, "GET", "/transactions", 401, %{
        "error" => %{
          "code" => "authentication_failed",
          "detail" => "Invalid API key"
        }
      })

      assert {:error, %Error{type: :authentication_error}} = Transaction.list(%{}, config: config)
    end
  end

  describe "get/3" do
    setup do
      bypass = Bypass.open()
      config = create_bypass_config(bypass)
      {:ok, bypass: bypass, config: config}
    end

    test "returns single transaction", %{bypass: bypass, config: config} do
      transaction_response = %{
        "data" => %{
          "id" => "txn_01gsz4t5hdjse780zja8vvr7jg",
          "status" => "completed",
          "customer_id" => "ctm_01gsz4t5hdjse780zja8vvr7jg",
          "address_id" => "add_01gsz4t5hdjse780zja8vvr7jg",
          "business_id" => "biz_01gsz4t5hdjse780zja8vvr7jg",
          "custom_data" => %{
            "contract_id" => "CTR-2024-001",
            "sales_rep" => "john.doe@company.com",
            "department" => "Enterprise Sales",
            "priority" => "high"
          },
          "currency_code" => "USD",
          "origin" => "api",
          "subscription_id" => nil,
          "invoice_id" => "inv_01gsz4t5hdjse780zja8vvr7jg",
          "invoice_number" => "INV-ENT-2024-001",
          "collection_mode" => "manual",
          "discount_id" => "dsc_enterprise_discount",
          "billing_details" => %{
            "enable_checkout" => false,
            "purchase_order_number" => "PO-ENT-2024-COMPLEX",
            "additional_information" => "Enterprise contract with custom payment terms",
            "payment_terms" => %{
              "interval" => "month",
              "frequency" => 3
            }
          },
          "billing_period" => %{
            "starts_at" => "2024-01-01T00:00:00Z",
            "ends_at" => "2024-04-01T00:00:00Z"
          },
          "items" => [
            %{
              "price_id" => "pri_enterprise_software",
              "quantity" => 100,
              "proration" => nil
            },
            %{
              "price_id" => "pri_support_premium",
              "quantity" => 1,
              "proration" => nil
            }
          ],
          "details" => %{
            "tax_rates_used" => [
              %{
                "tax_rate" => "0.08",
                "totals" => %{
                  "subtotal" => "50000",
                  "tax" => "4000",
                  "total" => "54000"
                }
              }
            ],
            "totals" => %{
              "subtotal" => "50000",
              "discount" => "5000",
              "tax" => "4000",
              "total" => "49000",
              "credit" => "0",
              "balance" => "49000",
              "grand_total" => "49000",
              "fee" => "1470",
              "earnings" => "47530",
              "currency_code" => "USD"
            },
            "adjusted_totals" => %{
              "subtotal" => "50000",
              "tax" => "4000",
              "total" => "49000",
              "grand_total" => "49000",
              "fee" => "1470",
              "earnings" => "47530",
              "currency_code" => "USD",
              "breakdown" => [
                %{
                  "type" => "discount",
                  "amount" => "-5000"
                }
              ]
            },
            "payout_totals" => %{
              "subtotal" => "47530",
              "fee" => "1470",
              "currency_code" => "USD"
            },
            "adjusted_payout_totals" => %{
              "subtotal" => "47530",
              "fee" => "1470",
              "currency_code" => "USD"
            },
            "line_items" => [
              %{
                "id" => "txnitm_01gsz4t5hdjse780zja8vvr7jg",
                "price_id" => "pri_enterprise_software",
                "quantity" => 100,
                "totals" => %{
                  "subtotal" => "45000",
                  "discount" => "4500",
                  "tax" => "3600",
                  "total" => "44100"
                }
              }
            ]
          },
          "payments" => [
            %{
              "amount" => "49000",
              "status" => "captured",
              "captured_at" => "2024-01-15T10:30:00Z",
              "method_details" => %{
                "type" => "wire_transfer",
                "wire_transfer" => %{
                  "reference" => "WT-ENT-2024-001"
                }
              }
            }
          ],
          "checkout" => nil,
          "created_at" => "2023-06-01T13:30:50.302Z",
          "updated_at" => "2024-01-15T10:30:00Z",
          "billed_at" => "2024-01-15T10:30:00Z",
          "import_meta" => %{
            "external_id" => "legacy_enterprise_txn_123",
            "source" => "crm_integration",
            "imported_at" => "2023-12-01T00:00:00Z"
          }
        }
      }

      Bypass.expect_once(bypass, "GET", "/transactions/txn_01gsz4t5hdjse780zja8vvr7jg", fn conn ->
        assert_valid_paddle_headers(conn)
        Plug.Conn.resp(conn, 200, Jason.encode!(transaction_response))
      end)

      assert {:ok, transaction} =
               Transaction.get("txn_01gsz4t5hdjse780zja8vvr7jg", %{}, config: config)

      assert transaction.id == "txn_01gsz4t5hdjse780zja8vvr7jg"
      assert transaction.status == "completed"
      assert transaction.customer_id == "ctm_01gsz4t5hdjse780zja8vvr7jg"
      assert transaction.currency_code == "USD"
      assert transaction.origin == "api"
      assert transaction.invoice_number == "INV-ENT-2024-001"
      assert transaction.collection_mode == "manual"
      assert transaction.discount_id == "dsc_enterprise_discount"
      assert transaction.custom_data["contract_id"] == "CTR-2024-001"
      assert transaction.billing_details["purchase_order_number"] == "PO-ENT-2024-COMPLEX"
      assert transaction.billing_details["payment_terms"]["frequency"] == 3
      assert transaction.details["totals"]["grand_total"] == "49000"
      assert transaction.details["totals"]["discount"] == "5000"
      assert length(transaction.items) == 2
      assert length(transaction.payments) == 1

      payment = hd(transaction.payments)
      assert payment["method_details"]["type"] == "wire_transfer"

      assert transaction.import_meta["external_id"] == "legacy_enterprise_txn_123"
    end

    test "handles include parameters", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/transactions/txn_123", fn conn ->
        query_params = URI.decode_query(conn.query_string)
        assert query_params["include"] == "customer,address,business,discount,adjustments"

        Plug.Conn.resp(
          conn,
          200,
          Jason.encode!(%{
            "data" => %{
              "id" => "txn_123",
              "status" => "completed",
              "customer_id" => "ctm_123",
              "currency_code" => "USD",
              "origin" => "api",
              "collection_mode" => "automatic",
              "items" => [],
              "payments" => [],
              "created_at" => "2023-06-01T13:30:50.302Z",
              "updated_at" => "2023-06-01T13:30:50.302Z"
            }
          })
        )
      end)

      assert {:ok, _transaction} =
               Transaction.get(
                 "txn_123",
                 %{include: ["customer", "address", "business", "discount", "adjustments"]},
                 config: config
               )
    end

    test "handles not found error", %{bypass: bypass, config: config} do
      setup_error_response(bypass, "GET", "/transactions/txn_nonexistent", 404, %{
        "error" => %{
          "code" => "entity_not_found",
          "detail" => "Transaction not found"
        }
      })

      assert {:error, %Error{type: :not_found_error}} =
               Transaction.get("txn_nonexistent", %{}, config: config)
    end
  end

  describe "create/2" do
    setup do
      bypass = Bypass.open()
      config = create_bypass_config(bypass)
      {:ok, bypass: bypass, config: config}
    end

    test "creates transaction with required fields", %{bypass: bypass, config: config} do
      transaction_data = %{
        items: [
          %{price_id: "pri_01gsz4t5hdjse780zja8vvr7jg", quantity: 1}
        ],
        customer_id: "ctm_01gsz4t5hdjse780zja8vvr7jg"
      }

      create_response = %{
        "data" => %{
          "id" => "txn_01h987654321zyxwvutsrqponm",
          "status" => "draft",
          "customer_id" => "ctm_01gsz4t5hdjse780zja8vvr7jg",
          "address_id" => nil,
          "business_id" => nil,
          "custom_data" => nil,
          "currency_code" => "USD",
          "origin" => "api",
          "subscription_id" => nil,
          "invoice_id" => nil,
          "invoice_number" => nil,
          "collection_mode" => "automatic",
          "discount_id" => nil,
          "billing_details" => nil,
          "billing_period" => nil,
          "items" => [
            %{
              "price_id" => "pri_01gsz4t5hdjse780zja8vvr7jg",
              "quantity" => 1,
              "proration" => nil
            }
          ],
          "details" => nil,
          "payments" => [],
          "checkout" => %{
            "url" => "https://checkout.paddle.com/txn_01h987654321zyxwvutsrqponm"
          },
          "created_at" => "2023-06-01T13:30:50.302Z",
          "updated_at" => "2023-06-01T13:30:50.302Z",
          "billed_at" => nil,
          "import_meta" => nil
        }
      }

      Bypass.expect_once(bypass, "POST", "/transactions", fn conn ->
        assert_valid_paddle_headers(conn)

        {:ok, body, conn} = Plug.Conn.read_body(conn)

        # Handle empty body case
        parsed_body =
          case body do
            "" -> %{}
            _ -> Jason.decode!(body)
          end

        assert parsed_body["customer_id"] == "ctm_01gsz4t5hdjse780zja8vvr7jg"
        assert is_list(parsed_body["items"])
        assert length(parsed_body["items"]) == 1

        item = hd(parsed_body["items"])
        assert item["price_id"] == "pri_01gsz4t5hdjse780zja8vvr7jg"
        assert item["quantity"] == 1

        Plug.Conn.resp(conn, 201, Jason.encode!(create_response))
      end)

      assert {:ok, transaction} = Transaction.create(transaction_data, config: config)

      assert transaction.id == "txn_01h987654321zyxwvutsrqponm"
      assert transaction.status == "draft"
      assert transaction.customer_id == "ctm_01gsz4t5hdjse780zja8vvr7jg"
      assert transaction.currency_code == "USD"
      assert transaction.origin == "api"
      assert transaction.collection_mode == "automatic"
      assert length(transaction.items) == 1

      assert transaction.checkout["url"] ==
               "https://checkout.paddle.com/txn_01h987654321zyxwvutsrqponm"
    end

    test "creates complex B2B transaction", %{bypass: bypass, config: config} do
      transaction_data = %{
        items: [
          %{price_id: "pri_software_license", quantity: 10},
          %{price_id: "pri_support_package", quantity: 1}
        ],
        customer_id: "ctm_enterprise",
        address_id: "add_billing_123",
        business_id: "biz_company_456",
        collection_mode: "manual",
        discount_id: "dsc_enterprise_discount",
        billing_details: %{
          enable_checkout: false,
          purchase_order_number: "PO-2024-001",
          additional_information: "Net-30 payment terms",
          payment_terms: %{interval: "month", frequency: 1}
        },
        custom_data: %{
          contract_id: "CTR-2024-001",
          sales_rep: "john.doe@company.com"
        }
      }

      create_response = %{
        "data" => %{
          "id" => "txn_enterprise_complex",
          "status" => "draft",
          "customer_id" => "ctm_enterprise",
          "address_id" => "add_billing_123",
          "business_id" => "biz_company_456",
          "custom_data" => %{
            "contract_id" => "CTR-2024-001",
            "sales_rep" => "john.doe@company.com"
          },
          "currency_code" => "USD",
          "origin" => "api",
          "collection_mode" => "manual",
          "discount_id" => "dsc_enterprise_discount",
          "billing_details" => %{
            "enable_checkout" => false,
            "purchase_order_number" => "PO-2024-001",
            "additional_information" => "Net-30 payment terms",
            "payment_terms" => %{
              "interval" => "month",
              "frequency" => 1
            }
          },
          "items" => [
            %{
              "price_id" => "pri_software_license",
              "quantity" => 10,
              "proration" => nil
            },
            %{
              "price_id" => "pri_support_package",
              "quantity" => 1,
              "proration" => nil
            }
          ],
          "payments" => [],
          "created_at" => "2023-06-01T13:30:50.302Z",
          "updated_at" => "2023-06-01T13:30:50.302Z"
        }
      }

      Bypass.expect_once(bypass, "POST", "/transactions", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)

        # Handle empty body case
        parsed_body =
          case body do
            "" -> %{}
            _ -> Jason.decode!(body)
          end

        assert parsed_body["customer_id"] == "ctm_enterprise"
        assert parsed_body["address_id"] == "add_billing_123"
        assert parsed_body["business_id"] == "biz_company_456"
        assert parsed_body["collection_mode"] == "manual"
        assert parsed_body["discount_id"] == "dsc_enterprise_discount"

        assert is_map(parsed_body["billing_details"])
        assert parsed_body["billing_details"]["purchase_order_number"] == "PO-2024-001"

        assert is_map(parsed_body["custom_data"])
        assert parsed_body["custom_data"]["contract_id"] == "CTR-2024-001"

        assert length(parsed_body["items"]) == 2

        Plug.Conn.resp(conn, 201, Jason.encode!(create_response))
      end)

      assert {:ok, transaction} = Transaction.create(transaction_data, config: config)

      assert transaction.id == "txn_enterprise_complex"
      assert transaction.collection_mode == "manual"
      assert transaction.discount_id == "dsc_enterprise_discount"
      assert transaction.billing_details["purchase_order_number"] == "PO-2024-001"
      assert transaction.custom_data["contract_id"] == "CTR-2024-001"
      assert length(transaction.items) == 2
    end

    test "creates transaction with proration", %{bypass: bypass, config: config} do
      transaction_data = %{
        items: [
          %{
            price_id: "pri_monthly_plan",
            quantity: 1,
            proration: %{
              rate: "0.5",
              billing_period: %{
                starts_at: "2024-01-15T00:00:00Z",
                ends_at: "2024-02-01T00:00:00Z"
              }
            }
          }
        ],
        customer_id: "ctm_123",
        billing_period: %{
          starts_at: "2024-01-01T00:00:00Z",
          ends_at: "2024-02-01T00:00:00Z"
        }
      }

      create_response = %{
        "data" => %{
          "id" => "txn_prorated",
          "status" => "draft",
          "customer_id" => "ctm_123",
          "currency_code" => "USD",
          "origin" => "api",
          "billing_period" => %{
            "starts_at" => "2024-01-01T00:00:00Z",
            "ends_at" => "2024-02-01T00:00:00Z"
          },
          "items" => [
            %{
              "price_id" => "pri_monthly_plan",
              "quantity" => 1,
              "proration" => %{
                "rate" => "0.5",
                "billing_period" => %{
                  "starts_at" => "2024-01-15T00:00:00Z",
                  "ends_at" => "2024-02-01T00:00:00Z"
                }
              }
            }
          ],
          "payments" => [],
          "created_at" => "2023-06-01T13:30:50.302Z",
          "updated_at" => "2023-06-01T13:30:50.302Z"
        }
      }

      Bypass.expect_once(bypass, "POST", "/transactions", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)

        # Handle empty body case
        parsed_body =
          case body do
            "" -> %{}
            _ -> Jason.decode!(body)
          end

        assert is_map(parsed_body["billing_period"])
        assert parsed_body["billing_period"]["starts_at"] == "2024-01-01T00:00:00Z"

        item = hd(parsed_body["items"])
        assert is_map(item["proration"])
        assert item["proration"]["rate"] == "0.5"

        Plug.Conn.resp(conn, 201, Jason.encode!(create_response))
      end)

      assert {:ok, transaction} = Transaction.create(transaction_data, config: config)

      assert transaction.id == "txn_prorated"
      assert transaction.billing_period["starts_at"] == "2024-01-01T00:00:00Z"

      item = hd(transaction.items)
      assert item["proration"]["rate"] == "0.5"
    end

    test "handles validation errors", %{bypass: bypass, config: config} do
      setup_error_response(bypass, "POST", "/transactions", 400, %{
        "errors" => [
          %{
            "field" => "items",
            "code" => "required",
            "detail" => "Items are required"
          },
          %{
            "field" => "items[0].price_id",
            "code" => "invalid",
            "detail" => "Price ID must be valid"
          }
        ]
      })

      assert {:error, %Error{type: :validation_error}} =
               Transaction.create(%{customer_id: "ctm_123"}, config: config)
    end
  end

  describe "update/3" do
    setup do
      bypass = Bypass.open()
      config = create_bypass_config(bypass)
      {:ok, bypass: bypass, config: config}
    end

    test "updates draft transaction", %{bypass: bypass, config: config} do
      update_params = %{
        collection_mode: "manual",
        billing_details: %{
          purchase_order_number: "PO-UPDATED-2024"
        },
        custom_data: %{
          updated_by: "admin@company.com",
          update_reason: "Customer request"
        }
      }

      update_response = %{
        "data" => %{
          "id" => "txn_01gsz4t5hdjse780zja8vvr7jg",
          "status" => "draft",
          "customer_id" => "ctm_123",
          "currency_code" => "USD",
          "origin" => "api",
          "created_at" => "2023-06-01T13:30:50.302Z",
          "updated_at" => "2024-01-15T11:00:00.000Z",
          "collection_mode" => "manual",
          "billing_details" => %{
            "purchase_order_number" => "PO-UPDATED-2024"
          },
          "custom_data" => %{
            "updated_by" => "admin@company.com",
            "update_reason" => "Customer request"
          },
          "items" => [],
          "payments" => []
        }
      }

      Bypass.expect_once(
        bypass,
        "PATCH",
        "/transactions/txn_01gsz4t5hdjse780zja8vvr7jg",
        fn conn ->
          assert_valid_paddle_headers(conn)

          {:ok, body, conn} = Plug.Conn.read_body(conn)

          # Handle empty body case
          parsed_body =
            case body do
              "" -> %{}
              _ -> Jason.decode!(body)
            end

          assert parsed_body["collection_mode"] == "manual"
          assert is_map(parsed_body["billing_details"])
          assert parsed_body["billing_details"]["purchase_order_number"] == "PO-UPDATED-2024"
          assert is_map(parsed_body["custom_data"])
          assert parsed_body["custom_data"]["updated_by"] == "admin@company.com"

          Plug.Conn.resp(conn, 200, Jason.encode!(update_response))
        end
      )

      assert {:ok, transaction} =
               Transaction.update("txn_01gsz4t5hdjse780zja8vvr7jg", update_params, config: config)

      assert transaction.collection_mode == "manual"
      assert transaction.billing_details["purchase_order_number"] == "PO-UPDATED-2024"
      assert transaction.custom_data["updated_by"] == "admin@company.com"
    end

    test "adds discount to draft transaction", %{bypass: bypass, config: config} do
      update_params = %{
        discount_id: "dsc_early_bird"
      }

      update_response = %{
        "data" => %{
          "id" => "txn_draft",
          "status" => "draft",
          "customer_id" => "ctm_123",
          "discount_id" => "dsc_early_bird",
          "items" => [],
          "payments" => [],
          "created_at" => "2023-06-01T13:30:50.302Z",
          "updated_at" => "2024-01-15T11:00:00.000Z"
        }
      }

      Bypass.expect_once(bypass, "PATCH", "/transactions/txn_draft", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)

        # Handle empty body case
        parsed_body =
          case body do
            "" -> %{}
            _ -> Jason.decode!(body)
          end

        assert parsed_body["discount_id"] == "dsc_early_bird"

        Plug.Conn.resp(conn, 200, Jason.encode!(update_response))
      end)

      assert {:ok, transaction} = Transaction.update("txn_draft", update_params, config: config)
      assert transaction.discount_id == "dsc_early_bird"
    end

    test "handles not found error", %{bypass: bypass, config: config} do
      setup_error_response(bypass, "PATCH", "/transactions/txn_nonexistent", 404, %{
        "error" => %{
          "code" => "entity_not_found",
          "detail" => "Transaction not found"
        }
      })

      assert {:error, %Error{type: :not_found_error}} =
               Transaction.update("txn_nonexistent", %{collection_mode: "manual"}, config: config)
    end

    test "handles immutable transaction error", %{bypass: bypass, config: config} do
      setup_error_response(bypass, "PATCH", "/transactions/txn_completed", 409, %{
        "error" => %{
          "code" => "transaction_immutable",
          "detail" => "Completed transactions cannot be modified"
        }
      })

      assert {:error, %Error{type: :api_error}} =
               Transaction.update("txn_completed", %{collection_mode: "manual"}, config: config)
    end
  end

  describe "preview/2" do
    setup do
      bypass = Bypass.open()
      config = create_bypass_config(bypass)
      {:ok, bypass: bypass, config: config}
    end

    test "previews simple transaction", %{bypass: bypass, config: config} do
      preview_params = %{
        items: [
          %{price_id: "pri_123", quantity: 2}
        ],
        customer_id: "ctm_456"
      }

      preview_response = %{
        "data" => %{
          "totals" => %{
            "subtotal" => "4800",
            "discount" => "0",
            "tax" => "480",
            "total" => "5280",
            "credit" => "0",
            "balance" => "5280",
            "grand_total" => "5280",
            "fee" => "158",
            "earnings" => "5122",
            "currency_code" => "USD"
          },
          "tax_rates_used" => [
            %{
              "tax_rate" => "0.10",
              "totals" => %{
                "subtotal" => "4800",
                "tax" => "480",
                "total" => "5280"
              }
            }
          ],
          "line_items" => [
            %{
              "price_id" => "pri_123",
              "quantity" => 2,
              "totals" => %{
                "subtotal" => "4800",
                "tax" => "480",
                "total" => "5280"
              }
            }
          ]
        }
      }

      Bypass.expect_once(bypass, "POST", "/transactions/preview", fn conn ->
        assert_valid_paddle_headers(conn)

        {:ok, body, conn} = Plug.Conn.read_body(conn)

        # Handle empty body case
        parsed_body =
          case body do
            "" -> %{}
            _ -> Jason.decode!(body)
          end

        assert parsed_body["customer_id"] == "ctm_456"
        assert length(parsed_body["items"]) == 1

        item = hd(parsed_body["items"])
        assert item["price_id"] == "pri_123"
        assert item["quantity"] == 2

        Plug.Conn.resp(conn, 200, Jason.encode!(preview_response))
      end)

      assert {:ok, preview} = Transaction.preview(preview_params, config: config)

      assert preview["totals"]["grand_total"] == "5280"
      assert preview["totals"]["tax"] == "480"
      assert preview["totals"]["currency_code"] == "USD"
      assert length(preview["tax_rates_used"]) == 1
      assert length(preview["line_items"]) == 1
    end

    test "previews with discount and address", %{bypass: bypass, config: config} do
      preview_params = %{
        items: [%{price_id: "pri_annual_plan", quantity: 1}],
        customer_id: "ctm_123",
        address_id: "add_billing_456",
        discount_id: "dsc_new_customer"
      }

      preview_response = %{
        "data" => %{
          "totals" => %{
            "subtotal" => "12000",
            "discount" => "1200",
            "tax" => "1080",
            "total" => "11880",
            "grand_total" => "11880",
            "currency_code" => "USD"
          },
          "tax_rates_used" => [],
          "line_items" => []
        }
      }

      Bypass.expect_once(bypass, "POST", "/transactions/preview", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)

        # Handle empty body case
        parsed_body =
          case body do
            "" -> %{}
            _ -> Jason.decode!(body)
          end

        assert parsed_body["customer_id"] == "ctm_123"
        assert parsed_body["address_id"] == "add_billing_456"
        assert parsed_body["discount_id"] == "dsc_new_customer"

        Plug.Conn.resp(conn, 200, Jason.encode!(preview_response))
      end)

      assert {:ok, preview} = Transaction.preview(preview_params, config: config)
      assert preview["totals"]["discount"] == "1200"
      assert preview["totals"]["grand_total"] == "11880"
    end

    test "handles validation errors", %{bypass: bypass, config: config} do
      setup_error_response(bypass, "POST", "/transactions/preview", 400, %{
        "errors" => [
          %{
            "field" => "items",
            "code" => "required",
            "detail" => "Items are required for preview"
          }
        ]
      })

      assert {:error, %Error{type: :validation_error}} =
               Transaction.preview(%{customer_id: "ctm_123"}, config: config)
    end
  end

  describe "invoice/2" do
    setup do
      bypass = Bypass.open()
      config = create_bypass_config(bypass)
      {:ok, bypass: bypass, config: config}
    end

    test "invoices completed transaction", %{bypass: bypass, config: config} do
      invoice_response = %{
        "data" => %{
          "id" => "txn_123",
          "status" => "completed",
          "customer_id" => "ctm_456",
          "currency_code" => "USD",
          "origin" => "api",
          "invoice_id" => "inv_456",
          "invoice_number" => "INV-2024-001",
          "collection_mode" => "automatic",
          "items" => [],
          "payments" => [],
          "created_at" => "2023-06-01T13:30:50.302Z",
          "updated_at" => "2024-01-15T10:30:00.000Z"
        }
      }

      Bypass.expect_once(bypass, "POST", "/transactions/txn_123/invoice", fn conn ->
        assert_valid_paddle_headers(conn)

        {:ok, body, conn} = Plug.Conn.read_body(conn)

        # Handle empty body case
        parsed_body =
          case body do
            "" -> %{}
            _ -> Jason.decode!(body)
          end

        # Should be empty body for invoice creation
        assert parsed_body == %{}

        Plug.Conn.resp(conn, 200, Jason.encode!(invoice_response))
      end)

      assert {:ok, transaction} = Transaction.invoice("txn_123", config: config)
      assert transaction.id == "txn_123"
      assert transaction.invoice_id == "inv_456"
      assert transaction.invoice_number == "INV-2024-001"
    end

    test "handles draft transaction error", %{bypass: bypass, config: config} do
      setup_error_response(bypass, "POST", "/transactions/txn_draft/invoice", 400, %{
        "error" => %{
          "code" => "transaction_not_completed",
          "detail" => "Only completed transactions can be invoiced"
        }
      })

      assert {:error, %Error{type: :api_error}} =
               Transaction.invoice("txn_draft", config: config)
    end
  end

  describe "get_invoice/2" do
    setup do
      bypass = Bypass.open()
      config = create_bypass_config(bypass)
      {:ok, bypass: bypass, config: config}
    end

    test "returns invoice details", %{bypass: bypass, config: config} do
      invoice_response = %{
        "data" => %{
          "invoice_id" => "inv_456",
          "invoice_number" => "INV-2024-001",
          "status" => "issued",
          "totals" => %{
            "subtotal" => "2400",
            "tax" => "240",
            "total" => "2640",
            "currency_code" => "USD"
          },
          "created_at" => "2024-01-15T10:30:00.000Z"
        }
      }

      Bypass.expect_once(bypass, "GET", "/transactions/txn_123/invoice", fn conn ->
        assert_valid_paddle_headers(conn)
        Plug.Conn.resp(conn, 200, Jason.encode!(invoice_response))
      end)

      assert {:ok, invoice} = Transaction.get_invoice("txn_123", config: config)
      assert invoice["invoice_id"] == "inv_456"
      assert invoice["invoice_number"] == "INV-2024-001"
      assert invoice["totals"]["total"] == "2640"
    end

    test "handles not found error", %{bypass: bypass, config: config} do
      setup_error_response(bypass, "GET", "/transactions/txn_no_invoice/invoice", 404, %{
        "error" => %{
          "code" => "entity_not_found",
          "detail" => "Invoice not found"
        }
      })

      assert {:error, %Error{type: :not_found_error}} =
               Transaction.get_invoice("txn_no_invoice", config: config)
    end
  end

  describe "get_pdf/2" do
    setup do
      bypass = Bypass.open()
      config = create_bypass_config(bypass)
      {:ok, bypass: bypass, config: config}
    end

    test "returns transaction PDF", %{bypass: bypass, config: config} do
      pdf_data = <<"%PDF-1.4\n1 0 obj\n<<\n/Type /Catalog\n/Pages 2 0 R\n>>\nendobj\n">>

      Bypass.expect_once(bypass, "GET", "/transactions/txn_123/pdf", fn conn ->
        assert_valid_paddle_headers(conn)

        conn
        |> Plug.Conn.put_resp_content_type("application/pdf")
        |> Plug.Conn.resp(200, pdf_data)
      end)

      assert {:ok, ^pdf_data} = Transaction.get_pdf("txn_123", config: config)
    end

    test "handles draft transaction error", %{bypass: bypass, config: config} do
      setup_error_response(bypass, "GET", "/transactions/txn_draft/pdf", 400, %{
        "error" => %{
          "code" => "transaction_not_billed",
          "detail" => "PDF not available for draft transactions"
        }
      })

      assert {:error, %Error{type: :api_error}} =
               Transaction.get_pdf("txn_draft", config: config)
    end
  end

  describe "list_for_customer/3" do
    setup do
      bypass = Bypass.open()
      config = create_bypass_config(bypass)
      {:ok, bypass: bypass, config: config}
    end

    test "lists completed transactions for customer", %{bypass: bypass, config: config} do
      customer_txns_response = %{
        "data" => [
          %{
            "id" => "txn_customer_1",
            "status" => "completed",
            "customer_id" => "ctm_123",
            "currency_code" => "USD",
            "origin" => "api",
            "items" => [],
            "payments" => [],
            "created_at" => "2023-06-01T13:30:50.302Z",
            "updated_at" => "2023-06-01T13:30:50.302Z"
          }
        ]
      }

      Bypass.expect_once(bypass, "GET", "/transactions", fn conn ->
        query_params = URI.decode_query(conn.query_string)
        assert query_params["customer_id"] == "ctm_123"
        assert query_params["status"] == "completed"

        Plug.Conn.resp(conn, 200, Jason.encode!(customer_txns_response))
      end)

      assert {:ok, transactions} =
               Transaction.list_for_customer("ctm_123", ["completed"], config: config)

      assert length(transactions) == 1
      assert hd(transactions).customer_id == "ctm_123"
    end

    test "lists multiple statuses for customer", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/transactions", fn conn ->
        query_params = URI.decode_query(conn.query_string)
        assert query_params["customer_id"] == "ctm_456"
        assert query_params["status"] == "completed,paid,billed"

        Plug.Conn.resp(conn, 200, Jason.encode!(%{"data" => []}))
      end)

      assert {:ok, []} =
               Transaction.list_for_customer("ctm_456", ["completed", "paid", "billed"],
                 config: config
               )
    end
  end

  describe "list_for_subscription/2" do
    setup do
      bypass = Bypass.open()
      config = create_bypass_config(bypass)
      {:ok, bypass: bypass, config: config}
    end

    test "lists transactions for subscription", %{bypass: bypass, config: config} do
      subscription_txns_response = %{
        "data" => [
          %{
            "id" => "txn_sub_1",
            "status" => "completed",
            "customer_id" => "ctm_123",
            "subscription_id" => "sub_789",
            "currency_code" => "USD",
            "origin" => "subscription_recurring",
            "items" => [],
            "payments" => [],
            "created_at" => "2023-06-01T13:30:50.302Z",
            "updated_at" => "2023-06-01T13:30:50.302Z"
          }
        ]
      }

      Bypass.expect_once(bypass, "GET", "/transactions", fn conn ->
        query_params = URI.decode_query(conn.query_string)
        assert query_params["subscription_id"] == "sub_789"

        Plug.Conn.resp(conn, 200, Jason.encode!(subscription_txns_response))
      end)

      assert {:ok, transactions} = Transaction.list_for_subscription("sub_789", config: config)
      assert length(transactions) == 1
      assert hd(transactions).subscription_id == "sub_789"
    end
  end

  describe "status check functions" do
    test "completed?/1 returns true for completed transactions" do
      completed_transaction = %Transaction{status: "completed"}
      draft_transaction = %Transaction{status: "draft"}

      assert Transaction.completed?(completed_transaction) == true
      assert Transaction.completed?(draft_transaction) == false
    end

    test "paid?/1 returns true for paid transactions" do
      paid_transaction = %Transaction{status: "paid"}
      draft_transaction = %Transaction{status: "draft"}

      assert Transaction.paid?(paid_transaction) == true
      assert Transaction.paid?(draft_transaction) == false
    end

    test "billed?/1 returns true for billed transactions" do
      billed_transaction = %Transaction{status: "billed"}
      draft_transaction = %Transaction{status: "draft"}

      assert Transaction.billed?(billed_transaction) == true
      assert Transaction.billed?(draft_transaction) == false
    end

    test "draft?/1 returns true for draft transactions" do
      draft_transaction = %Transaction{status: "draft"}
      completed_transaction = %Transaction{status: "completed"}

      assert Transaction.draft?(draft_transaction) == true
      assert Transaction.draft?(completed_transaction) == false
    end

    test "canceled?/1 returns true for canceled transactions" do
      canceled_transaction = %Transaction{status: "canceled"}
      completed_transaction = %Transaction{status: "completed"}

      assert Transaction.canceled?(canceled_transaction) == true
      assert Transaction.canceled?(completed_transaction) == false
    end

    test "past_due?/1 returns true for past due transactions" do
      past_due_transaction = %Transaction{status: "past_due"}
      completed_transaction = %Transaction{status: "completed"}

      assert Transaction.past_due?(past_due_transaction) == true
      assert Transaction.past_due?(completed_transaction) == false
    end
  end
end
