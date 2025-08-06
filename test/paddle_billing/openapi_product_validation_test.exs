defmodule PaddleBilling.OpenApiProductValidationTest do
  @moduledoc """
  Comprehensive validation of the Product module against Paddle's OpenAPI specification.

  This test suite ensures that our Product implementation exactly matches the 
  OpenAPI specification requirements for:
  - Request/response schemas
  - Field validation
  - Data types and formats
  - Required vs optional fields
  - Error responses
  - HTTP status codes

  Based on: https://github.com/PaddleHQ/paddle-openapi/blob/main/v1/openapi.yaml
  Product schema validation from paths: /products, /products/{product_id}
  """

  use ExUnit.Case, async: true
  import PaddleBilling.TestHelpers

  alias PaddleBilling.{Product, Error}

  describe "Product schema validation against OpenAPI spec" do
    setup do
      bypass = Bypass.open()
      config = create_bypass_config(bypass)
      {:ok, bypass: bypass, config: config}
    end

    test "validates complete product response schema", %{bypass: bypass, config: config} do
      # Complete product per OpenAPI specification with all possible fields
      complete_product_response = %{
        "data" => %{
          "id" => "pro_01gsz4t5hdjse780zja8vvr7jg",
          "name" => "Complete Test Product",
          "description" => "A comprehensive product for schema validation",
          "type" => "standard",
          "tax_category" => "standard",
          "image_url" => "https://example.com/images/product.jpg",
          "custom_data" => %{
            "category" => "electronics",
            "weight" => 2.5,
            "dimensions" => %{
              "length" => 15.5,
              "width" => 10.2,
              "height" => 5.8
            },
            "features" => ["waterproof", "bluetooth", "rechargeable"],
            "metadata" => %{
              "created_by" => "admin_user",
              "source" => "api",
              "version" => 2
            }
          },
          "status" => "active",
          "created_at" => "2023-06-01T13:30:50.302Z",
          "updated_at" => "2023-06-01T14:15:25.123Z",
          "import_meta" => %{
            "external_id" => "ext_prod_12345",
            "imported_from" => "legacy_system"
          }
        },
        "meta" => %{
          "request_id" => "req_01gsz4t5hdjse780zja8vvr7jg"
        }
      }

      Bypass.expect_once(bypass, "GET", "/products/pro_01gsz4t5hdjse780zja8vvr7jg", fn conn ->
        assert_valid_paddle_headers(conn)
        Plug.Conn.resp(conn, 200, Jason.encode!(complete_product_response))
      end)

      assert {:ok, product} = Product.get("pro_01gsz4t5hdjse780zja8vvr7jg", %{}, config: config)

      # Validate all required fields per OpenAPI spec
      assert product.id == "pro_01gsz4t5hdjse780zja8vvr7jg"
      assert product.name == "Complete Test Product"
      assert product.description == "A comprehensive product for schema validation"
      assert product.type == "standard"
      assert product.tax_category == "standard"
      assert product.image_url == "https://example.com/images/product.jpg"
      assert product.status == "active"
      assert product.created_at == "2023-06-01T13:30:50.302Z"
      assert product.updated_at == "2023-06-01T14:15:25.123Z"

      # Validate custom_data structure preservation
      assert is_map(product.custom_data)
      assert product.custom_data["category"] == "electronics"
      assert product.custom_data["weight"] == 2.5
      assert is_map(product.custom_data["dimensions"])
      assert is_list(product.custom_data["features"])
      assert length(product.custom_data["features"]) == 3

      # Validate import_meta when present
      assert is_map(product.import_meta)
      assert product.import_meta["external_id"] == "ext_prod_12345"
    end

    test "validates minimal product response schema", %{bypass: bypass, config: config} do
      # Minimal product with only required fields per OpenAPI spec
      minimal_product_response = %{
        "data" => %{
          "id" => "pro_01gsz4t5hdjse780zja8vvr7jg",
          "name" => "Minimal Product",
          "description" => nil,
          "type" => "standard",
          "tax_category" => "standard",
          "image_url" => nil,
          "custom_data" => nil,
          "status" => "active",
          "created_at" => "2023-06-01T13:30:50.302Z",
          "updated_at" => "2023-06-01T13:30:50.302Z",
          "import_meta" => nil
        }
      }

      Bypass.expect_once(bypass, "GET", "/products/pro_minimal", fn conn ->
        Plug.Conn.resp(conn, 200, Jason.encode!(minimal_product_response))
      end)

      assert {:ok, product} = Product.get("pro_minimal", %{}, config: config)

      # Required fields must be present
      assert product.id == "pro_01gsz4t5hdjse780zja8vvr7jg"
      assert product.name == "Minimal Product"
      assert product.type == "standard"
      assert product.status == "active"
      assert product.created_at == "2023-06-01T13:30:50.302Z"
      assert product.updated_at == "2023-06-01T13:30:50.302Z"

      # Optional fields can be nil
      assert product.description == nil
      assert product.image_url == nil
      assert product.custom_data == nil
      assert product.import_meta == nil
    end

    test "validates product type enum values per OpenAPI spec", %{bypass: bypass, config: config} do
      # Test all valid product types per OpenAPI specification
      valid_types = ["standard", "service"]

      for {product_type, index} <- Enum.with_index(valid_types) do
        product_response = %{
          "data" => %{
            "id" => "pro_type_#{index}",
            "name" => "#{String.capitalize(product_type)} Product",
            "type" => product_type,
            "tax_category" => "standard",
            "status" => "active",
            "created_at" => "2023-06-01T13:30:50.302Z",
            "updated_at" => "2023-06-01T13:30:50.302Z"
          }
        }

        Bypass.expect_once(bypass, "GET", "/products/pro_type_#{index}", fn conn ->
          Plug.Conn.resp(conn, 200, Jason.encode!(product_response))
        end)

        assert {:ok, product} = Product.get("pro_type_#{index}", %{}, config: config)
        assert product.type == product_type
      end
    end

    test "validates product status enum values per OpenAPI spec", %{
      bypass: bypass,
      config: config
    } do
      # Test all valid product statuses per OpenAPI specification
      valid_statuses = ["active", "archived"]

      for {status, index} <- Enum.with_index(valid_statuses) do
        product_response = %{
          "data" => %{
            "id" => "pro_status_#{index}",
            "name" => "#{String.capitalize(status)} Product",
            "type" => "standard",
            "tax_category" => "standard",
            "status" => status,
            "created_at" => "2023-06-01T13:30:50.302Z",
            "updated_at" => "2023-06-01T13:30:50.302Z"
          }
        }

        Bypass.expect_once(bypass, "GET", "/products/pro_status_#{index}", fn conn ->
          Plug.Conn.resp(conn, 200, Jason.encode!(product_response))
        end)

        assert {:ok, product} = Product.get("pro_status_#{index}", %{}, config: config)
        assert product.status == status
      end
    end

    test "validates tax_category field per OpenAPI spec", %{bypass: bypass, config: config} do
      # Test common tax categories (OpenAPI spec allows any string)
      tax_categories = ["standard", "reduced", "zero", "exempt", "saas"]

      for {tax_category, index} <- Enum.with_index(tax_categories) do
        product_response = %{
          "data" => %{
            "id" => "pro_tax_#{index}",
            "name" => "Tax Category Test",
            "type" => "standard",
            "tax_category" => tax_category,
            "status" => "active",
            "created_at" => "2023-06-01T13:30:50.302Z",
            "updated_at" => "2023-06-01T13:30:50.302Z"
          }
        }

        Bypass.expect_once(bypass, "GET", "/products/pro_tax_#{index}", fn conn ->
          Plug.Conn.resp(conn, 200, Jason.encode!(product_response))
        end)

        assert {:ok, product} = Product.get("pro_tax_#{index}", %{}, config: config)
        assert product.tax_category == tax_category
      end
    end
  end

  describe "Product list response validation against OpenAPI spec" do
    setup do
      bypass = Bypass.open()
      config = create_bypass_config(bypass)
      {:ok, bypass: bypass, config: config}
    end

    test "validates paginated list response format", %{bypass: bypass, config: config} do
      # OpenAPI spec pagination response with multiple products
      paginated_response = %{
        "data" => [
          %{
            "id" => "pro_01gsz4t5hdjse780zja8vvr7jg",
            "name" => "First Product",
            "type" => "standard",
            "tax_category" => "standard",
            "status" => "active",
            "created_at" => "2023-06-01T13:30:50.302Z",
            "updated_at" => "2023-06-01T13:30:50.302Z"
          },
          %{
            "id" => "pro_01h123456789abcdefghijklmn",
            "name" => "Second Product",
            "type" => "service",
            "tax_category" => "standard",
            "status" => "active",
            "created_at" => "2023-06-02T10:15:30.123Z",
            "updated_at" => "2023-06-02T10:15:30.123Z"
          }
        ],
        "meta" => %{
          "request_id" => "req_01gsz4t5hdjse780zja8vvr7jg",
          "pagination" => %{
            "per_page" => 50,
            "next" => "https://api.paddle.com/products?after=pro_01h123456789abcdefghijklmn",
            "has_more" => true,
            "estimated_total" => 157
          }
        }
      }

      Bypass.expect_once(bypass, "GET", "/products", fn conn ->
        assert_valid_paddle_headers(conn)

        # Validate query parameters match OpenAPI spec
        query_params = URI.decode_query(conn.query_string)

        if query_params["per_page"],
          do: assert(String.to_integer(query_params["per_page"]) <= 200)

        Plug.Conn.resp(conn, 200, Jason.encode!(paginated_response))
      end)

      assert {:ok, products} = Product.list(%{}, config: config)

      # Validate list structure
      assert length(products) == 2

      # Validate first product
      first_product = hd(products)
      assert first_product.id == "pro_01gsz4t5hdjse780zja8vvr7jg"
      assert first_product.name == "First Product"
      assert first_product.type == "standard"

      # Validate second product  
      second_product = Enum.at(products, 1)
      assert second_product.id == "pro_01h123456789abcdefghijklmn"
      assert second_product.name == "Second Product"
      assert second_product.type == "service"
    end

    test "validates empty list response format", %{bypass: bypass, config: config} do
      # Empty list per OpenAPI spec
      empty_response = %{
        "data" => [],
        "meta" => %{
          "request_id" => "req_01gsz4t5hdjse780zja8vvr7jg",
          "pagination" => %{
            "per_page" => 50,
            "next" => nil,
            "has_more" => false,
            "estimated_total" => 0
          }
        }
      }

      Bypass.expect_once(bypass, "GET", "/products", fn conn ->
        Plug.Conn.resp(conn, 200, Jason.encode!(empty_response))
      end)

      assert {:ok, products} = Product.list(%{}, config: config)
      assert products == []
    end
  end

  describe "Product creation request validation against OpenAPI spec" do
    setup do
      bypass = Bypass.open()
      config = create_bypass_config(bypass)
      {:ok, bypass: bypass, config: config}
    end

    test "validates complete creation request schema", %{bypass: bypass, config: config} do
      # Complete product creation data per OpenAPI spec
      complete_creation_data = %{
        name: "Complete Creation Product",
        description: "Product created with all possible fields",
        type: "standard",
        tax_category: "standard",
        image_url: "https://example.com/creation-product.jpg",
        custom_data: %{
          "department" => "electronics",
          "supplier" => "acme_corp",
          "specifications" => %{
            "model" => "ACM-2024",
            "year" => 2024,
            "warranty_months" => 24
          },
          "tags" => ["new", "featured", "bestseller"]
        }
      }

      creation_response = %{
        "data" => %{
          "id" => "pro_01h987654321zyxwvutsrqponm",
          "name" => "Complete Creation Product",
          "description" => "Product created with all possible fields",
          "type" => "standard",
          "tax_category" => "standard",
          "image_url" => "https://example.com/creation-product.jpg",
          "custom_data" => %{
            "department" => "electronics",
            "supplier" => "acme_corp",
            "specifications" => %{
              "model" => "ACM-2024",
              "year" => 2024,
              "warranty_months" => 24
            },
            "tags" => ["new", "featured", "bestseller"]
          },
          "status" => "active",
          "created_at" => "2023-06-01T13:30:50.302Z",
          "updated_at" => "2023-06-01T13:30:50.302Z",
          "import_meta" => nil
        }
      }

      Bypass.expect_once(bypass, "POST", "/products", fn conn ->
        assert_valid_paddle_headers(conn)

        {:ok, body, conn} = Plug.Conn.read_body(conn)
        parsed_body = Jason.decode!(body)

        # Validate all fields are properly serialized per OpenAPI schema
        assert parsed_body["name"] == "Complete Creation Product"
        assert parsed_body["description"] == "Product created with all possible fields"
        assert parsed_body["type"] == "standard"
        assert parsed_body["tax_category"] == "standard"
        assert parsed_body["image_url"] == "https://example.com/creation-product.jpg"

        # Validate custom_data structure preservation
        assert is_map(parsed_body["custom_data"])
        assert parsed_body["custom_data"]["department"] == "electronics"
        assert is_map(parsed_body["custom_data"]["specifications"])
        assert parsed_body["custom_data"]["specifications"]["year"] == 2024
        assert is_list(parsed_body["custom_data"]["tags"])
        assert length(parsed_body["custom_data"]["tags"]) == 3

        Plug.Conn.resp(conn, 201, Jason.encode!(creation_response))
      end)

      assert {:ok, product} = Product.create(complete_creation_data, config: config)

      # Validate response matches input data
      assert product.id == "pro_01h987654321zyxwvutsrqponm"
      assert product.name == "Complete Creation Product"
      assert product.custom_data["department"] == "electronics"
      assert product.custom_data["specifications"]["model"] == "ACM-2024"
    end

    test "validates minimal creation request schema", %{bypass: bypass, config: config} do
      # Minimal product creation with only required fields
      minimal_creation_data = %{
        name: "Minimal Creation Product"
      }

      creation_response = %{
        "data" => %{
          "id" => "pro_01h555666777888999aaabbbcc",
          "name" => "Minimal Creation Product",
          "description" => nil,
          # Default value
          "type" => "standard",
          # Default value
          "tax_category" => "standard",
          "image_url" => nil,
          "custom_data" => nil,
          "status" => "active",
          "created_at" => "2023-06-01T13:30:50.302Z",
          "updated_at" => "2023-06-01T13:30:50.302Z",
          "import_meta" => nil
        }
      }

      Bypass.expect_once(bypass, "POST", "/products", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        parsed_body = Jason.decode!(body)

        # Only name should be provided
        assert parsed_body["name"] == "Minimal Creation Product"

        # Other fields should not be present or be nil
        # Should not be in request
        refute Map.has_key?(parsed_body, "id")

        Plug.Conn.resp(conn, 201, Jason.encode!(creation_response))
      end)

      assert {:ok, product} = Product.create(minimal_creation_data, config: config)
      assert product.name == "Minimal Creation Product"
      # Server defaults
      assert product.type == "standard"
    end
  end

  describe "Product update request validation against OpenAPI spec" do
    setup do
      bypass = Bypass.open()
      config = create_bypass_config(bypass)
      {:ok, bypass: bypass, config: config}
    end

    test "validates partial update request schema", %{bypass: bypass, config: config} do
      # Partial update per OpenAPI spec - only changed fields
      update_params = %{
        name: "Updated Product Name",
        custom_data: %{
          "updated_at" => "2024-01-01T12:00:00Z",
          "version" => 2
        }
      }

      update_response = %{
        "data" => %{
          "id" => "pro_01gsz4t5hdjse780zja8vvr7jg",
          "name" => "Updated Product Name",
          # Unchanged
          "description" => "Original description unchanged",
          # Unchanged
          "type" => "standard",
          # Unchanged
          "tax_category" => "standard",
          # Unchanged
          "image_url" => nil,
          "custom_data" => %{
            "updated_at" => "2024-01-01T12:00:00Z",
            "version" => 2
          },
          # Unchanged
          "status" => "active",
          # Unchanged
          "created_at" => "2023-06-01T13:30:50.302Z",
          # Updated by server
          "updated_at" => "2024-01-01T12:00:00Z"
        }
      }

      Bypass.expect_once(bypass, "PATCH", "/products/pro_01gsz4t5hdjse780zja8vvr7jg", fn conn ->
        assert_valid_paddle_headers(conn)

        {:ok, body, conn} = Plug.Conn.read_body(conn)
        parsed_body = Jason.decode!(body)

        # Only changed fields should be in request body
        assert parsed_body["name"] == "Updated Product Name"
        assert is_map(parsed_body["custom_data"])
        assert parsed_body["custom_data"]["version"] == 2

        # Unchanged fields should not be present
        refute Map.has_key?(parsed_body, "type")
        refute Map.has_key?(parsed_body, "status")
        refute Map.has_key?(parsed_body, "created_at")

        Plug.Conn.resp(conn, 200, Jason.encode!(update_response))
      end)

      assert {:ok, product} =
               Product.update("pro_01gsz4t5hdjse780zja8vvr7jg", update_params, config: config)

      # Validate updated fields
      assert product.name == "Updated Product Name"
      assert product.custom_data["version"] == 2
      assert product.updated_at == "2024-01-01T12:00:00Z"
    end
  end

  describe "Product validation error responses per OpenAPI spec" do
    setup do
      bypass = Bypass.open()
      config = create_bypass_config(bypass)
      {:ok, bypass: bypass, config: config}
    end

    test "validates field validation error response format", %{bypass: bypass, config: config} do
      # Multiple field validation errors per OpenAPI spec
      validation_errors_response = %{
        "errors" => [
          %{
            "field" => "name",
            "code" => "required",
            "detail" => "Product name is required and cannot be empty"
          },
          %{
            "field" => "type",
            "code" => "invalid_choice",
            "detail" => "Product type must be one of: standard, service"
          },
          %{
            "field" => "image_url",
            "code" => "invalid_url",
            "detail" => "Image URL must be a valid HTTP or HTTPS URL"
          }
        ]
      }

      invalid_data = %{
        # Invalid - empty
        name: "",
        # Invalid - not in enum
        type: "invalid_type",
        # Invalid - malformed URL
        image_url: "not-a-url"
      }

      Bypass.expect_once(bypass, "POST", "/products", fn conn ->
        Plug.Conn.resp(conn, 400, Jason.encode!(validation_errors_response))
      end)

      assert {:error, %Error{type: :validation_error}} =
               Product.create(invalid_data, config: config)
    end

    test "validates single field validation error response", %{bypass: bypass, config: config} do
      # Single field validation error per OpenAPI spec
      single_validation_error = %{
        "errors" => [
          %{
            "field" => "name",
            "code" => "too_long",
            "detail" => "Product name cannot exceed 255 characters"
          }
        ]
      }

      long_name_data = %{
        # Too long
        name: String.duplicate("A", 300)
      }

      Bypass.expect_once(bypass, "POST", "/products", fn conn ->
        Plug.Conn.resp(conn, 400, Jason.encode!(single_validation_error))
      end)

      assert {:error, %Error{type: :validation_error}} =
               Product.create(long_name_data, config: config)
    end
  end

  describe "Product include parameter validation per OpenAPI spec" do
    setup do
      bypass = Bypass.open()
      config = create_bypass_config(bypass)
      {:ok, bypass: bypass, config: config}
    end

    test "validates include=prices parameter", %{bypass: bypass, config: config} do
      # Product with included prices per OpenAPI spec
      product_with_prices_response = %{
        "data" => %{
          "id" => "pro_01gsz4t5hdjse780zja8vvr7jg",
          "name" => "Product with Prices",
          "type" => "standard",
          "tax_category" => "standard",
          "status" => "active",
          "created_at" => "2023-06-01T13:30:50.302Z",
          "updated_at" => "2023-06-01T13:30:50.302Z",
          "prices" => [
            %{
              "id" => "pri_01gsz4t5hdjse780zja8vvr7jg",
              "description" => "Monthly price",
              "unit_price" => %{
                "amount" => "2400",
                "currency_code" => "USD"
              },
              "billing_cycle" => %{
                "interval" => "month",
                "frequency" => 1
              },
              "status" => "active"
            }
          ]
        }
      }

      Bypass.expect_once(bypass, "GET", "/products/pro_01gsz4t5hdjse780zja8vvr7jg", fn conn ->
        query_params = URI.decode_query(conn.query_string)

        # Validate include parameter format per OpenAPI spec
        assert query_params["include"] == "prices"

        Plug.Conn.resp(conn, 200, Jason.encode!(product_with_prices_response))
      end)

      assert {:ok, product} =
               Product.get("pro_01gsz4t5hdjse780zja8vvr7jg", %{include: ["prices"]},
                 config: config
               )

      # Validate that the request was made correctly with include parameter
      # Note: The actual handling of included data would need to be implemented
      # in the Product struct and parsing logic when include relationships are needed
      assert product.id == "pro_01gsz4t5hdjse780zja8vvr7jg"
    end
  end
end
