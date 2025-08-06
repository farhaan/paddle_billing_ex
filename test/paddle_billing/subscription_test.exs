defmodule PaddleBilling.SubscriptionTest do
  use ExUnit.Case, async: true
  import PaddleBilling.TestHelpers

  alias PaddleBilling.{Subscription, Error}

  describe "list/2" do
    setup do
      bypass = Bypass.open()
      config = create_bypass_config(bypass)
      {:ok, bypass: bypass, config: config}
    end

    test "returns list of subscriptions", %{bypass: bypass, config: config} do
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
            "custom_data" => %{
              "customer_tier" => "premium",
              "contract_id" => "CTR-2024-001"
            },
            "collection_mode" => "automatic",
            "billing_details" => %{
              "enable_checkout" => true,
              "purchase_order_number" => "PO-2024-001"
            },
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
                "tax" => "240",
                "total" => "2640",
                "currency_code" => "USD"
              }
            },
            "scheduled_change" => nil,
            "items" => [
              %{
                "status" => "active",
                "quantity" => 1,
                "price" => %{
                  "id" => "pri_01gsz4t5hdjse780zja8vvr7jg",
                  "description" => "Monthly Pro Plan"
                }
              }
            ],
            "discount" => nil,
            "import_meta" => nil
          },
          %{
            "id" => "sub_01h123456789abcdefghijklmn",
            "status" => "trialing",
            "customer_id" => "ctm_01h123456789abcdefghijklmn",
            "address_id" => nil,
            "business_id" => "biz_01gsz4t5hdjse780zja8vvr7jg",
            "currency_code" => "EUR",
            "created_at" => "2023-06-02T10:15:30.123Z",
            "updated_at" => "2023-06-02T10:15:30.123Z",
            "started_at" => nil,
            "first_billed_at" => nil,
            "next_billed_at" => "2023-07-02T10:15:30.123Z",
            "paused_at" => nil,
            "canceled_at" => nil,
            "custom_data" => nil,
            "collection_mode" => "manual",
            "billing_details" => nil,
            "current_billing_period" => nil,
            "billing_cycle" => %{
              "interval" => "year",
              "frequency" => 1
            },
            "recurring_transaction_details" => nil,
            "scheduled_change" => %{
              "action" => "update",
              "effective_at" => "2023-07-02T10:15:30.123Z",
              "items" => [
                %{
                  "price_id" => "pri_upgraded_plan",
                  "quantity" => 1
                }
              ]
            },
            "items" => [
              %{
                "status" => "trialing",
                "quantity" => 5,
                "price" => %{
                  "id" => "pri_enterprise_plan",
                  "description" => "Enterprise Plan"
                }
              }
            ],
            "discount" => %{
              "id" => "dsc_trial_discount",
              "description" => "Trial Discount"
            },
            "import_meta" => %{
              "external_id" => "legacy_sub_789",
              "source" => "migration_2023"
            }
          }
        ]
      }

      Bypass.expect_once(bypass, "GET", "/subscriptions", fn conn ->
        assert_valid_paddle_headers(conn)
        Plug.Conn.resp(conn, 200, Jason.encode!(subscriptions_response))
      end)

      assert {:ok, subscriptions} = Subscription.list(%{}, config: config)
      assert length(subscriptions) == 2

      [subscription1, subscription2] = subscriptions

      # Test first subscription (active monthly)
      assert subscription1.id == "sub_01gsz4t5hdjse780zja8vvr7jg"
      assert subscription1.status == "active"
      assert subscription1.customer_id == "ctm_01gsz4t5hdjse780zja8vvr7jg"
      assert subscription1.currency_code == "USD"
      assert subscription1.collection_mode == "automatic"
      assert subscription1.billing_cycle["interval"] == "month"
      assert subscription1.billing_cycle["frequency"] == 1
      assert subscription1.custom_data["customer_tier"] == "premium"
      assert subscription1.billing_details["purchase_order_number"] == "PO-2024-001"
      assert length(subscription1.items) == 1
      assert hd(subscription1.items)["quantity"] == 1

      # Test second subscription (trialing annual with scheduled change)
      assert subscription2.id == "sub_01h123456789abcdefghijklmn"
      assert subscription2.status == "trialing"
      assert subscription2.currency_code == "EUR"
      assert subscription2.collection_mode == "manual"
      assert subscription2.billing_cycle["interval"] == "year"
      assert subscription2.scheduled_change["action"] == "update"
      assert subscription2.discount["id"] == "dsc_trial_discount"
      assert subscription2.import_meta["external_id"] == "legacy_sub_789"
    end

    test "handles filtering parameters", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/subscriptions", fn conn ->
        query_params = URI.decode_query(conn.query_string)

        assert query_params["customer_id"] == "ctm_123,ctm_456"
        assert query_params["price_id"] == "pri_789"
        assert query_params["status"] == "active,trialing"
        assert query_params["collection_mode"] == "automatic"
        assert query_params["include"] == "customer,discount"
        assert query_params["per_page"] == "25"

        Plug.Conn.resp(conn, 200, Jason.encode!(%{"data" => []}))
      end)

      assert {:ok, []} =
               Subscription.list(
                 %{
                   customer_id: ["ctm_123", "ctm_456"],
                   price_id: ["pri_789"],
                   status: ["active", "trialing"],
                   collection_mode: ["automatic"],
                   include: ["customer", "discount"],
                   per_page: 25
                 },
                 config: config
               )
    end

    test "handles empty list", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/subscriptions", fn conn ->
        Plug.Conn.resp(conn, 200, Jason.encode!(%{"data" => []}))
      end)

      assert {:ok, []} = Subscription.list(%{}, config: config)
    end

    test "handles API errors", %{bypass: bypass, config: config} do
      setup_error_response(bypass, "GET", "/subscriptions", 401, %{
        "error" => %{
          "code" => "authentication_failed",
          "detail" => "Invalid API key"
        }
      })

      assert {:error, %Error{type: :authentication_error}} =
               Subscription.list(%{}, config: config)
    end
  end

  describe "get/3" do
    setup do
      bypass = Bypass.open()
      config = create_bypass_config(bypass)
      {:ok, bypass: bypass, config: config}
    end

    test "returns single subscription", %{bypass: bypass, config: config} do
      subscription_response = %{
        "data" => %{
          "id" => "sub_01gsz4t5hdjse780zja8vvr7jg",
          "status" => "active",
          "customer_id" => "ctm_01gsz4t5hdjse780zja8vvr7jg",
          "address_id" => "add_01gsz4t5hdjse780zja8vvr7jg",
          "business_id" => nil,
          "currency_code" => "USD",
          "created_at" => "2023-06-01T13:30:50.302Z",
          "updated_at" => "2023-06-01T14:15:25.123Z",
          "started_at" => "2023-06-01T13:30:50.302Z",
          "first_billed_at" => "2023-06-01T13:30:50.302Z",
          "next_billed_at" => "2023-07-01T13:30:50.302Z",
          "paused_at" => nil,
          "canceled_at" => nil,
          "custom_data" => %{
            "account_manager" => "Sarah Wilson",
            "contract_type" => "enterprise",
            "renewal_priority" => "high"
          },
          "collection_mode" => "automatic",
          "billing_details" => %{
            "enable_checkout" => false,
            "purchase_order_number" => "PO-ENT-2024-001",
            "additional_information" => "Net-30 payment terms",
            "payment_terms" => %{
              "interval" => "month",
              "frequency" => 1
            }
          },
          "current_billing_period" => %{
            "starts_at" => "2023-06-01T13:30:50.302Z",
            "ends_at" => "2023-07-01T13:30:50.302Z"
          },
          "billing_cycle" => %{
            "interval" => "month",
            "frequency" => 1
          },
          "recurring_transaction_details" => %{
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
              "currency_code" => "USD"
            }
          },
          "scheduled_change" => nil,
          "items" => [
            %{
              "status" => "active",
              "quantity" => 3,
              "recurring" => true,
              "created_at" => "2023-06-01T13:30:50.302Z",
              "updated_at" => "2023-06-01T13:30:50.302Z",
              "previously_billed_at" => "2023-06-01T13:30:50.302Z",
              "next_billed_at" => "2023-07-01T13:30:50.302Z",
              "trial_dates" => nil,
              "price" => %{
                "id" => "pri_01gsz4t5hdjse780zja8vvr7jg",
                "description" => "Pro Plan - Monthly",
                "type" => "standard",
                "billing_cycle" => %{
                  "interval" => "month",
                  "frequency" => 1
                },
                "unit_price" => %{
                  "amount" => "800",
                  "currency_code" => "USD"
                }
              }
            }
          ],
          "discount" => nil,
          "import_meta" => %{
            "external_id" => "legacy_subscription_456",
            "source" => "migration_2023",
            "imported_at" => "2023-05-15T08:00:00.000Z"
          }
        }
      }

      Bypass.expect_once(
        bypass,
        "GET",
        "/subscriptions/sub_01gsz4t5hdjse780zja8vvr7jg",
        fn conn ->
          assert_valid_paddle_headers(conn)
          Plug.Conn.resp(conn, 200, Jason.encode!(subscription_response))
        end
      )

      assert {:ok, subscription} =
               Subscription.get("sub_01gsz4t5hdjse780zja8vvr7jg", %{}, config: config)

      assert subscription.id == "sub_01gsz4t5hdjse780zja8vvr7jg"
      assert subscription.status == "active"
      assert subscription.customer_id == "ctm_01gsz4t5hdjse780zja8vvr7jg"
      assert subscription.currency_code == "USD"
      assert subscription.collection_mode == "automatic"
      assert subscription.custom_data["account_manager"] == "Sarah Wilson"
      assert subscription.billing_details["purchase_order_number"] == "PO-ENT-2024-001"
      assert subscription.billing_details["payment_terms"]["interval"] == "month"
      assert subscription.recurring_transaction_details["totals"]["grand_total"] == "2640"
      assert length(subscription.items) == 1

      item = hd(subscription.items)
      assert item["quantity"] == 3
      assert item["price"]["id"] == "pri_01gsz4t5hdjse780zja8vvr7jg"
      assert item["price"]["unit_price"]["amount"] == "800"

      assert subscription.import_meta["external_id"] == "legacy_subscription_456"
    end

    test "handles include parameters", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/subscriptions/sub_123", fn conn ->
        query_params = URI.decode_query(conn.query_string)
        assert query_params["include"] == "customer,address,business,discount"

        Plug.Conn.resp(
          conn,
          200,
          Jason.encode!(%{
            "data" => %{
              "id" => "sub_123",
              "status" => "active",
              "customer_id" => "ctm_123",
              "currency_code" => "USD",
              "created_at" => "2023-06-01T13:30:50.302Z",
              "updated_at" => "2023-06-01T13:30:50.302Z",
              "collection_mode" => "automatic",
              "items" => []
            }
          })
        )
      end)

      assert {:ok, _subscription} =
               Subscription.get(
                 "sub_123",
                 %{include: ["customer", "address", "business", "discount"]},
                 config: config
               )
    end

    test "handles not found error", %{bypass: bypass, config: config} do
      setup_error_response(bypass, "GET", "/subscriptions/sub_nonexistent", 404, %{
        "error" => %{
          "code" => "entity_not_found",
          "detail" => "Subscription not found"
        }
      })

      assert {:error, %Error{type: :not_found_error}} =
               Subscription.get("sub_nonexistent", %{}, config: config)
    end
  end

  describe "create/2" do
    setup do
      bypass = Bypass.open()
      config = create_bypass_config(bypass)
      {:ok, bypass: bypass, config: config}
    end

    test "creates subscription with required fields", %{bypass: bypass, config: config} do
      subscription_data = %{
        items: [
          %{price_id: "pri_01gsz4t5hdjse780zja8vvr7jg", quantity: 1}
        ],
        customer_id: "ctm_01gsz4t5hdjse780zja8vvr7jg"
      }

      create_response = %{
        "data" => %{
          "id" => "sub_01h987654321zyxwvutsrqponm",
          "status" => "active",
          "customer_id" => "ctm_01gsz4t5hdjse780zja8vvr7jg",
          "address_id" => nil,
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
          "recurring_transaction_details" => nil,
          "scheduled_change" => nil,
          "items" => [
            %{
              "status" => "active",
              "quantity" => 1,
              "price" => %{
                "id" => "pri_01gsz4t5hdjse780zja8vvr7jg",
                "description" => "Monthly Plan"
              }
            }
          ],
          "discount" => nil,
          "import_meta" => nil
        }
      }

      Bypass.expect_once(bypass, "POST", "/subscriptions", fn conn ->
        assert_valid_paddle_headers(conn)

        {:ok, body, conn} = Plug.Conn.read_body(conn)
        parsed_body = Jason.decode!(body)

        assert parsed_body["customer_id"] == "ctm_01gsz4t5hdjse780zja8vvr7jg"
        assert is_list(parsed_body["items"])
        assert length(parsed_body["items"]) == 1

        item = hd(parsed_body["items"])
        assert item["price_id"] == "pri_01gsz4t5hdjse780zja8vvr7jg"
        assert item["quantity"] == 1

        Plug.Conn.resp(conn, 201, Jason.encode!(create_response))
      end)

      assert {:ok, subscription} = Subscription.create(subscription_data, config: config)

      assert subscription.id == "sub_01h987654321zyxwvutsrqponm"
      assert subscription.status == "active"
      assert subscription.customer_id == "ctm_01gsz4t5hdjse780zja8vvr7jg"
      assert subscription.currency_code == "USD"
      assert subscription.collection_mode == "automatic"
      assert length(subscription.items) == 1
    end

    test "creates subscription with complex configuration", %{bypass: bypass, config: config} do
      subscription_data = %{
        items: [
          %{price_id: "pri_base_plan", quantity: 1},
          %{price_id: "pri_addon_users", quantity: 5}
        ],
        customer_id: "ctm_enterprise",
        address_id: "add_billing_123",
        business_id: "biz_company_456",
        currency_code: "EUR",
        collection_mode: "manual",
        billing_details: %{
          enable_checkout: false,
          purchase_order_number: "PO-2024-001",
          additional_information: "Net-30 payment terms",
          payment_terms: %{
            interval: "month",
            frequency: 1
          }
        },
        billing_cycle: %{
          interval: "year",
          frequency: 1
        },
        scheduled_change: %{
          action: "update",
          effective_at: "2024-02-01T00:00:00Z",
          items: [
            %{price_id: "pri_upgraded_plan", quantity: 1}
          ]
        },
        proration_billing_mode: "prorated_immediately",
        custom_data: %{
          contract_id: "CTR-2024-001",
          account_manager: "jane.doe@company.com",
          renewal_date: "2024-12-31"
        }
      }

      create_response = %{
        "data" => %{
          "id" => "sub_enterprise_complex",
          "status" => "active",
          "customer_id" => "ctm_enterprise",
          "address_id" => "add_billing_123",
          "business_id" => "biz_company_456",
          "currency_code" => "EUR",
          "created_at" => "2023-06-01T13:30:50.302Z",
          "updated_at" => "2023-06-01T13:30:50.302Z",
          "collection_mode" => "manual",
          "billing_details" => %{
            "enable_checkout" => false,
            "purchase_order_number" => "PO-2024-001",
            "additional_information" => "Net-30 payment terms",
            "payment_terms" => %{
              "interval" => "month",
              "frequency" => 1
            }
          },
          "billing_cycle" => %{
            "interval" => "year",
            "frequency" => 1
          },
          "scheduled_change" => %{
            "action" => "update",
            "effective_at" => "2024-02-01T00:00:00Z",
            "items" => [
              %{
                "price_id" => "pri_upgraded_plan",
                "quantity" => 1
              }
            ]
          },
          "custom_data" => %{
            "contract_id" => "CTR-2024-001",
            "account_manager" => "jane.doe@company.com",
            "renewal_date" => "2024-12-31"
          },
          "items" => [
            %{
              "status" => "active",
              "quantity" => 1,
              "price" => %{"id" => "pri_base_plan"}
            },
            %{
              "status" => "active",
              "quantity" => 5,
              "price" => %{"id" => "pri_addon_users"}
            }
          ]
        }
      }

      Bypass.expect_once(bypass, "POST", "/subscriptions", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        parsed_body = Jason.decode!(body)

        assert parsed_body["customer_id"] == "ctm_enterprise"
        assert parsed_body["address_id"] == "add_billing_123"
        assert parsed_body["business_id"] == "biz_company_456"
        assert parsed_body["currency_code"] == "EUR"
        assert parsed_body["collection_mode"] == "manual"
        assert parsed_body["proration_billing_mode"] == "prorated_immediately"

        assert is_map(parsed_body["billing_details"])
        assert parsed_body["billing_details"]["purchase_order_number"] == "PO-2024-001"

        assert is_map(parsed_body["billing_cycle"])
        assert parsed_body["billing_cycle"]["interval"] == "year"

        assert is_map(parsed_body["scheduled_change"])
        assert parsed_body["scheduled_change"]["action"] == "update"

        assert is_map(parsed_body["custom_data"])
        assert parsed_body["custom_data"]["contract_id"] == "CTR-2024-001"

        assert length(parsed_body["items"]) == 2

        Plug.Conn.resp(conn, 201, Jason.encode!(create_response))
      end)

      assert {:ok, subscription} = Subscription.create(subscription_data, config: config)

      assert subscription.id == "sub_enterprise_complex"
      assert subscription.currency_code == "EUR"
      assert subscription.collection_mode == "manual"
      assert subscription.billing_details["purchase_order_number"] == "PO-2024-001"
      assert subscription.billing_cycle["interval"] == "year"
      assert subscription.scheduled_change["action"] == "update"
      assert subscription.custom_data["contract_id"] == "CTR-2024-001"
      assert length(subscription.items) == 2
    end

    test "handles validation errors", %{bypass: bypass, config: config} do
      setup_error_response(bypass, "POST", "/subscriptions", 400, %{
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
               Subscription.create(%{customer_id: "ctm_123"}, config: config)
    end
  end

  describe "update/3" do
    setup do
      bypass = Bypass.open()
      config = create_bypass_config(bypass)
      {:ok, bypass: bypass, config: config}
    end

    test "updates subscription fields", %{bypass: bypass, config: config} do
      update_params = %{
        collection_mode: "manual",
        billing_details: %{
          enable_checkout: false,
          purchase_order_number: "PO-UPDATED-2024",
          additional_information: "Updated payment terms"
        },
        custom_data: %{
          tier: "enterprise",
          renewal_date: "2024-12-31",
          account_manager: "new.manager@company.com"
        }
      }

      update_response = %{
        "data" => %{
          "id" => "sub_01gsz4t5hdjse780zja8vvr7jg",
          "status" => "active",
          "customer_id" => "ctm_01gsz4t5hdjse780zja8vvr7jg",
          "currency_code" => "USD",
          "created_at" => "2023-06-01T13:30:50.302Z",
          "updated_at" => "2024-01-15T11:00:00.000Z",
          "collection_mode" => "manual",
          "billing_details" => %{
            "enable_checkout" => false,
            "purchase_order_number" => "PO-UPDATED-2024",
            "additional_information" => "Updated payment terms"
          },
          "custom_data" => %{
            "tier" => "enterprise",
            "renewal_date" => "2024-12-31",
            "account_manager" => "new.manager@company.com"
          },
          "items" => []
        }
      }

      Bypass.expect_once(
        bypass,
        "PATCH",
        "/subscriptions/sub_01gsz4t5hdjse780zja8vvr7jg",
        fn conn ->
          assert_valid_paddle_headers(conn)

          {:ok, body, conn} = Plug.Conn.read_body(conn)
          parsed_body = Jason.decode!(body)

          assert parsed_body["collection_mode"] == "manual"
          assert is_map(parsed_body["billing_details"])
          assert parsed_body["billing_details"]["purchase_order_number"] == "PO-UPDATED-2024"
          assert is_map(parsed_body["custom_data"])
          assert parsed_body["custom_data"]["tier"] == "enterprise"

          Plug.Conn.resp(conn, 200, Jason.encode!(update_response))
        end
      )

      assert {:ok, subscription} =
               Subscription.update("sub_01gsz4t5hdjse780zja8vvr7jg", update_params,
                 config: config
               )

      assert subscription.collection_mode == "manual"
      assert subscription.billing_details["purchase_order_number"] == "PO-UPDATED-2024"
      assert subscription.custom_data["tier"] == "enterprise"
      assert subscription.custom_data["account_manager"] == "new.manager@company.com"
    end

    test "schedules future changes", %{bypass: bypass, config: config} do
      update_params = %{
        scheduled_change: %{
          action: "update",
          effective_at: "2024-03-01T00:00:00Z",
          items: [
            %{price_id: "pri_new_plan", quantity: 1}
          ]
        }
      }

      update_response = %{
        "data" => %{
          "id" => "sub_schedule_test",
          "status" => "active",
          "customer_id" => "ctm_123",
          "currency_code" => "USD",
          "updated_at" => "2024-01-15T11:00:00.000Z",
          "scheduled_change" => %{
            "action" => "update",
            "effective_at" => "2024-03-01T00:00:00Z",
            "items" => [
              %{
                "price_id" => "pri_new_plan",
                "quantity" => 1
              }
            ]
          },
          "items" => []
        }
      }

      Bypass.expect_once(bypass, "PATCH", "/subscriptions/sub_schedule_test", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        parsed_body = Jason.decode!(body)

        assert is_map(parsed_body["scheduled_change"])
        assert parsed_body["scheduled_change"]["action"] == "update"
        assert parsed_body["scheduled_change"]["effective_at"] == "2024-03-01T00:00:00Z"

        Plug.Conn.resp(conn, 200, Jason.encode!(update_response))
      end)

      assert {:ok, subscription} =
               Subscription.update("sub_schedule_test", update_params, config: config)

      assert subscription.scheduled_change["action"] == "update"
      assert subscription.scheduled_change["effective_at"] == "2024-03-01T00:00:00Z"
    end

    test "handles not found error", %{bypass: bypass, config: config} do
      setup_error_response(bypass, "PATCH", "/subscriptions/sub_nonexistent", 404, %{
        "error" => %{
          "code" => "entity_not_found",
          "detail" => "Subscription not found"
        }
      })

      assert {:error, %Error{type: :not_found_error}} =
               Subscription.update("sub_nonexistent", %{collection_mode: "manual"},
                 config: config
               )
    end
  end

  describe "activate/3" do
    setup do
      bypass = Bypass.open()
      config = create_bypass_config(bypass)
      {:ok, bypass: bypass, config: config}
    end

    test "activates subscription", %{bypass: bypass, config: config} do
      activate_response = %{
        "data" => %{
          "id" => "sub_01gsz4t5hdjse780zja8vvr7jg",
          "status" => "active",
          "customer_id" => "ctm_123",
          "currency_code" => "USD",
          "started_at" => "2024-01-15T10:30:00.000Z",
          "first_billed_at" => "2024-01-15T10:30:00.000Z",
          "updated_at" => "2024-01-15T10:30:00.000Z",
          "items" => []
        }
      }

      Bypass.expect_once(
        bypass,
        "POST",
        "/subscriptions/sub_01gsz4t5hdjse780zja8vvr7jg/activate",
        fn conn ->
          assert_valid_paddle_headers(conn)

          {:ok, body, conn} = Plug.Conn.read_body(conn)

          # Handle empty body case
          parsed_body =
            case body do
              "" -> %{}
              _ -> Jason.decode!(body)
            end

          # Default activation should have empty body or basic params
          assert is_map(parsed_body)

          Plug.Conn.resp(conn, 200, Jason.encode!(activate_response))
        end
      )

      assert {:ok, subscription} =
               Subscription.activate("sub_01gsz4t5hdjse780zja8vvr7jg", %{}, config: config)

      assert subscription.status == "active"
      assert subscription.started_at == "2024-01-15T10:30:00.000Z"
    end

    test "activates subscription with effective time", %{bypass: bypass, config: config} do
      activation_params = %{
        effective_from: "immediately",
        proration_billing_mode: "prorated_immediately"
      }

      activate_response = %{
        "data" => %{
          "id" => "sub_immediate_activate",
          "status" => "active",
          "customer_id" => "ctm_123",
          "started_at" => "2024-01-15T10:30:00.000Z",
          "items" => []
        }
      }

      Bypass.expect_once(
        bypass,
        "POST",
        "/subscriptions/sub_immediate_activate/activate",
        fn conn ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          parsed_body = Jason.decode!(body)

          assert parsed_body["effective_from"] == "immediately"
          assert parsed_body["proration_billing_mode"] == "prorated_immediately"

          Plug.Conn.resp(conn, 200, Jason.encode!(activate_response))
        end
      )

      assert {:ok, subscription} =
               Subscription.activate("sub_immediate_activate", activation_params, config: config)

      assert subscription.status == "active"
    end
  end

  describe "cancel/3" do
    setup do
      bypass = Bypass.open()
      config = create_bypass_config(bypass)
      {:ok, bypass: bypass, config: config}
    end

    test "cancels subscription at end of billing period", %{bypass: bypass, config: config} do
      cancel_response = %{
        "data" => %{
          "id" => "sub_01gsz4t5hdjse780zja8vvr7jg",
          "status" => "canceled",
          "customer_id" => "ctm_123",
          "currency_code" => "USD",
          "canceled_at" => "2023-07-01T13:30:50.302Z",
          "updated_at" => "2024-01-15T10:30:00.000Z",
          "items" => []
        }
      }

      Bypass.expect_once(
        bypass,
        "POST",
        "/subscriptions/sub_01gsz4t5hdjse780zja8vvr7jg/cancel",
        fn conn ->
          assert_valid_paddle_headers(conn)

          {:ok, body, conn} = Plug.Conn.read_body(conn)

          # Handle empty body case
          parsed_body =
            case body do
              "" -> %{}
              _ -> Jason.decode!(body)
            end

          # Default cancellation should have empty body
          assert is_map(parsed_body)

          Plug.Conn.resp(conn, 200, Jason.encode!(cancel_response))
        end
      )

      assert {:ok, subscription} =
               Subscription.cancel("sub_01gsz4t5hdjse780zja8vvr7jg", %{}, config: config)

      assert subscription.status == "canceled"
      assert subscription.canceled_at == "2023-07-01T13:30:50.302Z"
    end

    test "cancels subscription immediately with prorated refund", %{
      bypass: bypass,
      config: config
    } do
      cancel_params = %{
        effective_from: "immediately",
        proration_billing_mode: "prorated_immediately"
      }

      cancel_response = %{
        "data" => %{
          "id" => "sub_immediate_cancel",
          "status" => "canceled",
          "customer_id" => "ctm_123",
          "canceled_at" => "2024-01-15T10:30:00.000Z",
          "items" => []
        }
      }

      Bypass.expect_once(bypass, "POST", "/subscriptions/sub_immediate_cancel/cancel", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        parsed_body = Jason.decode!(body)

        assert parsed_body["effective_from"] == "immediately"
        assert parsed_body["proration_billing_mode"] == "prorated_immediately"

        Plug.Conn.resp(conn, 200, Jason.encode!(cancel_response))
      end)

      assert {:ok, subscription} =
               Subscription.cancel("sub_immediate_cancel", cancel_params, config: config)

      assert subscription.status == "canceled"
    end
  end

  describe "pause/3" do
    setup do
      bypass = Bypass.open()
      config = create_bypass_config(bypass)
      {:ok, bypass: bypass, config: config}
    end

    test "pauses subscription at end of billing period", %{bypass: bypass, config: config} do
      pause_response = %{
        "data" => %{
          "id" => "sub_01gsz4t5hdjse780zja8vvr7jg",
          "status" => "paused",
          "customer_id" => "ctm_123",
          "currency_code" => "USD",
          "paused_at" => "2024-01-15T10:30:00.000Z",
          "updated_at" => "2024-01-15T10:30:00.000Z",
          "items" => []
        }
      }

      Bypass.expect_once(
        bypass,
        "POST",
        "/subscriptions/sub_01gsz4t5hdjse780zja8vvr7jg/pause",
        fn conn ->
          assert_valid_paddle_headers(conn)
          Plug.Conn.resp(conn, 200, Jason.encode!(pause_response))
        end
      )

      assert {:ok, subscription} =
               Subscription.pause("sub_01gsz4t5hdjse780zja8vvr7jg", %{}, config: config)

      assert subscription.status == "paused"
      assert subscription.paused_at == "2024-01-15T10:30:00.000Z"
    end

    test "pauses subscription immediately with auto-resume", %{bypass: bypass, config: config} do
      pause_params = %{
        effective_from: "immediately",
        resume_at: "2024-04-01T00:00:00Z"
      }

      pause_response = %{
        "data" => %{
          "id" => "sub_auto_resume",
          "status" => "paused",
          "customer_id" => "ctm_123",
          "paused_at" => "2024-01-15T10:30:00.000Z",
          "scheduled_change" => %{
            "action" => "resume",
            "resume_at" => "2024-04-01T00:00:00Z"
          },
          "items" => []
        }
      }

      Bypass.expect_once(bypass, "POST", "/subscriptions/sub_auto_resume/pause", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        parsed_body = Jason.decode!(body)

        assert parsed_body["effective_from"] == "immediately"
        assert parsed_body["resume_at"] == "2024-04-01T00:00:00Z"

        Plug.Conn.resp(conn, 200, Jason.encode!(pause_response))
      end)

      assert {:ok, subscription} =
               Subscription.pause("sub_auto_resume", pause_params, config: config)

      assert subscription.status == "paused"
      assert subscription.scheduled_change["action"] == "resume"
    end
  end

  describe "resume/3" do
    setup do
      bypass = Bypass.open()
      config = create_bypass_config(bypass)
      {:ok, bypass: bypass, config: config}
    end

    test "resumes paused subscription immediately", %{bypass: bypass, config: config} do
      resume_response = %{
        "data" => %{
          "id" => "sub_01gsz4t5hdjse780zja8vvr7jg",
          "status" => "active",
          "customer_id" => "ctm_123",
          "currency_code" => "USD",
          "paused_at" => nil,
          "updated_at" => "2024-01-15T10:30:00.000Z",
          "items" => []
        }
      }

      Bypass.expect_once(
        bypass,
        "POST",
        "/subscriptions/sub_01gsz4t5hdjse780zja8vvr7jg/resume",
        fn conn ->
          assert_valid_paddle_headers(conn)
          Plug.Conn.resp(conn, 200, Jason.encode!(resume_response))
        end
      )

      assert {:ok, subscription} =
               Subscription.resume("sub_01gsz4t5hdjse780zja8vvr7jg", %{}, config: config)

      assert subscription.status == "active"
      assert subscription.paused_at == nil
    end

    test "resumes subscription at next billing period", %{bypass: bypass, config: config} do
      resume_params = %{
        effective_from: "next_billing_period"
      }

      resume_response = %{
        "data" => %{
          "id" => "sub_next_period_resume",
          "status" => "paused",
          "customer_id" => "ctm_123",
          "scheduled_change" => %{
            "action" => "resume",
            "effective_at" => "2024-02-01T00:00:00Z"
          },
          "items" => []
        }
      }

      Bypass.expect_once(
        bypass,
        "POST",
        "/subscriptions/sub_next_period_resume/resume",
        fn conn ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          parsed_body = Jason.decode!(body)

          assert parsed_body["effective_from"] == "next_billing_period"

          Plug.Conn.resp(conn, 200, Jason.encode!(resume_response))
        end
      )

      assert {:ok, subscription} =
               Subscription.resume("sub_next_period_resume", resume_params, config: config)

      assert subscription.scheduled_change["action"] == "resume"
    end
  end

  describe "list_for_customer/3" do
    setup do
      bypass = Bypass.open()
      config = create_bypass_config(bypass)
      {:ok, bypass: bypass, config: config}
    end

    test "lists active subscriptions for customer", %{bypass: bypass, config: config} do
      customer_subs_response = %{
        "data" => [
          %{
            "id" => "sub_customer_1",
            "status" => "active",
            "customer_id" => "ctm_123",
            "currency_code" => "USD",
            "items" => []
          }
        ]
      }

      Bypass.expect_once(bypass, "GET", "/subscriptions", fn conn ->
        query_params = URI.decode_query(conn.query_string)
        assert query_params["customer_id"] == "ctm_123"
        assert query_params["status"] == "active"

        Plug.Conn.resp(conn, 200, Jason.encode!(customer_subs_response))
      end)

      assert {:ok, subscriptions} =
               Subscription.list_for_customer("ctm_123", ["active"], config: config)

      assert length(subscriptions) == 1
      assert hd(subscriptions).customer_id == "ctm_123"
    end

    test "lists all statuses for customer", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/subscriptions", fn conn ->
        query_params = URI.decode_query(conn.query_string)
        assert query_params["customer_id"] == "ctm_456"
        assert query_params["status"] == "active,trialing,paused"

        Plug.Conn.resp(conn, 200, Jason.encode!(%{"data" => []}))
      end)

      assert {:ok, []} =
               Subscription.list_for_customer("ctm_456", ["active", "trialing", "paused"],
                 config: config
               )
    end
  end

  describe "list_for_price/2" do
    setup do
      bypass = Bypass.open()
      config = create_bypass_config(bypass)
      {:ok, bypass: bypass, config: config}
    end

    test "lists subscriptions for specific price", %{bypass: bypass, config: config} do
      price_subs_response = %{
        "data" => [
          %{
            "id" => "sub_price_1",
            "status" => "active",
            "customer_id" => "ctm_123",
            "items" => [
              %{
                "price" => %{"id" => "pri_789"}
              }
            ]
          }
        ]
      }

      Bypass.expect_once(bypass, "GET", "/subscriptions", fn conn ->
        query_params = URI.decode_query(conn.query_string)
        assert query_params["price_id"] == "pri_789"

        Plug.Conn.resp(conn, 200, Jason.encode!(price_subs_response))
      end)

      assert {:ok, subscriptions} = Subscription.list_for_price("pri_789", config: config)
      assert length(subscriptions) == 1
      assert hd(subscriptions).items |> hd() |> get_in(["price", "id"]) == "pri_789"
    end
  end

  describe "charge/3" do
    setup do
      bypass = Bypass.open()
      config = create_bypass_config(bypass)
      {:ok, bypass: bypass, config: config}
    end

    test "creates one-time charge for next billing period", %{bypass: bypass, config: config} do
      charge_params = %{
        items: [
          %{price_id: "pri_setup_fee", quantity: 1}
        ]
      }

      charge_response = %{
        "data" => %{
          "id" => "sub_01gsz4t5hdjse780zja8vvr7jg",
          "status" => "active",
          "customer_id" => "ctm_123",
          "currency_code" => "USD",
          "updated_at" => "2024-01-15T10:30:00.000Z",
          "items" => []
        }
      }

      Bypass.expect_once(
        bypass,
        "POST",
        "/subscriptions/sub_01gsz4t5hdjse780zja8vvr7jg/charge",
        fn conn ->
          assert_valid_paddle_headers(conn)

          {:ok, body, conn} = Plug.Conn.read_body(conn)
          parsed_body = Jason.decode!(body)

          assert is_list(parsed_body["items"])
          assert length(parsed_body["items"]) == 1
          assert hd(parsed_body["items"])["price_id"] == "pri_setup_fee"
          assert hd(parsed_body["items"])["quantity"] == 1

          Plug.Conn.resp(conn, 200, Jason.encode!(charge_response))
        end
      )

      assert {:ok, subscription} =
               Subscription.charge("sub_01gsz4t5hdjse780zja8vvr7jg", charge_params,
                 config: config
               )

      assert subscription.id == "sub_01gsz4t5hdjse780zja8vvr7jg"
    end

    test "creates immediate charge with failure handling", %{bypass: bypass, config: config} do
      charge_params = %{
        items: [
          %{price_id: "pri_addon", quantity: 2}
        ],
        effective_from: "immediately",
        on_payment_failure: "apply_change"
      }

      charge_response = %{
        "data" => %{
          "id" => "sub_immediate_charge",
          "status" => "active",
          "customer_id" => "ctm_456",
          "items" => []
        }
      }

      Bypass.expect_once(bypass, "POST", "/subscriptions/sub_immediate_charge/charge", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        parsed_body = Jason.decode!(body)

        assert parsed_body["effective_from"] == "immediately"
        assert parsed_body["on_payment_failure"] == "apply_change"
        assert length(parsed_body["items"]) == 1
        assert hd(parsed_body["items"])["quantity"] == 2

        Plug.Conn.resp(conn, 200, Jason.encode!(charge_response))
      end)

      assert {:ok, subscription} =
               Subscription.charge("sub_immediate_charge", charge_params, config: config)

      assert subscription.id == "sub_immediate_charge"
    end
  end

  describe "get_update_payment_method_transaction/2" do
    setup do
      bypass = Bypass.open()
      config = create_bypass_config(bypass)
      {:ok, bypass: bypass, config: config}
    end

    test "returns update payment method transaction", %{bypass: bypass, config: config} do
      transaction_response = %{
        "data" => %{
          "id" => "txn_update_payment_method",
          "status" => "completed",
          "customer_id" => "ctm_123",
          "currency_code" => "USD",
          "origin" => "subscription_update",
          "subscription_id" => "sub_123"
        }
      }

      Bypass.expect_once(
        bypass,
        "GET",
        "/subscriptions/sub_123/update-payment-method-transaction",
        fn conn ->
          assert_valid_paddle_headers(conn)
          Plug.Conn.resp(conn, 200, Jason.encode!(transaction_response))
        end
      )

      assert {:ok, transaction} =
               Subscription.get_update_payment_method_transaction("sub_123", config: config)

      assert transaction["id"] == "txn_update_payment_method"
      assert transaction["origin"] == "subscription_update"
    end

    test "handles not found error", %{bypass: bypass, config: config} do
      setup_error_response(
        bypass,
        "GET",
        "/subscriptions/sub_nonexistent/update-payment-method-transaction",
        404,
        %{
          "error" => %{
            "code" => "entity_not_found",
            "detail" => "Transaction not found"
          }
        }
      )

      assert {:error, %Error{type: :not_found_error}} =
               Subscription.get_update_payment_method_transaction("sub_nonexistent",
                 config: config
               )
    end
  end

  describe "preview/2" do
    setup do
      bypass = Bypass.open()
      config = create_bypass_config(bypass)
      {:ok, bypass: bypass, config: config}
    end

    test "previews subscription with basic items", %{bypass: bypass, config: config} do
      preview_params = %{
        items: [
          %{price_id: "pri_123", quantity: 1}
        ],
        customer_id: "ctm_456"
      }

      preview_response = %{
        "data" => %{
          "details" => %{
            "line_items" => [
              %{
                "price_id" => "pri_123",
                "quantity" => 1,
                "totals" => %{
                  "subtotal" => "1000",
                  "tax" => "100",
                  "total" => "1100"
                }
              }
            ],
            "totals" => %{
              "subtotal" => "1000",
              "tax" => "100",
              "total" => "1100",
              "currency_code" => "USD"
            }
          }
        }
      }

      Bypass.expect_once(bypass, "POST", "/subscriptions/preview", fn conn ->
        assert_valid_paddle_headers(conn)

        {:ok, body, conn} = Plug.Conn.read_body(conn)
        parsed_body = Jason.decode!(body)

        assert parsed_body["customer_id"] == "ctm_456"
        assert is_list(parsed_body["items"])
        assert length(parsed_body["items"]) == 1
        assert hd(parsed_body["items"])["price_id"] == "pri_123"

        Plug.Conn.resp(conn, 200, Jason.encode!(preview_response))
      end)

      assert {:ok, preview} = Subscription.preview(preview_params, config: config)
      assert preview["details"]["totals"]["total"] == "1100"
    end

    test "previews subscription with new customer and address", %{bypass: bypass, config: config} do
      preview_params = %{
        items: [%{price_id: "pri_123", quantity: 1}],
        customer: %{
          email: "customer@example.com",
          name: "John Doe"
        },
        address: %{
          country_code: "US",
          postal_code: "10001"
        },
        discount_id: "dsc_25percent"
      }

      preview_response = %{
        "data" => %{
          "details" => %{
            "totals" => %{
              "subtotal" => "1000",
              "discount" => "250",
              "tax" => "75",
              "total" => "825",
              "currency_code" => "USD"
            }
          }
        }
      }

      Bypass.expect_once(bypass, "POST", "/subscriptions/preview", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        parsed_body = Jason.decode!(body)

        assert parsed_body["customer"]["email"] == "customer@example.com"
        assert parsed_body["address"]["country_code"] == "US"
        assert parsed_body["discount_id"] == "dsc_25percent"

        Plug.Conn.resp(conn, 200, Jason.encode!(preview_response))
      end)

      assert {:ok, preview} = Subscription.preview(preview_params, config: config)
      assert preview["details"]["totals"]["discount"] == "250"
    end
  end

  describe "preview_update/2" do
    setup do
      bypass = Bypass.open()
      config = create_bypass_config(bypass)
      {:ok, bypass: bypass, config: config}
    end

    test "previews subscription update with new items", %{bypass: bypass, config: config} do
      preview_params = %{
        subscription_id: "sub_123",
        items: [
          %{price_id: "pri_new_plan", quantity: 1}
        ],
        proration_billing_mode: "prorated_immediately"
      }

      preview_response = %{
        "data" => %{
          "immediate_transaction" => %{
            "totals" => %{
              "subtotal" => "500",
              "tax" => "50",
              "total" => "550"
            }
          },
          "next_transaction" => %{
            "totals" => %{
              "subtotal" => "2000",
              "tax" => "200",
              "total" => "2200"
            }
          }
        }
      }

      Bypass.expect_once(bypass, "PATCH", "/subscriptions/preview", fn conn ->
        assert_valid_paddle_headers(conn)

        {:ok, body, conn} = Plug.Conn.read_body(conn)
        parsed_body = Jason.decode!(body)

        assert parsed_body["subscription_id"] == "sub_123"
        assert parsed_body["proration_billing_mode"] == "prorated_immediately"
        assert length(parsed_body["items"]) == 1
        assert hd(parsed_body["items"])["price_id"] == "pri_new_plan"

        Plug.Conn.resp(conn, 200, Jason.encode!(preview_response))
      end)

      assert {:ok, preview} = Subscription.preview_update(preview_params, config: config)
      assert preview["immediate_transaction"]["totals"]["total"] == "550"
      assert preview["next_transaction"]["totals"]["total"] == "2200"
    end

    test "previews adding items to existing subscription", %{bypass: bypass, config: config} do
      preview_params = %{
        subscription_id: "sub_456",
        items: [
          %{price_id: "pri_base", quantity: 1},
          %{price_id: "pri_addon", quantity: 2}
        ]
      }

      preview_response = %{
        "data" => %{
          "next_transaction" => %{
            "totals" => %{
              "subtotal" => "3000",
              "tax" => "300",
              "total" => "3300"
            }
          }
        }
      }

      Bypass.expect_once(bypass, "PATCH", "/subscriptions/preview", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        parsed_body = Jason.decode!(body)

        assert parsed_body["subscription_id"] == "sub_456"
        assert length(parsed_body["items"]) == 2

        Plug.Conn.resp(conn, 200, Jason.encode!(preview_response))
      end)

      assert {:ok, preview} = Subscription.preview_update(preview_params, config: config)
      assert preview["next_transaction"]["totals"]["total"] == "3300"
    end
  end

  describe "status check functions" do
    test "active?/1 returns true for active subscriptions" do
      active_subscription = %Subscription{status: "active"}
      inactive_subscription = %Subscription{status: "canceled"}

      assert Subscription.active?(active_subscription) == true
      assert Subscription.active?(inactive_subscription) == false
    end

    test "canceled?/1 returns true for canceled subscriptions" do
      canceled_subscription = %Subscription{status: "canceled"}
      active_subscription = %Subscription{status: "active"}

      assert Subscription.canceled?(canceled_subscription) == true
      assert Subscription.canceled?(active_subscription) == false
    end

    test "paused?/1 returns true for paused subscriptions" do
      paused_subscription = %Subscription{status: "paused"}
      active_subscription = %Subscription{status: "active"}

      assert Subscription.paused?(paused_subscription) == true
      assert Subscription.paused?(active_subscription) == false
    end

    test "trialing?/1 returns true for trialing subscriptions" do
      trialing_subscription = %Subscription{status: "trialing"}
      active_subscription = %Subscription{status: "active"}

      assert Subscription.trialing?(trialing_subscription) == true
      assert Subscription.trialing?(active_subscription) == false
    end
  end
end
