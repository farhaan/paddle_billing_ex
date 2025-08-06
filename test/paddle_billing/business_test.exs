defmodule PaddleBilling.BusinessTest do
  use ExUnit.Case, async: true
  alias PaddleBilling.{Business, Error}

  setup do
    bypass = Bypass.open()

    # Override config to use bypass
    config = %{
      api_key: "pdl_test_123456789",
      environment: :sandbox,
      base_url: "http://localhost:#{bypass.port}",
      timeout: 30_000,
      retry: false
    }

    {:ok, bypass: bypass, config: config}
  end

  describe "list/2" do
    test "lists all businesses successfully", %{bypass: bypass, config: config} do
      businesses_data = [
        %{
          "id" => "biz_123",
          "customer_id" => "ctm_456",
          "name" => "Acme Corporation",
          "company_number" => "12345678",
          "tax_identifier" => "GB123456789",
          "status" => "active",
          "contacts" => [
            %{"name" => "John Doe", "email" => "john.doe@acme.com"}
          ],
          "created_at" => "2024-01-01T00:00:00Z",
          "updated_at" => "2024-01-01T00:00:00Z"
        }
      ]

      Bypass.expect_once(bypass, "GET", "/businesses", fn conn ->
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer pdl_test_123456789"]
        assert Plug.Conn.get_req_header(conn, "paddle-version") == ["1"]

        Plug.Conn.resp(
          conn,
          200,
          Jason.encode!(%{"data" => businesses_data})
        )
      end)

      assert {:ok, [business]} = Business.list(%{}, config: config)
      assert business.id == "biz_123"
      assert business.customer_id == "ctm_456"
      assert business.name == "Acme Corporation"
      assert business.company_number == "12345678"
      assert business.tax_identifier == "GB123456789"
      assert business.status == "active"
      assert length(business.contacts) == 1
      assert hd(business.contacts)["name"] == "John Doe"
    end

    test "lists businesses with filtering parameters", %{bypass: bypass, config: config} do
      businesses_data = [
        %{
          "id" => "biz_123",
          "customer_id" => "ctm_456",
          "name" => "Tech Solutions",
          "status" => "active",
          "created_at" => "2024-01-01T00:00:00Z",
          "updated_at" => "2024-01-01T00:00:00Z"
        }
      ]

      Bypass.expect_once(bypass, "GET", "/businesses", fn conn ->
        query_params = URI.decode_query(conn.query_string)

        assert query_params["customer_id"] == "ctm_456"
        assert query_params["status"] == "active"
        assert query_params["search"] == "tech"
        assert query_params["include"] == "customer"
        assert query_params["per_page"] == "25"

        Plug.Conn.resp(
          conn,
          200,
          Jason.encode!(%{"data" => businesses_data})
        )
      end)

      params = %{
        customer_id: ["ctm_456"],
        status: ["active"],
        search: "tech",
        include: ["customer"],
        per_page: 25
      }

      assert {:ok, [business]} = Business.list(params, config: config)
      assert business.id == "biz_123"
    end

    test "handles API errors", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/businesses", fn conn ->
        Plug.Conn.resp(
          conn,
          500,
          Jason.encode!(%{
            "error" => %{
              "type" => "internal_server_error",
              "code" => "internal_error",
              "detail" => "Something went wrong"
            }
          })
        )
      end)

      assert {:error, %Error{}} = Business.list(%{}, config: config)
    end
  end

  describe "get/3" do
    test "gets business by ID successfully", %{bypass: bypass, config: config} do
      business_data = %{
        "id" => "biz_123",
        "customer_id" => "ctm_456",
        "name" => "Innovation Ltd",
        "company_number" => "87654321",
        "tax_identifier" => "DE987654321",
        "status" => "active",
        "contacts" => [
          %{"name" => "Alice Smith", "email" => "alice@innovation.com"},
          %{"name" => "Bob Wilson", "email" => "bob@innovation.com"}
        ],
        "custom_data" => %{"industry" => "technology"},
        "created_at" => "2024-01-01T00:00:00Z",
        "updated_at" => "2024-01-01T00:00:00Z",
        "import_meta" => %{"source" => "api"}
      }

      Bypass.expect_once(bypass, "GET", "/businesses/biz_123", fn conn ->
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer pdl_test_123456789"]
        assert Plug.Conn.get_req_header(conn, "paddle-version") == ["1"]

        Plug.Conn.resp(
          conn,
          200,
          Jason.encode!(%{"data" => business_data})
        )
      end)

      assert {:ok, business} = Business.get("biz_123", %{}, config: config)
      assert business.id == "biz_123"
      assert business.customer_id == "ctm_456"
      assert business.name == "Innovation Ltd"
      assert business.company_number == "87654321"
      assert business.tax_identifier == "DE987654321"
      assert business.status == "active"
      assert length(business.contacts) == 2
      assert business.custom_data == %{"industry" => "technology"}
      assert business.import_meta == %{"source" => "api"}
    end

    test "gets business with include parameters", %{bypass: bypass, config: config} do
      business_data = %{
        "id" => "biz_123",
        "customer_id" => "ctm_456",
        "name" => "Test Corp",
        "status" => "active",
        "created_at" => "2024-01-01T00:00:00Z",
        "updated_at" => "2024-01-01T00:00:00Z"
      }

      Bypass.expect_once(bypass, "GET", "/businesses/biz_123", fn conn ->
        query_params = URI.decode_query(conn.query_string)
        assert query_params["include"] == "customer"

        Plug.Conn.resp(
          conn,
          200,
          Jason.encode!(%{"data" => business_data})
        )
      end)

      assert {:ok, business} = Business.get("biz_123", %{include: ["customer"]}, config: config)
      assert business.id == "biz_123"
    end

    test "handles not found error", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/businesses/invalid_id", fn conn ->
        Plug.Conn.resp(
          conn,
          404,
          Jason.encode!(%{
            "error" => %{
              "type" => "not_found_error",
              "code" => "entity_not_found",
              "detail" => "Business not found"
            }
          })
        )
      end)

      assert {:error, %Error{type: :not_found_error}} =
               Business.get("invalid_id", %{}, config: config)
    end
  end

  describe "create/2" do
    test "creates business successfully", %{bypass: bypass, config: config} do
      create_params = %{
        customer_id: "ctm_456",
        name: "Acme Corporation",
        company_number: "12345678",
        tax_identifier: "GB123456789"
      }

      created_business = %{
        "id" => "biz_123",
        "customer_id" => "ctm_456",
        "name" => "Acme Corporation",
        "company_number" => "12345678",
        "tax_identifier" => "GB123456789",
        "status" => "active",
        "contacts" => [],
        "created_at" => "2024-01-01T00:00:00Z",
        "updated_at" => "2024-01-01T00:00:00Z"
      }

      Bypass.expect_once(bypass, "POST", "/businesses", fn conn ->
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer pdl_test_123456789"]
        assert Plug.Conn.get_req_header(conn, "paddle-version") == ["1"]

        Plug.Conn.resp(
          conn,
          201,
          Jason.encode!(%{"data" => created_business})
        )
      end)

      assert {:ok, business} = Business.create(create_params, config: config)
      assert business.id == "biz_123"
      assert business.customer_id == "ctm_456"
      assert business.name == "Acme Corporation"
      assert business.company_number == "12345678"
      assert business.tax_identifier == "GB123456789"
      assert business.status == "active"
    end

    test "creates business with contacts and custom data", %{bypass: bypass, config: config} do
      create_params = %{
        customer_id: "ctm_enterprise",
        name: "Tech Solutions Ltd",
        company_number: "87654321",
        tax_identifier: "DE987654321",
        contacts: [
          %{
            name: "John Doe",
            email: "john.doe@techsolutions.com"
          },
          %{
            name: "Jane Smith",
            email: "jane.smith@techsolutions.com"
          }
        ],
        custom_data: %{
          "industry" => "technology",
          "employees" => "50-100",
          "founded" => "2020"
        }
      }

      created_business = %{
        "id" => "biz_456",
        "customer_id" => "ctm_enterprise",
        "name" => "Tech Solutions Ltd",
        "company_number" => "87654321",
        "tax_identifier" => "DE987654321",
        "status" => "active",
        "contacts" => [
          %{"name" => "John Doe", "email" => "john.doe@techsolutions.com"},
          %{"name" => "Jane Smith", "email" => "jane.smith@techsolutions.com"}
        ],
        "custom_data" => %{
          "industry" => "technology",
          "employees" => "50-100",
          "founded" => "2020"
        },
        "created_at" => "2024-01-01T00:00:00Z",
        "updated_at" => "2024-01-01T00:00:00Z"
      }

      Bypass.expect_once(bypass, "POST", "/businesses", fn conn ->
        Plug.Conn.resp(
          conn,
          201,
          Jason.encode!(%{"data" => created_business})
        )
      end)

      assert {:ok, business} = Business.create(create_params, config: config)
      assert business.id == "biz_456"
      assert length(business.contacts) == 2
      assert business.custom_data["industry"] == "technology"
    end

    test "handles validation errors", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "POST", "/businesses", fn conn ->
        Plug.Conn.resp(
          conn,
          422,
          Jason.encode!(%{
            "error" => %{
              "type" => "validation_error",
              "code" => "validation_failed",
              "detail" => "Validation failed",
              "errors" => [
                %{
                  "field" => "name",
                  "code" => "required",
                  "detail" => "Business name is required"
                }
              ]
            }
          })
        )
      end)

      invalid_params = %{
        customer_id: "ctm_456",
        # Invalid empty name
        name: ""
      }

      assert {:error, %Error{type: :validation_error}} =
               Business.create(invalid_params, config: config)
    end
  end

  describe "update/3" do
    test "updates business successfully", %{bypass: bypass, config: config} do
      update_params = %{
        name: "Acme Corporation Ltd",
        tax_identifier: "US123456789",
        contacts: [
          %{
            name: "Alice Johnson",
            email: "alice.johnson@acme.com"
          }
        ],
        custom_data: %{
          "updated_by" => "admin@acme.com",
          "tax_status" => "verified"
        }
      }

      updated_business = %{
        "id" => "biz_123",
        "customer_id" => "ctm_456",
        "name" => "Acme Corporation Ltd",
        "company_number" => "12345678",
        "tax_identifier" => "US123456789",
        "status" => "active",
        "contacts" => [
          %{"name" => "Alice Johnson", "email" => "alice.johnson@acme.com"}
        ],
        "custom_data" => %{
          "updated_by" => "admin@acme.com",
          "tax_status" => "verified"
        },
        "created_at" => "2024-01-01T00:00:00Z",
        "updated_at" => "2024-01-01T12:00:00Z"
      }

      Bypass.expect_once(bypass, "PATCH", "/businesses/biz_123", fn conn ->
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer pdl_test_123456789"]
        assert Plug.Conn.get_req_header(conn, "paddle-version") == ["1"]

        Plug.Conn.resp(
          conn,
          200,
          Jason.encode!(%{"data" => updated_business})
        )
      end)

      assert {:ok, business} = Business.update("biz_123", update_params, config: config)
      assert business.id == "biz_123"
      assert business.name == "Acme Corporation Ltd"
      assert business.tax_identifier == "US123456789"
      assert length(business.contacts) == 1
      assert business.custom_data["updated_by"] == "admin@acme.com"
    end

    test "archives business", %{bypass: bypass, config: config} do
      updated_business = %{
        "id" => "biz_123",
        "customer_id" => "ctm_456",
        "name" => "Acme Corporation",
        "status" => "archived",
        "created_at" => "2024-01-01T00:00:00Z",
        "updated_at" => "2024-01-01T12:00:00Z"
      }

      Bypass.expect_once(bypass, "PATCH", "/businesses/biz_123", fn conn ->
        Plug.Conn.resp(
          conn,
          200,
          Jason.encode!(%{"data" => updated_business})
        )
      end)

      assert {:ok, business} = Business.archive("biz_123", config: config)
      assert business.status == "archived"
    end

    test "handles not found error", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "PATCH", "/businesses/invalid_id", fn conn ->
        Plug.Conn.resp(
          conn,
          404,
          Jason.encode!(%{
            "error" => %{
              "type" => "not_found_error",
              "code" => "entity_not_found",
              "detail" => "Business not found"
            }
          })
        )
      end)

      assert {:error, %Error{type: :not_found_error}} =
               Business.update("invalid_id", %{name: "Updated"}, config: config)
    end
  end

  describe "list_for_customer/3" do
    test "lists businesses for specific customer", %{bypass: bypass, config: config} do
      businesses_data = [
        %{
          "id" => "biz_123",
          "customer_id" => "ctm_456",
          "name" => "Primary Business",
          "status" => "active",
          "created_at" => "2024-01-01T00:00:00Z",
          "updated_at" => "2024-01-01T00:00:00Z"
        }
      ]

      Bypass.expect_once(bypass, "GET", "/businesses", fn conn ->
        query_params = URI.decode_query(conn.query_string)
        assert query_params["customer_id"] == "ctm_456"
        assert query_params["status"] == "active"

        Plug.Conn.resp(
          conn,
          200,
          Jason.encode!(%{"data" => businesses_data})
        )
      end)

      assert {:ok, [business]} = Business.list_for_customer("ctm_456", ["active"], config: config)
      assert business.customer_id == "ctm_456"
      assert business.status == "active"
    end
  end

  describe "search/2" do
    test "searches businesses by name", %{bypass: bypass, config: config} do
      businesses_data = [
        %{
          "id" => "biz_123",
          "customer_id" => "ctm_456",
          "name" => "Acme Corporation",
          "status" => "active",
          "created_at" => "2024-01-01T00:00:00Z",
          "updated_at" => "2024-01-01T00:00:00Z"
        }
      ]

      Bypass.expect_once(bypass, "GET", "/businesses", fn conn ->
        query_params = URI.decode_query(conn.query_string)
        assert query_params["search"] == "acme"

        Plug.Conn.resp(
          conn,
          200,
          Jason.encode!(%{"data" => businesses_data})
        )
      end)

      assert {:ok, [business]} = Business.search("acme", config: config)
      assert business.name =~ "Acme"
    end
  end

  describe "valid_tax_identifier?/1" do
    test "validates UK VAT numbers" do
      assert Business.valid_tax_identifier?("GB123456789") == true
      assert Business.valid_tax_identifier?("GB123456789012") == true
      assert Business.valid_tax_identifier?("gb123456789") == true
      # too short
      assert Business.valid_tax_identifier?("GB12345678") == false
      # too long
      assert Business.valid_tax_identifier?("GB1234567890123") == false
      # non-numeric
      assert Business.valid_tax_identifier?("GB12345678A") == false
    end

    test "validates US Federal EIN" do
      assert Business.valid_tax_identifier?("12-3456789") == true
      assert Business.valid_tax_identifier?("00-1234567") == true
      # missing dash
      assert Business.valid_tax_identifier?("123456789") == false
      # too short
      assert Business.valid_tax_identifier?("12-345678") == false
      # too long
      assert Business.valid_tax_identifier?("12-34567890") == false
    end

    test "validates German VAT numbers" do
      assert Business.valid_tax_identifier?("DE123456789") == true
      assert Business.valid_tax_identifier?("de123456789") == true
      # too short
      assert Business.valid_tax_identifier?("DE12345678") == false
      # too long
      assert Business.valid_tax_identifier?("DE1234567890") == false
      # non-numeric
      assert Business.valid_tax_identifier?("DE12345678A") == false
    end

    test "validates French VAT numbers" do
      assert Business.valid_tax_identifier?("FR12345678901") == true
      assert Business.valid_tax_identifier?("FRAB345678901") == true
      assert Business.valid_tax_identifier?("fr12345678901") == true
      # too short
      assert Business.valid_tax_identifier?("FR1234567890") == false
      # too long
      assert Business.valid_tax_identifier?("FR123456789012") == false
    end

    test "validates Canadian Business Numbers" do
      assert Business.valid_tax_identifier?("123456789BC0001") == true
      assert Business.valid_tax_identifier?("987654321ON0001") == true
      # too short
      assert Business.valid_tax_identifier?("12345678BC0001") == false
      # missing digit
      assert Business.valid_tax_identifier?("123456789BC001") == false
    end

    test "validates Australian ABN" do
      assert Business.valid_tax_identifier?("12345678901") == true
      assert Business.valid_tax_identifier?("98765432109") == true
      # too short
      assert Business.valid_tax_identifier?("1234567890") == false
      # too long
      assert Business.valid_tax_identifier?("123456789012") == false
      # non-numeric
      assert Business.valid_tax_identifier?("1234567890A") == false
    end

    test "validates generic tax identifiers" do
      assert Business.valid_tax_identifier?("ABC123") == true
      assert Business.valid_tax_identifier?("123-456-789") == true
      assert Business.valid_tax_identifier?("TAX123456") == true
      # too short
      assert Business.valid_tax_identifier?("AB") == false
      # empty
      assert Business.valid_tax_identifier?("") == false
      # nil
      assert Business.valid_tax_identifier?(nil) == false
    end

    test "rejects invalid formats" do
      assert Business.valid_tax_identifier?("invalid") == false
      assert Business.valid_tax_identifier?("12") == false
      assert Business.valid_tax_identifier?("") == false
      assert Business.valid_tax_identifier?(nil) == false
      assert Business.valid_tax_identifier?(123) == false
    end
  end

  describe "active?/1" do
    test "returns true for active business" do
      business = %Business{status: "active"}
      assert Business.active?(business) == true
    end

    test "returns false for non-active business" do
      business = %Business{status: "archived"}
      assert Business.active?(business) == false

      business_nil = %Business{status: nil}
      assert Business.active?(business_nil) == false
    end
  end

  describe "archived?/1" do
    test "returns true for archived business" do
      business = %Business{status: "archived"}
      assert Business.archived?(business) == true
    end

    test "returns false for non-archived business" do
      business = %Business{status: "active"}
      assert Business.archived?(business) == false

      business_nil = %Business{status: nil}
      assert Business.archived?(business_nil) == false
    end
  end

  describe "has_tax_identifier?/1" do
    test "returns true when business has tax identifier" do
      business = %Business{tax_identifier: "GB123456789"}
      assert Business.has_tax_identifier?(business) == true
    end

    test "returns false when business has no tax identifier" do
      business = %Business{tax_identifier: nil}
      assert Business.has_tax_identifier?(business) == false

      business_empty = %Business{tax_identifier: ""}
      assert Business.has_tax_identifier?(business_empty) == false
    end
  end

  describe "valid_tax_info?/1" do
    test "returns true for business with valid tax identifier" do
      business = %Business{tax_identifier: "GB123456789"}
      assert Business.valid_tax_info?(business) == true
    end

    test "returns false for business with invalid tax identifier" do
      business = %Business{tax_identifier: "invalid"}
      assert Business.valid_tax_info?(business) == false

      business_nil = %Business{tax_identifier: nil}
      assert Business.valid_tax_info?(business_nil) == false
    end
  end
end
