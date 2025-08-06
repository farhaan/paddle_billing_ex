defmodule PaddleBilling.PriceTest do
  use ExUnit.Case, async: true
  import PaddleBilling.TestHelpers

  alias PaddleBilling.{Price, Error}

  describe "list/2" do
    setup do
      bypass = Bypass.open()
      config = create_bypass_config(bypass)
      {:ok, bypass: bypass, config: config}
    end

    test "returns list of prices", %{bypass: bypass, config: config} do
      prices_response = %{
        "data" => [
          %{
            "id" => "pri_01gsz4t5hdjse780zja8vvr7jg",
            "description" => "Monthly Pro Plan",
            "product_id" => "pro_01gsz4t5hdjse780zja8vvr7jg",
            "name" => "Monthly Pro",
            "type" => "standard",
            "billing_cycle" => %{
              "interval" => "month",
              "frequency" => 1
            },
            "trial_period" => nil,
            "tax_mode" => "account_setting",
            "unit_price" => %{
              "amount" => "2999",
              "currency_code" => "USD"
            },
            "unit_price_overrides" => [],
            "quantity" => nil,
            "custom_data" => nil,
            "status" => "active",
            "created_at" => "2023-06-01T13:30:50.302Z",
            "updated_at" => "2023-06-01T13:30:50.302Z",
            "import_meta" => nil
          }
        ]
      }

      Bypass.expect_once(bypass, "GET", "/prices", fn conn ->
        assert_valid_paddle_headers(conn)
        Plug.Conn.resp(conn, 200, Jason.encode!(prices_response))
      end)

      assert {:ok, [price]} = Price.list(%{}, config: config)
      assert price.id == "pri_01gsz4t5hdjse780zja8vvr7jg"
      assert price.product_id == "pro_01gsz4t5hdjse780zja8vvr7jg"
      assert price.type == "standard"
      assert price.unit_price["amount"] == "2999"
      assert price.billing_cycle["interval"] == "month"
    end

    test "handles filtering parameters", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/prices", fn conn ->
        query_params = URI.decode_query(conn.query_string)

        assert query_params["product_id"] == "pro_123,pro_456"
        assert query_params["status"] == "active"
        assert query_params["recurring"] == "true"
        assert query_params["include"] == "product"

        Plug.Conn.resp(conn, 200, Jason.encode!(%{"data" => []}))
      end)

      assert {:ok, []} =
               Price.list(
                 %{
                   product_id: ["pro_123", "pro_456"],
                   status: ["active"],
                   recurring: true,
                   include: ["product"]
                 },
                 config: config
               )
    end

    test "handles empty list", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/prices", fn conn ->
        Plug.Conn.resp(conn, 200, Jason.encode!(%{"data" => []}))
      end)

      assert {:ok, []} = Price.list(%{}, config: config)
    end

    test "handles API errors", %{bypass: bypass, config: config} do
      setup_error_response(bypass, "GET", "/prices", 401, %{
        "error" => %{
          "code" => "authentication_failed",
          "detail" => "Invalid API key"
        }
      })

      assert {:error, %Error{type: :authentication_error}} = Price.list(%{}, config: config)
    end
  end

  describe "get/3" do
    setup do
      bypass = Bypass.open()
      config = create_bypass_config(bypass)
      {:ok, bypass: bypass, config: config}
    end

    test "returns single price", %{bypass: bypass, config: config} do
      price_response = %{
        "data" => %{
          "id" => "pri_01gsz4t5hdjse780zja8vvr7jg",
          "description" => "Annual Pro Plan",
          "product_id" => "pro_01gsz4t5hdjse780zja8vvr7jg",
          "name" => "Annual Pro",
          "type" => "standard",
          "billing_cycle" => %{
            "interval" => "year",
            "frequency" => 1
          },
          "trial_period" => %{
            "interval" => "day",
            "frequency" => 14
          },
          "tax_mode" => "account_setting",
          "unit_price" => %{
            "amount" => "29999",
            "currency_code" => "USD"
          },
          "unit_price_overrides" => [
            %{
              "country_codes" => ["GB"],
              "unit_price" => %{
                "amount" => "24999",
                "currency_code" => "GBP"
              }
            }
          ],
          "quantity" => %{
            "minimum" => 1,
            "maximum" => 10
          },
          "custom_data" => %{
            "tier" => "pro",
            "features" => ["analytics", "priority_support"]
          },
          "status" => "active",
          "created_at" => "2023-06-01T13:30:50.302Z",
          "updated_at" => "2023-06-01T14:15:25.123Z",
          "import_meta" => %{
            "external_id" => "price_123",
            "source" => "migration"
          }
        }
      }

      Bypass.expect_once(bypass, "GET", "/prices/pri_01gsz4t5hdjse780zja8vvr7jg", fn conn ->
        assert_valid_paddle_headers(conn)
        Plug.Conn.resp(conn, 200, Jason.encode!(price_response))
      end)

      assert {:ok, price} = Price.get("pri_01gsz4t5hdjse780zja8vvr7jg", %{}, config: config)

      assert price.id == "pri_01gsz4t5hdjse780zja8vvr7jg"
      assert price.description == "Annual Pro Plan"
      assert price.billing_cycle["interval"] == "year"
      assert price.trial_period["frequency"] == 14
      assert price.unit_price["amount"] == "29999"
      assert length(price.unit_price_overrides) == 1
      assert price.quantity["minimum"] == 1
      assert price.custom_data["tier"] == "pro"
      assert price.import_meta["external_id"] == "price_123"
    end

    test "handles include parameters", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/prices/pri_123", fn conn ->
        query_params = URI.decode_query(conn.query_string)
        assert query_params["include"] == "product"

        Plug.Conn.resp(
          conn,
          200,
          Jason.encode!(%{
            "data" => %{
              "id" => "pri_123",
              "product_id" => "pro_456",
              "type" => "standard",
              "status" => "active",
              "created_at" => "2023-06-01T13:30:50.302Z",
              "updated_at" => "2023-06-01T13:30:50.302Z"
            }
          })
        )
      end)

      assert {:ok, _price} = Price.get("pri_123", %{include: ["product"]}, config: config)
    end

    test "handles not found error", %{bypass: bypass, config: config} do
      setup_error_response(bypass, "GET", "/prices/pri_nonexistent", 404, %{
        "error" => %{
          "code" => "entity_not_found",
          "detail" => "Price not found"
        }
      })

      assert {:error, %Error{type: :not_found_error}} =
               Price.get("pri_nonexistent", %{}, config: config)
    end
  end

  describe "create/2" do
    setup do
      bypass = Bypass.open()
      config = create_bypass_config(bypass)
      {:ok, bypass: bypass, config: config}
    end

    test "creates one-time price", %{bypass: bypass, config: config} do
      price_data = %{
        product_id: "pro_01gsz4t5hdjse780zja8vvr7jg",
        description: "One-time Pro License",
        unit_price: %{
          amount: "9999",
          currency_code: "USD"
        },
        tax_mode: "account_setting"
      }

      create_response = %{
        "data" => %{
          "id" => "pri_01h123456789abcdefghijklmn",
          "description" => "One-time Pro License",
          "product_id" => "pro_01gsz4t5hdjse780zja8vvr7jg",
          "name" => nil,
          "type" => "standard",
          "billing_cycle" => nil,
          "trial_period" => nil,
          "tax_mode" => "account_setting",
          "unit_price" => %{
            "amount" => "9999",
            "currency_code" => "USD"
          },
          "unit_price_overrides" => [],
          "quantity" => nil,
          "custom_data" => nil,
          "status" => "active",
          "created_at" => "2023-06-01T13:30:50.302Z",
          "updated_at" => "2023-06-01T13:30:50.302Z",
          "import_meta" => nil
        }
      }

      Bypass.expect_once(bypass, "POST", "/prices", fn conn ->
        assert_valid_paddle_headers(conn)

        {:ok, body, conn} = Plug.Conn.read_body(conn)
        parsed_body = Jason.decode!(body)

        assert parsed_body["product_id"] == "pro_01gsz4t5hdjse780zja8vvr7jg"
        assert parsed_body["description"] == "One-time Pro License"
        assert parsed_body["unit_price"]["amount"] == "9999"
        assert parsed_body["unit_price"]["currency_code"] == "USD"

        Plug.Conn.resp(conn, 201, Jason.encode!(create_response))
      end)

      assert {:ok, price} = Price.create(price_data, config: config)

      assert price.id == "pri_01h123456789abcdefghijklmn"
      assert price.product_id == "pro_01gsz4t5hdjse780zja8vvr7jg"
      assert price.billing_cycle == nil
      assert price.unit_price["amount"] == "9999"
    end

    test "creates recurring price with trial", %{bypass: bypass, config: config} do
      price_data = %{
        product_id: "pro_01gsz4t5hdjse780zja8vvr7jg",
        description: "Monthly Pro Plan",
        billing_cycle: %{
          interval: "month",
          frequency: 1
        },
        trial_period: %{
          interval: "day",
          frequency: 7
        },
        unit_price: %{
          amount: "2999",
          currency_code: "USD"
        },
        custom_data: %{
          plan_tier: "pro",
          features: ["analytics", "api_access"]
        }
      }

      create_response = %{
        "data" => %{
          "id" => "pri_recurring",
          "description" => "Monthly Pro Plan",
          "product_id" => "pro_01gsz4t5hdjse780zja8vvr7jg",
          "type" => "standard",
          "billing_cycle" => %{
            "interval" => "month",
            "frequency" => 1
          },
          "trial_period" => %{
            "interval" => "day",
            "frequency" => 7
          },
          "unit_price" => %{
            "amount" => "2999",
            "currency_code" => "USD"
          },
          "custom_data" => %{
            "plan_tier" => "pro",
            "features" => ["analytics", "api_access"]
          },
          "status" => "active",
          "created_at" => "2023-06-01T13:30:50.302Z",
          "updated_at" => "2023-06-01T13:30:50.302Z"
        }
      }

      Bypass.expect_once(bypass, "POST", "/prices", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        parsed_body = Jason.decode!(body)

        assert is_map(parsed_body["billing_cycle"])
        assert parsed_body["billing_cycle"]["interval"] == "month"
        assert is_map(parsed_body["trial_period"])
        assert parsed_body["trial_period"]["frequency"] == 7
        assert is_map(parsed_body["custom_data"])

        Plug.Conn.resp(conn, 201, Jason.encode!(create_response))
      end)

      assert {:ok, price} = Price.create(price_data, config: config)

      assert price.billing_cycle["interval"] == "month"
      assert price.trial_period["frequency"] == 7
      assert price.custom_data["plan_tier"] == "pro"
    end

    test "handles validation errors", %{bypass: bypass, config: config} do
      setup_error_response(bypass, "POST", "/prices", 400, %{
        "errors" => [
          %{
            "field" => "product_id",
            "code" => "required",
            "detail" => "Product ID is required"
          },
          %{
            "field" => "unit_price",
            "code" => "required",
            "detail" => "Unit price is required for standard prices"
          }
        ]
      })

      assert {:error, %Error{type: :validation_error}} =
               Price.create(%{}, config: config)
    end
  end

  describe "update/3" do
    setup do
      bypass = Bypass.open()
      config = create_bypass_config(bypass)
      {:ok, bypass: bypass, config: config}
    end

    test "updates price fields", %{bypass: bypass, config: config} do
      update_params = %{
        description: "Updated Monthly Plan",
        unit_price: %{
          amount: "3499",
          currency_code: "USD"
        },
        custom_data: %{
          updated: true,
          version: 2
        }
      }

      update_response = %{
        "data" => %{
          "id" => "pri_01gsz4t5hdjse780zja8vvr7jg",
          "description" => "Updated Monthly Plan",
          "product_id" => "pro_01gsz4t5hdjse780zja8vvr7jg",
          "unit_price" => %{
            "amount" => "3499",
            "currency_code" => "USD"
          },
          "custom_data" => %{
            "updated" => true,
            "version" => 2
          },
          "status" => "active",
          "created_at" => "2023-06-01T13:30:50.302Z",
          "updated_at" => "2023-06-02T10:15:30.123Z"
        }
      }

      Bypass.expect_once(bypass, "PATCH", "/prices/pri_01gsz4t5hdjse780zja8vvr7jg", fn conn ->
        assert_valid_paddle_headers(conn)

        {:ok, body, conn} = Plug.Conn.read_body(conn)
        parsed_body = Jason.decode!(body)

        assert parsed_body["description"] == "Updated Monthly Plan"
        assert parsed_body["unit_price"]["amount"] == "3499"
        assert parsed_body["custom_data"]["updated"] == true

        Plug.Conn.resp(conn, 200, Jason.encode!(update_response))
      end)

      assert {:ok, price} =
               Price.update("pri_01gsz4t5hdjse780zja8vvr7jg", update_params, config: config)

      assert price.description == "Updated Monthly Plan"
      assert price.unit_price["amount"] == "3499"
      assert price.custom_data["version"] == 2
    end

    test "handles not found error", %{bypass: bypass, config: config} do
      setup_error_response(bypass, "PATCH", "/prices/pri_nonexistent", 404, %{
        "error" => %{
          "code" => "entity_not_found",
          "detail" => "Price not found"
        }
      })

      assert {:error, %Error{type: :not_found_error}} =
               Price.update("pri_nonexistent", %{description: "New"}, config: config)
    end
  end

  describe "archive/2" do
    setup do
      bypass = Bypass.open()
      config = create_bypass_config(bypass)
      {:ok, bypass: bypass, config: config}
    end

    test "archives price", %{bypass: bypass, config: config} do
      archive_response = %{
        "data" => %{
          "id" => "pri_01gsz4t5hdjse780zja8vvr7jg",
          "status" => "archived",
          "updated_at" => "2023-06-02T15:30:00.000Z"
        }
      }

      Bypass.expect_once(bypass, "PATCH", "/prices/pri_01gsz4t5hdjse780zja8vvr7jg", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        parsed_body = Jason.decode!(body)

        assert parsed_body["status"] == "archived"

        Plug.Conn.resp(conn, 200, Jason.encode!(archive_response))
      end)

      assert {:ok, price} = Price.archive("pri_01gsz4t5hdjse780zja8vvr7jg", config: config)
      assert price.status == "archived"
    end
  end

  describe "create_one_time/4" do
    setup do
      bypass = Bypass.open()
      config = create_bypass_config(bypass)
      {:ok, bypass: bypass, config: config}
    end

    test "creates one-time price with convenience function", %{bypass: bypass, config: config} do
      create_response = %{
        "data" => %{
          "id" => "pri_one_time",
          "product_id" => "pro_123",
          "type" => "standard",
          "billing_cycle" => nil,
          "unit_price" => %{
            "amount" => "4999",
            "currency_code" => "USD"
          },
          "description" => "One-time License",
          "status" => "active",
          "created_at" => "2023-06-01T13:30:50.302Z",
          "updated_at" => "2023-06-01T13:30:50.302Z"
        }
      }

      Bypass.expect_once(bypass, "POST", "/prices", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        parsed_body = Jason.decode!(body)

        assert parsed_body["product_id"] == "pro_123"
        assert parsed_body["type"] == "standard"
        assert parsed_body["unit_price"]["amount"] == "4999"
        assert parsed_body["description"] == "One-time License"
        refute Map.has_key?(parsed_body, "billing_cycle")

        Plug.Conn.resp(conn, 201, Jason.encode!(create_response))
      end)

      unit_price = %{amount: "4999", currency_code: "USD"}
      additional_params = %{description: "One-time License"}

      assert {:ok, price} =
               Price.create_one_time("pro_123", unit_price, additional_params, config: config)

      assert price.id == "pri_one_time"
      assert price.billing_cycle == nil
      assert price.description == "One-time License"
    end
  end

  describe "create_recurring/5" do
    setup do
      bypass = Bypass.open()
      config = create_bypass_config(bypass)
      {:ok, bypass: bypass, config: config}
    end

    test "creates recurring price with convenience function", %{bypass: bypass, config: config} do
      create_response = %{
        "data" => %{
          "id" => "pri_recurring",
          "product_id" => "pro_123",
          "type" => "standard",
          "billing_cycle" => %{
            "interval" => "month",
            "frequency" => 1
          },
          "trial_period" => %{
            "interval" => "day",
            "frequency" => 14
          },
          "unit_price" => %{
            "amount" => "2999",
            "currency_code" => "USD"
          },
          "description" => "Monthly Subscription",
          "status" => "active",
          "created_at" => "2023-06-01T13:30:50.302Z",
          "updated_at" => "2023-06-01T13:30:50.302Z"
        }
      }

      Bypass.expect_once(bypass, "POST", "/prices", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        parsed_body = Jason.decode!(body)

        assert parsed_body["product_id"] == "pro_123"
        assert parsed_body["type"] == "standard"
        assert is_map(parsed_body["billing_cycle"])
        assert parsed_body["billing_cycle"]["interval"] == "month"
        assert is_map(parsed_body["trial_period"])
        assert parsed_body["trial_period"]["frequency"] == 14
        assert parsed_body["description"] == "Monthly Subscription"

        Plug.Conn.resp(conn, 201, Jason.encode!(create_response))
      end)

      unit_price = %{amount: "2999", currency_code: "USD"}
      billing_cycle = %{interval: "month", frequency: 1}

      additional_params = %{
        description: "Monthly Subscription",
        trial_period: %{interval: "day", frequency: 14}
      }

      assert {:ok, price} =
               Price.create_recurring("pro_123", unit_price, billing_cycle, additional_params,
                 config: config
               )

      assert price.id == "pri_recurring"
      assert price.billing_cycle["interval"] == "month"
      assert price.trial_period["frequency"] == 14
      assert price.description == "Monthly Subscription"
    end
  end
end
