defmodule PaddleBilling.AddressTest do
  use ExUnit.Case, async: true
  alias PaddleBilling.{Address, Error}

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
    test "lists all addresses successfully", %{bypass: bypass, config: config} do
      addresses_data = [
        %{
          "id" => "add_123",
          "customer_id" => "ctm_456",
          "description" => "Home Address",
          "first_line" => "123 Main St",
          "city" => "New York",
          "postal_code" => "10001",
          "region" => "NY",
          "country_code" => "US",
          "status" => "active",
          "created_at" => "2024-01-01T00:00:00Z",
          "updated_at" => "2024-01-01T00:00:00Z"
        }
      ]

      Bypass.expect_once(bypass, "GET", "/addresses", fn conn ->
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer pdl_test_123456789"]
        assert Plug.Conn.get_req_header(conn, "paddle-version") == ["1"]

        Plug.Conn.resp(
          conn,
          200,
          Jason.encode!(%{"data" => addresses_data})
        )
      end)

      assert {:ok, [address]} = Address.list(%{}, config: config)
      assert address.id == "add_123"
      assert address.customer_id == "ctm_456"
      assert address.description == "Home Address"
      assert address.first_line == "123 Main St"
      assert address.city == "New York"
      assert address.postal_code == "10001"
      assert address.region == "NY"
      assert address.country_code == "US"
      assert address.status == "active"
    end

    test "lists addresses with filtering parameters", %{bypass: bypass, config: config} do
      addresses_data = [
        %{
          "id" => "add_123",
          "customer_id" => "ctm_456",
          "country_code" => "US",
          "status" => "active",
          "created_at" => "2024-01-01T00:00:00Z",
          "updated_at" => "2024-01-01T00:00:00Z"
        }
      ]

      Bypass.expect_once(bypass, "GET", "/addresses", fn conn ->
        query_params = URI.decode_query(conn.query_string)

        assert query_params["customer_id"] == "ctm_456"
        assert query_params["country_code"] == "US,CA"
        assert query_params["status"] == "active"
        assert query_params["include"] == "customer"
        assert query_params["per_page"] == "50"

        Plug.Conn.resp(
          conn,
          200,
          Jason.encode!(%{"data" => addresses_data})
        )
      end)

      params = %{
        customer_id: ["ctm_456"],
        country_code: ["US", "CA"],
        status: ["active"],
        include: ["customer"],
        per_page: 50
      }

      assert {:ok, [address]} = Address.list(params, config: config)
      assert address.id == "add_123"
    end

    test "handles API errors", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/addresses", fn conn ->
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

      assert {:error, %Error{}} = Address.list(%{}, config: config)
    end
  end

  describe "get/3" do
    test "gets address by ID successfully", %{bypass: bypass, config: config} do
      address_data = %{
        "id" => "add_123",
        "customer_id" => "ctm_456",
        "description" => "Business Address",
        "first_line" => "456 Oak Ave",
        "second_line" => "Suite 100",
        "city" => "San Francisco",
        "postal_code" => "94102",
        "region" => "CA",
        "country_code" => "US",
        "custom_data" => %{"department" => "Engineering"},
        "status" => "active",
        "created_at" => "2024-01-01T00:00:00Z",
        "updated_at" => "2024-01-01T00:00:00Z",
        "import_meta" => %{"source" => "api"}
      }

      Bypass.expect_once(bypass, "GET", "/addresses/add_123", fn conn ->
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer pdl_test_123456789"]
        assert Plug.Conn.get_req_header(conn, "paddle-version") == ["1"]

        Plug.Conn.resp(
          conn,
          200,
          Jason.encode!(%{"data" => address_data})
        )
      end)

      assert {:ok, address} = Address.get("add_123", %{}, config: config)
      assert address.id == "add_123"
      assert address.customer_id == "ctm_456"
      assert address.description == "Business Address"
      assert address.first_line == "456 Oak Ave"
      assert address.second_line == "Suite 100"
      assert address.city == "San Francisco"
      assert address.postal_code == "94102"
      assert address.region == "CA"
      assert address.country_code == "US"
      assert address.custom_data == %{"department" => "Engineering"}
      assert address.status == "active"
      assert address.import_meta == %{"source" => "api"}
    end

    test "gets address with include parameters", %{bypass: bypass, config: config} do
      address_data = %{
        "id" => "add_123",
        "customer_id" => "ctm_456",
        "country_code" => "US",
        "status" => "active",
        "created_at" => "2024-01-01T00:00:00Z",
        "updated_at" => "2024-01-01T00:00:00Z"
      }

      Bypass.expect_once(bypass, "GET", "/addresses/add_123", fn conn ->
        query_params = URI.decode_query(conn.query_string)
        assert query_params["include"] == "customer"

        Plug.Conn.resp(
          conn,
          200,
          Jason.encode!(%{"data" => address_data})
        )
      end)

      assert {:ok, address} = Address.get("add_123", %{include: ["customer"]}, config: config)
      assert address.id == "add_123"
    end

    test "handles not found error", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/addresses/invalid_id", fn conn ->
        Plug.Conn.resp(
          conn,
          404,
          Jason.encode!(%{
            "error" => %{
              "type" => "not_found_error",
              "code" => "entity_not_found",
              "detail" => "Address not found"
            }
          })
        )
      end)

      assert {:error, %Error{type: :not_found_error}} =
               Address.get("invalid_id", %{}, config: config)
    end
  end

  describe "create/2" do
    test "creates address successfully", %{bypass: bypass, config: config} do
      create_params = %{
        customer_id: "ctm_456",
        country_code: "US",
        description: "Billing Address",
        first_line: "123 Main Street",
        city: "New York",
        region: "NY",
        postal_code: "10001"
      }

      created_address = %{
        "id" => "add_123",
        "customer_id" => "ctm_456",
        "country_code" => "US",
        "description" => "Billing Address",
        "first_line" => "123 Main Street",
        "city" => "New York",
        "region" => "NY",
        "postal_code" => "10001",
        "status" => "active",
        "created_at" => "2024-01-01T00:00:00Z",
        "updated_at" => "2024-01-01T00:00:00Z"
      }

      Bypass.expect_once(bypass, "POST", "/addresses", fn conn ->
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer pdl_test_123456789"]
        assert Plug.Conn.get_req_header(conn, "paddle-version") == ["1"]

        Plug.Conn.resp(
          conn,
          201,
          Jason.encode!(%{"data" => created_address})
        )
      end)

      assert {:ok, address} = Address.create(create_params, config: config)
      assert address.id == "add_123"
      assert address.customer_id == "ctm_456"
      assert address.country_code == "US"
      assert address.description == "Billing Address"
      assert address.first_line == "123 Main Street"
      assert address.city == "New York"
      assert address.region == "NY"
      assert address.postal_code == "10001"
      assert address.status == "active"
    end

    test "creates address with custom data", %{bypass: bypass, config: config} do
      create_params = %{
        customer_id: "ctm_enterprise",
        country_code: "CA",
        description: "Head Office",
        first_line: "100 Queen Street West",
        second_line: "Suite 3200",
        city: "Toronto",
        region: "ON",
        postal_code: "M5H 2N2",
        custom_data: %{
          "department" => "Finance",
          "contact_person" => "John Smith",
          "phone" => "+1-416-555-0123"
        }
      }

      created_address = %{
        "id" => "add_456",
        "customer_id" => "ctm_enterprise",
        "country_code" => "CA",
        "description" => "Head Office",
        "first_line" => "100 Queen Street West",
        "second_line" => "Suite 3200",
        "city" => "Toronto",
        "region" => "ON",
        "postal_code" => "M5H 2N2",
        "custom_data" => %{
          "department" => "Finance",
          "contact_person" => "John Smith",
          "phone" => "+1-416-555-0123"
        },
        "status" => "active",
        "created_at" => "2024-01-01T00:00:00Z",
        "updated_at" => "2024-01-01T00:00:00Z"
      }

      Bypass.expect_once(bypass, "POST", "/addresses", fn conn ->
        Plug.Conn.resp(
          conn,
          201,
          Jason.encode!(%{"data" => created_address})
        )
      end)

      assert {:ok, address} = Address.create(create_params, config: config)
      assert address.id == "add_456"

      assert address.custom_data == %{
               "department" => "Finance",
               "contact_person" => "John Smith",
               "phone" => "+1-416-555-0123"
             }
    end

    test "handles validation errors", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "POST", "/addresses", fn conn ->
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
                  "field" => "country_code",
                  "code" => "required",
                  "detail" => "Country code is required"
                }
              ]
            }
          })
        )
      end)

      invalid_params = %{
        customer_id: "ctm_456",
        # Invalid empty country code
        country_code: ""
      }

      assert {:error, %Error{type: :validation_error}} =
               Address.create(invalid_params, config: config)
    end
  end

  describe "update/3" do
    test "updates address successfully", %{bypass: bypass, config: config} do
      update_params = %{
        description: "Updated Billing Address",
        second_line: "Floor 2",
        custom_data: %{
          "updated_by" => "admin@company.com",
          "update_reason" => "Office relocation"
        }
      }

      updated_address = %{
        "id" => "add_123",
        "customer_id" => "ctm_456",
        "description" => "Updated Billing Address",
        "first_line" => "123 Main Street",
        "second_line" => "Floor 2",
        "city" => "New York",
        "postal_code" => "10001",
        "region" => "NY",
        "country_code" => "US",
        "custom_data" => %{
          "updated_by" => "admin@company.com",
          "update_reason" => "Office relocation"
        },
        "status" => "active",
        "created_at" => "2024-01-01T00:00:00Z",
        "updated_at" => "2024-01-01T12:00:00Z"
      }

      Bypass.expect_once(bypass, "PATCH", "/addresses/add_123", fn conn ->
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer pdl_test_123456789"]
        assert Plug.Conn.get_req_header(conn, "paddle-version") == ["1"]

        Plug.Conn.resp(
          conn,
          200,
          Jason.encode!(%{"data" => updated_address})
        )
      end)

      assert {:ok, address} = Address.update("add_123", update_params, config: config)
      assert address.id == "add_123"
      assert address.description == "Updated Billing Address"
      assert address.second_line == "Floor 2"
      assert address.custom_data["updated_by"] == "admin@company.com"
    end

    test "handles not found error", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "PATCH", "/addresses/invalid_id", fn conn ->
        Plug.Conn.resp(
          conn,
          404,
          Jason.encode!(%{
            "error" => %{
              "type" => "not_found_error",
              "code" => "entity_not_found",
              "detail" => "Address not found"
            }
          })
        )
      end)

      assert {:error, %Error{type: :not_found_error}} =
               Address.update("invalid_id", %{description: "Updated"}, config: config)
    end
  end

  describe "list_for_customer/3" do
    test "lists addresses for specific customer", %{bypass: bypass, config: config} do
      addresses_data = [
        %{
          "id" => "add_123",
          "customer_id" => "ctm_456",
          "country_code" => "US",
          "status" => "active",
          "created_at" => "2024-01-01T00:00:00Z",
          "updated_at" => "2024-01-01T00:00:00Z"
        }
      ]

      Bypass.expect_once(bypass, "GET", "/addresses", fn conn ->
        query_params = URI.decode_query(conn.query_string)
        assert query_params["customer_id"] == "ctm_456"
        assert query_params["status"] == "active"

        Plug.Conn.resp(
          conn,
          200,
          Jason.encode!(%{"data" => addresses_data})
        )
      end)

      assert {:ok, [address]} = Address.list_for_customer("ctm_456", ["active"], config: config)
      assert address.customer_id == "ctm_456"
      assert address.status == "active"
    end
  end

  describe "list_for_country/2" do
    test "lists addresses for specific country", %{bypass: bypass, config: config} do
      addresses_data = [
        %{
          "id" => "add_123",
          "customer_id" => "ctm_456",
          "country_code" => "US",
          "status" => "active",
          "created_at" => "2024-01-01T00:00:00Z",
          "updated_at" => "2024-01-01T00:00:00Z"
        }
      ]

      Bypass.expect_once(bypass, "GET", "/addresses", fn conn ->
        query_params = URI.decode_query(conn.query_string)
        assert query_params["country_code"] == "US"

        Plug.Conn.resp(
          conn,
          200,
          Jason.encode!(%{"data" => addresses_data})
        )
      end)

      assert {:ok, [address]} = Address.list_for_country("US", config: config)
      assert address.country_code == "US"
    end
  end

  describe "valid_for_tax?/1" do
    test "returns true for US address with postal code" do
      address = %Address{
        country_code: "US",
        postal_code: "10001",
        region: "NY"
      }

      assert Address.valid_for_tax?(address) == true
    end

    test "returns false for US address without postal code" do
      address = %Address{
        country_code: "US",
        postal_code: nil
      }

      assert Address.valid_for_tax?(address) == false
    end

    test "returns false for US address with empty postal code" do
      address = %Address{
        country_code: "US",
        postal_code: ""
      }

      assert Address.valid_for_tax?(address) == false
    end

    test "returns true for CA address with postal code" do
      address = %Address{
        country_code: "CA",
        postal_code: "M5H 2N2"
      }

      assert Address.valid_for_tax?(address) == true
    end

    test "returns false for CA address without postal code" do
      address = %Address{
        country_code: "CA",
        postal_code: nil
      }

      assert Address.valid_for_tax?(address) == false
    end

    test "returns true for EU countries regardless of postal code" do
      eu_countries = ["GB", "DE", "FR", "IT", "ES"]

      for country <- eu_countries do
        address_with_postal = %Address{
          country_code: country,
          postal_code: "12345"
        }

        address_without_postal = %Address{
          country_code: country,
          postal_code: nil
        }

        assert Address.valid_for_tax?(address_with_postal) == true
        assert Address.valid_for_tax?(address_without_postal) == true
      end
    end

    test "returns true for other countries with valid country code" do
      address = %Address{
        country_code: "AU",
        postal_code: nil
      }

      assert Address.valid_for_tax?(address) == true
    end

    test "returns false for invalid country code" do
      address = %Address{
        country_code: nil,
        postal_code: "12345"
      }

      assert Address.valid_for_tax?(address) == false

      address_empty = %Address{
        country_code: "",
        postal_code: "12345"
      }

      assert Address.valid_for_tax?(address_empty) == false
    end
  end

  describe "active?/1" do
    test "returns true for active address" do
      address = %Address{status: "active"}
      assert Address.active?(address) == true
    end

    test "returns false for non-active address" do
      address = %Address{status: "archived"}
      assert Address.active?(address) == false

      address_nil = %Address{status: nil}
      assert Address.active?(address_nil) == false
    end
  end

  describe "archived?/1" do
    test "returns true for archived address" do
      address = %Address{status: "archived"}
      assert Address.archived?(address) == true
    end

    test "returns false for non-archived address" do
      address = %Address{status: "active"}
      assert Address.archived?(address) == false

      address_nil = %Address{status: nil}
      assert Address.archived?(address_nil) == false
    end
  end
end
