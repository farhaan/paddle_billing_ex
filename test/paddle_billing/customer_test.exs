defmodule PaddleBilling.CustomerTest do
  use ExUnit.Case, async: true
  import PaddleBilling.TestHelpers

  alias PaddleBilling.{Customer, Error}

  describe "list/2" do
    setup do
      bypass = Bypass.open()
      config = create_bypass_config(bypass)
      {:ok, bypass: bypass, config: config}
    end

    test "returns list of customers", %{bypass: bypass, config: config} do
      customers_response = %{
        "data" => [
          %{
            "id" => "ctm_01gsz4t5hdjse780zja8vvr7jg",
            "name" => "John Doe",
            "email" => "john.doe@example.com",
            "locale" => "en",
            "status" => "active",
            "custom_data" => %{
              "customer_tier" => "premium",
              "signup_source" => "website"
            },
            "created_at" => "2023-06-01T13:30:50.302Z",
            "updated_at" => "2023-06-01T13:30:50.302Z",
            "marketing_consent" => true,
            "import_meta" => nil
          },
          %{
            "id" => "ctm_01h123456789abcdefghijklmn",
            "name" => "Jane Smith",
            "email" => "jane.smith@company.com",
            "locale" => "en",
            "status" => "active",
            "custom_data" => nil,
            "created_at" => "2023-06-02T10:15:30.123Z",
            "updated_at" => "2023-06-02T10:15:30.123Z",
            "marketing_consent" => false,
            "import_meta" => nil
          }
        ]
      }

      Bypass.expect_once(bypass, "GET", "/customers", fn conn ->
        assert_valid_paddle_headers(conn)
        Plug.Conn.resp(conn, 200, Jason.encode!(customers_response))
      end)

      assert {:ok, customers} = Customer.list(%{}, config: config)
      assert length(customers) == 2

      [customer1, customer2] = customers
      assert customer1.id == "ctm_01gsz4t5hdjse780zja8vvr7jg"
      assert customer1.name == "John Doe"
      assert customer1.email == "john.doe@example.com"
      assert customer1.marketing_consent == true
      assert customer1.custom_data["customer_tier"] == "premium"

      assert customer2.id == "ctm_01h123456789abcdefghijklmn"
      assert customer2.name == "Jane Smith"
      assert customer2.marketing_consent == false
    end

    test "handles filtering parameters", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/customers", fn conn ->
        query_params = URI.decode_query(conn.query_string)

        assert query_params["email"] == "user@example.com"
        assert query_params["status"] == "active"
        assert query_params["include"] == "addresses,businesses"
        assert query_params["search"] == "john doe"

        Plug.Conn.resp(conn, 200, Jason.encode!(%{"data" => []}))
      end)

      assert {:ok, []} =
               Customer.list(
                 %{
                   email: "user@example.com",
                   status: ["active"],
                   include: ["addresses", "businesses"],
                   search: "john doe"
                 },
                 config: config
               )
    end

    test "handles empty list", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/customers", fn conn ->
        Plug.Conn.resp(conn, 200, Jason.encode!(%{"data" => []}))
      end)

      assert {:ok, []} = Customer.list(%{}, config: config)
    end

    test "handles API errors", %{bypass: bypass, config: config} do
      setup_error_response(bypass, "GET", "/customers", 401, %{
        "error" => %{
          "code" => "authentication_failed",
          "detail" => "Invalid API key"
        }
      })

      assert {:error, %Error{type: :authentication_error}} = Customer.list(%{}, config: config)
    end
  end

  describe "get/3" do
    setup do
      bypass = Bypass.open()
      config = create_bypass_config(bypass)
      {:ok, bypass: bypass, config: config}
    end

    test "returns single customer", %{bypass: bypass, config: config} do
      customer_response = %{
        "data" => %{
          "id" => "ctm_01gsz4t5hdjse780zja8vvr7jg",
          "name" => "Alice Johnson",
          "email" => "alice@example.com",
          "locale" => "fr",
          "status" => "active",
          "custom_data" => %{
            "vip" => true,
            "account_manager" => "Sarah Wilson",
            "preferences" => %{
              "currency" => "EUR",
              "language" => "french"
            }
          },
          "created_at" => "2023-06-01T13:30:50.302Z",
          "updated_at" => "2023-06-01T14:15:25.123Z",
          "marketing_consent" => true,
          "import_meta" => %{
            "external_id" => "legacy_cust_456",
            "source" => "migration_2023"
          }
        }
      }

      Bypass.expect_once(bypass, "GET", "/customers/ctm_01gsz4t5hdjse780zja8vvr7jg", fn conn ->
        assert_valid_paddle_headers(conn)
        Plug.Conn.resp(conn, 200, Jason.encode!(customer_response))
      end)

      assert {:ok, customer} = Customer.get("ctm_01gsz4t5hdjse780zja8vvr7jg", %{}, config: config)

      assert customer.id == "ctm_01gsz4t5hdjse780zja8vvr7jg"
      assert customer.name == "Alice Johnson"
      assert customer.email == "alice@example.com"
      assert customer.locale == "fr"
      assert customer.marketing_consent == true
      assert customer.custom_data["vip"] == true
      assert customer.custom_data["preferences"]["currency"] == "EUR"
      assert customer.import_meta["external_id"] == "legacy_cust_456"
    end

    test "handles include parameters", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/customers/ctm_123", fn conn ->
        query_params = URI.decode_query(conn.query_string)
        assert query_params["include"] == "addresses,businesses"

        Plug.Conn.resp(
          conn,
          200,
          Jason.encode!(%{
            "data" => %{
              "id" => "ctm_123",
              "name" => "Test Customer",
              "email" => "test@example.com",
              "status" => "active",
              "created_at" => "2023-06-01T13:30:50.302Z",
              "updated_at" => "2023-06-01T13:30:50.302Z",
              "marketing_consent" => false
            }
          })
        )
      end)

      assert {:ok, _customer} =
               Customer.get("ctm_123", %{include: ["addresses", "businesses"]}, config: config)
    end

    test "handles not found error", %{bypass: bypass, config: config} do
      setup_error_response(bypass, "GET", "/customers/ctm_nonexistent", 404, %{
        "error" => %{
          "code" => "entity_not_found",
          "detail" => "Customer not found"
        }
      })

      assert {:error, %Error{type: :not_found_error}} =
               Customer.get("ctm_nonexistent", %{}, config: config)
    end
  end

  describe "create/2" do
    setup do
      bypass = Bypass.open()
      config = create_bypass_config(bypass)
      {:ok, bypass: bypass, config: config}
    end

    test "creates customer with required fields", %{bypass: bypass, config: config} do
      customer_data = %{
        email: "newuser@example.com",
        name: "New User"
      }

      create_response = %{
        "data" => %{
          "id" => "ctm_01h987654321zyxwvutsrqponm",
          "name" => "New User",
          "email" => "newuser@example.com",
          "locale" => nil,
          "status" => "active",
          "custom_data" => nil,
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

        assert parsed_body["email"] == "newuser@example.com"
        assert parsed_body["name"] == "New User"

        Plug.Conn.resp(conn, 201, Jason.encode!(create_response))
      end)

      assert {:ok, customer} = Customer.create(customer_data, config: config)

      assert customer.id == "ctm_01h987654321zyxwvutsrqponm"
      assert customer.email == "newuser@example.com"
      assert customer.name == "New User"
      assert customer.status == "active"
      assert customer.marketing_consent == false
    end

    test "creates customer with all optional fields", %{bypass: bypass, config: config} do
      customer_data = %{
        email: "enterprise@company.com",
        name: "Enterprise Customer",
        locale: "de",
        custom_data: %{
          company_size: "500+",
          industry: "fintech",
          contract_type: "enterprise",
          account_manager: "John Smith"
        }
      }

      create_response = %{
        "data" => %{
          "id" => "ctm_enterprise",
          "name" => "Enterprise Customer",
          "email" => "enterprise@company.com",
          "locale" => "de",
          "status" => "active",
          "custom_data" => %{
            "company_size" => "500+",
            "industry" => "fintech",
            "contract_type" => "enterprise",
            "account_manager" => "John Smith"
          },
          "created_at" => "2023-06-01T13:30:50.302Z",
          "updated_at" => "2023-06-01T13:30:50.302Z",
          "marketing_consent" => false,
          "import_meta" => nil
        }
      }

      Bypass.expect_once(bypass, "POST", "/customers", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        parsed_body = Jason.decode!(body)

        assert parsed_body["email"] == "enterprise@company.com"
        assert parsed_body["locale"] == "de"
        assert is_map(parsed_body["custom_data"])
        assert parsed_body["custom_data"]["company_size"] == "500+"

        Plug.Conn.resp(conn, 201, Jason.encode!(create_response))
      end)

      assert {:ok, customer} = Customer.create(customer_data, config: config)

      assert customer.locale == "de"
      assert customer.custom_data["industry"] == "fintech"
      assert customer.custom_data["account_manager"] == "John Smith"
    end

    test "handles validation errors", %{bypass: bypass, config: config} do
      setup_error_response(bypass, "POST", "/customers", 400, %{
        "errors" => [
          %{
            "field" => "email",
            "code" => "required",
            "detail" => "Email is required"
          },
          %{
            "field" => "email",
            "code" => "invalid_format",
            "detail" => "Email must be a valid email address"
          }
        ]
      })

      assert {:error, %Error{type: :validation_error}} =
               Customer.create(%{name: "No Email"}, config: config)
    end

    test "handles duplicate email error", %{bypass: bypass, config: config} do
      setup_error_response(bypass, "POST", "/customers", 409, %{
        "error" => %{
          "code" => "conflict",
          "detail" => "A customer with this email already exists"
        }
      })

      assert {:error, %Error{type: :api_error}} =
               Customer.create(%{email: "duplicate@example.com"}, config: config)
    end
  end

  describe "update/3" do
    setup do
      bypass = Bypass.open()
      config = create_bypass_config(bypass)
      {:ok, bypass: bypass, config: config}
    end

    test "updates customer fields", %{bypass: bypass, config: config} do
      update_params = %{
        name: "Updated Name",
        marketing_consent: true,
        custom_data: %{
          tier: "premium",
          last_login: "2024-01-15T10:30:00Z"
        }
      }

      update_response = %{
        "data" => %{
          "id" => "ctm_01gsz4t5hdjse780zja8vvr7jg",
          "name" => "Updated Name",
          "email" => "existing@example.com",
          "locale" => "en",
          "status" => "active",
          "custom_data" => %{
            "tier" => "premium",
            "last_login" => "2024-01-15T10:30:00Z"
          },
          "created_at" => "2023-06-01T13:30:50.302Z",
          "updated_at" => "2024-01-15T11:00:00.000Z",
          "marketing_consent" => true,
          "import_meta" => nil
        }
      }

      Bypass.expect_once(bypass, "PATCH", "/customers/ctm_01gsz4t5hdjse780zja8vvr7jg", fn conn ->
        assert_valid_paddle_headers(conn)

        {:ok, body, conn} = Plug.Conn.read_body(conn)
        parsed_body = Jason.decode!(body)

        assert parsed_body["name"] == "Updated Name"
        assert parsed_body["marketing_consent"] == true
        assert parsed_body["custom_data"]["tier"] == "premium"

        Plug.Conn.resp(conn, 200, Jason.encode!(update_response))
      end)

      assert {:ok, customer} =
               Customer.update("ctm_01gsz4t5hdjse780zja8vvr7jg", update_params, config: config)

      assert customer.name == "Updated Name"
      assert customer.marketing_consent == true
      assert customer.custom_data["tier"] == "premium"
    end

    test "updates email address", %{bypass: bypass, config: config} do
      update_params = %{email: "newemail@example.com"}

      update_response = %{
        "data" => %{
          "id" => "ctm_123",
          "name" => "Customer Name",
          "email" => "newemail@example.com",
          "status" => "active",
          "created_at" => "2023-06-01T13:30:50.302Z",
          "updated_at" => "2024-01-15T11:00:00.000Z",
          "marketing_consent" => false
        }
      }

      Bypass.expect_once(bypass, "PATCH", "/customers/ctm_123", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        parsed_body = Jason.decode!(body)

        assert parsed_body["email"] == "newemail@example.com"

        Plug.Conn.resp(conn, 200, Jason.encode!(update_response))
      end)

      assert {:ok, customer} = Customer.update("ctm_123", update_params, config: config)
      assert customer.email == "newemail@example.com"
    end

    test "handles not found error", %{bypass: bypass, config: config} do
      setup_error_response(bypass, "PATCH", "/customers/ctm_nonexistent", 404, %{
        "error" => %{
          "code" => "entity_not_found",
          "detail" => "Customer not found"
        }
      })

      assert {:error, %Error{type: :not_found_error}} =
               Customer.update("ctm_nonexistent", %{name: "New Name"}, config: config)
    end
  end

  describe "archive/2" do
    setup do
      bypass = Bypass.open()
      config = create_bypass_config(bypass)
      {:ok, bypass: bypass, config: config}
    end

    test "archives customer", %{bypass: bypass, config: config} do
      archive_response = %{
        "data" => %{
          "id" => "ctm_01gsz4t5hdjse780zja8vvr7jg",
          "name" => "Archived Customer",
          "email" => "archived@example.com",
          "status" => "archived",
          "updated_at" => "2024-01-15T15:30:00.000Z",
          "marketing_consent" => false
        }
      }

      Bypass.expect_once(bypass, "PATCH", "/customers/ctm_01gsz4t5hdjse780zja8vvr7jg", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        parsed_body = Jason.decode!(body)

        assert parsed_body["status"] == "archived"

        Plug.Conn.resp(conn, 200, Jason.encode!(archive_response))
      end)

      assert {:ok, customer} = Customer.archive("ctm_01gsz4t5hdjse780zja8vvr7jg", config: config)
      assert customer.status == "archived"
    end
  end

  describe "search/2" do
    setup do
      bypass = Bypass.open()
      config = create_bypass_config(bypass)
      {:ok, bypass: bypass, config: config}
    end

    test "searches customers by query", %{bypass: bypass, config: config} do
      search_response = %{
        "data" => [
          %{
            "id" => "ctm_search1",
            "name" => "John Smith",
            "email" => "john.smith@example.com",
            "status" => "active",
            "created_at" => "2023-06-01T13:30:50.302Z",
            "updated_at" => "2023-06-01T13:30:50.302Z",
            "marketing_consent" => false
          }
        ]
      }

      Bypass.expect_once(bypass, "GET", "/customers", fn conn ->
        query_params = URI.decode_query(conn.query_string)
        assert query_params["search"] == "john smith"

        Plug.Conn.resp(conn, 200, Jason.encode!(search_response))
      end)

      assert {:ok, customers} = Customer.search("john smith", config: config)
      assert length(customers) == 1
      assert hd(customers).name == "John Smith"
    end
  end

  describe "find_by_email/2" do
    setup do
      bypass = Bypass.open()
      config = create_bypass_config(bypass)
      {:ok, bypass: bypass, config: config}
    end

    test "finds customer by email", %{bypass: bypass, config: config} do
      email_response = %{
        "data" => [
          %{
            "id" => "ctm_email_match",
            "name" => "Email Customer",
            "email" => "specific@example.com",
            "status" => "active",
            "created_at" => "2023-06-01T13:30:50.302Z",
            "updated_at" => "2023-06-01T13:30:50.302Z",
            "marketing_consent" => true
          }
        ]
      }

      Bypass.expect_once(bypass, "GET", "/customers", fn conn ->
        query_params = URI.decode_query(conn.query_string)
        assert query_params["email"] == "specific@example.com"

        Plug.Conn.resp(conn, 200, Jason.encode!(email_response))
      end)

      assert {:ok, customers} = Customer.find_by_email("specific@example.com", config: config)
      assert length(customers) == 1
      assert hd(customers).email == "specific@example.com"
    end
  end

  describe "set_marketing_consent/3" do
    setup do
      bypass = Bypass.open()
      config = create_bypass_config(bypass)
      {:ok, bypass: bypass, config: config}
    end

    test "sets marketing consent to true", %{bypass: bypass, config: config} do
      consent_response = %{
        "data" => %{
          "id" => "ctm_consent",
          "name" => "Consent Customer",
          "email" => "consent@example.com",
          "status" => "active",
          "marketing_consent" => true,
          "updated_at" => "2024-01-15T16:00:00.000Z"
        }
      }

      Bypass.expect_once(bypass, "PATCH", "/customers/ctm_consent", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        parsed_body = Jason.decode!(body)

        assert parsed_body["marketing_consent"] == true

        Plug.Conn.resp(conn, 200, Jason.encode!(consent_response))
      end)

      assert {:ok, customer} = Customer.set_marketing_consent("ctm_consent", true, config: config)
      assert customer.marketing_consent == true
    end

    test "sets marketing consent to false", %{bypass: bypass, config: config} do
      consent_response = %{
        "data" => %{
          "id" => "ctm_consent",
          "marketing_consent" => false,
          "status" => "active"
        }
      }

      Bypass.expect_once(bypass, "PATCH", "/customers/ctm_consent", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        parsed_body = Jason.decode!(body)

        assert parsed_body["marketing_consent"] == false

        Plug.Conn.resp(conn, 200, Jason.encode!(consent_response))
      end)

      assert {:ok, customer} =
               Customer.set_marketing_consent("ctm_consent", false, config: config)

      assert customer.marketing_consent == false
    end
  end
end
