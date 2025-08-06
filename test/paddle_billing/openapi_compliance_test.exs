defmodule PaddleBilling.OpenApiComplianceTest do
  @moduledoc """
  Tests to ensure PaddleBilling client complies with Paddle's official OpenAPI specification.

  Based on: https://github.com/PaddleHQ/paddle-openapi/blob/main/v1/openapi.yaml

  These tests validate:
  - Request format compliance
  - Response schema validation
  - Authentication header requirements
  - Error response formats
  - HTTP status code handling
  - Query parameter formats
  """

  use ExUnit.Case, async: true
  import PaddleBilling.TestHelpers

  alias PaddleBilling.{Product, Error}

  describe "OpenAPI authentication compliance" do
    setup do
      bypass = Bypass.open()
      config = create_bypass_config(bypass)
      {:ok, bypass: bypass, config: config}
    end

    test "sends required authentication headers", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/products", fn conn ->
        # Validate OpenAPI required headers
        headers = Enum.into(conn.req_headers, %{})

        # Bearer token authentication
        assert headers["authorization"] == "Bearer pdl_test_123456789"

        # API version header (required by OpenAPI spec)
        assert headers["paddle-version"] == "1"

        # Content negotiation headers
        assert headers["accept"] == "application/json"
        assert headers["content-type"] == "application/json"

        # User agent identification
        assert headers["user-agent"] == "paddle_billing_ex/0.1.0 (Elixir)"

        Plug.Conn.resp(conn, 200, Jason.encode!(%{"data" => []}))
      end)

      {:ok, _products} = Product.list(%{}, config: config)
    end

    test "handles authentication errors per OpenAPI spec", %{bypass: bypass, config: config} do
      # OpenAPI spec error format for 401 responses
      auth_error_response = %{
        "error" => %{
          "type" => "request_error",
          "code" => "authentication_failed",
          "detail" => "Authentication credentials are not valid for this request.",
          "documentation_url" => "https://developer.paddle.com/errors/authentication-failed"
        }
      }

      Bypass.expect_once(bypass, "GET", "/products", fn conn ->
        Plug.Conn.resp(conn, 401, Jason.encode!(auth_error_response))
      end)

      assert {:error, %Error{type: :authentication_error}} = Product.list(%{}, config: config)
    end

    test "handles authorization errors per OpenAPI spec", %{bypass: bypass, config: config} do
      # OpenAPI spec error format for 403 responses  
      auth_error_response = %{
        "error" => %{
          "type" => "request_error",
          "code" => "forbidden",
          "detail" => "You do not have permission to access this resource.",
          "documentation_url" => "https://developer.paddle.com/errors/forbidden"
        }
      }

      Bypass.expect_once(bypass, "GET", "/products", fn conn ->
        Plug.Conn.resp(conn, 403, Jason.encode!(auth_error_response))
      end)

      assert {:error, %Error{type: :authorization_error}} = Product.list(%{}, config: config)
    end
  end

  describe "OpenAPI response format compliance" do
    setup do
      bypass = Bypass.open()
      config = create_bypass_config(bypass)
      {:ok, bypass: bypass, config: config}
    end

    test "validates successful list response format", %{bypass: bypass, config: config} do
      # OpenAPI specification for successful list response
      openapi_list_response = %{
        "data" => [
          %{
            "id" => "pro_01gsz4t5hdjse780zja8vvr7jg",
            "name" => "Test Product",
            "description" => "A test product for OpenAPI compliance",
            "type" => "standard",
            "tax_category" => "standard",
            "image_url" => nil,
            "custom_data" => %{"test" => true},
            "status" => "active",
            "created_at" => "2023-06-01T13:30:50.302Z",
            "updated_at" => "2023-06-01T13:30:50.302Z",
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

      Bypass.expect_once(bypass, "GET", "/products", fn conn ->
        Plug.Conn.resp(conn, 200, Jason.encode!(openapi_list_response))
      end)

      assert {:ok, products} = Product.list(%{}, config: config)
      assert length(products) == 1

      product = hd(products)
      # Validate product follows OpenAPI schema
      assert product.id == "pro_01gsz4t5hdjse780zja8vvr7jg"
      assert product.name == "Test Product"
      assert product.type == "standard"
      assert product.status == "active"
      assert product.custom_data == %{"test" => true}
    end

    test "validates successful single resource response format", %{bypass: bypass, config: config} do
      # OpenAPI specification for successful single resource response
      openapi_single_response = %{
        "data" => %{
          "id" => "pro_01gsz4t5hdjse780zja8vvr7jg",
          "name" => "Single Product",
          "description" => "A single product response",
          "type" => "standard",
          "tax_category" => "standard",
          "image_url" => "https://example.com/image.jpg",
          "custom_data" => %{"category" => "electronics"},
          "status" => "active",
          "created_at" => "2023-06-01T13:30:50.302Z",
          "updated_at" => "2023-06-01T14:15:30.123Z",
          "import_meta" => nil
        },
        "meta" => %{
          "request_id" => "req_01gsz4t5hdjse780zja8vvr7jg"
        }
      }

      Bypass.expect_once(bypass, "GET", "/products/pro_01gsz4t5hdjse780zja8vvr7jg", fn conn ->
        Plug.Conn.resp(conn, 200, Jason.encode!(openapi_single_response))
      end)

      assert {:ok, product} = Product.get("pro_01gsz4t5hdjse780zja8vvr7jg", %{}, config: config)

      # Validate product follows OpenAPI schema
      assert product.id == "pro_01gsz4t5hdjse780zja8vvr7jg"
      assert product.name == "Single Product"
      assert product.image_url == "https://example.com/image.jpg"
      assert product.custom_data == %{"category" => "electronics"}
    end

    test "validates creation response format", %{bypass: bypass, config: config} do
      product_data = generate_test_product_data(name: "Created Product")

      # OpenAPI specification for creation response (201 status)
      openapi_create_response = %{
        "data" => %{
          "id" => "pro_01gsz4t5hdjse780zja8vvr7jg",
          "name" => "Created Product",
          "description" => "A test product for unit testing",
          "type" => "standard",
          "tax_category" => "standard",
          "image_url" => nil,
          "custom_data" => %{
            "test" => true,
            "generated_at" => "2024-01-01T12:00:00Z"
          },
          "status" => "active",
          "created_at" => "2023-06-01T13:30:50.302Z",
          "updated_at" => "2023-06-01T13:30:50.302Z",
          "import_meta" => nil
        },
        "meta" => %{
          "request_id" => "req_01gsz4t5hdjse780zja8vvr7jg"
        }
      }

      Bypass.expect_once(bypass, "POST", "/products", fn conn ->
        # Validate request body format
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        parsed_body = Jason.decode!(body)

        # Ensure request follows OpenAPI schema
        assert is_binary(parsed_body["name"])
        assert is_binary(parsed_body["description"])
        assert parsed_body["type"] == "standard"
        assert is_map(parsed_body["custom_data"])

        Plug.Conn.resp(conn, 201, Jason.encode!(openapi_create_response))
      end)

      assert {:ok, product} = Product.create(product_data, config: config)
      assert product.id == "pro_01gsz4t5hdjse780zja8vvr7jg"
      assert product.name == "Created Product"
    end
  end

  describe "OpenAPI error response compliance" do
    setup do
      bypass = Bypass.open()
      config = create_bypass_config(bypass)
      {:ok, bypass: bypass, config: config}
    end

    test "validates validation error response format", %{bypass: bypass, config: config} do
      # OpenAPI specification for validation errors (400 status)
      validation_error_response = %{
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
          }
        ]
      }

      Bypass.expect_once(bypass, "POST", "/products", fn conn ->
        Plug.Conn.resp(conn, 400, Jason.encode!(validation_error_response))
      end)

      assert {:error, %Error{type: :validation_error}} =
               Product.create(%{}, config: config)
    end

    test "validates rate limit error response format", %{bypass: bypass, config: config} do
      # OpenAPI specification for rate limit errors (429 status)
      rate_limit_error_response = %{
        "error" => %{
          "type" => "api_error",
          "code" => "rate_limit_exceeded",
          "detail" => "Rate limit exceeded. Try again in 60 seconds.",
          "documentation_url" => "https://developer.paddle.com/errors/rate-limit-exceeded"
        }
      }

      Bypass.expect_once(bypass, "GET", "/products", fn conn ->
        conn
        |> Plug.Conn.put_resp_header("retry-after", "60")
        |> Plug.Conn.resp(429, Jason.encode!(rate_limit_error_response))
      end)

      assert {:error, %Error{type: :rate_limit_error}} = Product.list(%{}, config: config)
    end

    test "validates server error response format", %{bypass: bypass, config: config} do
      # OpenAPI specification for server errors (500 status)
      server_error_response = %{
        "error" => %{
          "type" => "api_error",
          "code" => "internal_error",
          "detail" => "An internal error occurred. Please try again later.",
          "documentation_url" => "https://developer.paddle.com/errors/internal-error"
        }
      }

      Bypass.expect_once(bypass, "GET", "/products", fn conn ->
        Plug.Conn.resp(conn, 500, Jason.encode!(server_error_response))
      end)

      assert {:error, %Error{type: :server_error}} = Product.list(%{}, config: config)
    end

    test "validates not found error response format", %{bypass: bypass, config: config} do
      # OpenAPI specification for not found errors (404 status)
      not_found_error_response = %{
        "error" => %{
          "type" => "request_error",
          "code" => "entity_not_found",
          "detail" => "Unable to find the requested product.",
          "documentation_url" => "https://developer.paddle.com/errors/entity-not-found"
        }
      }

      Bypass.expect_once(bypass, "GET", "/products/pro_nonexistent", fn conn ->
        Plug.Conn.resp(conn, 404, Jason.encode!(not_found_error_response))
      end)

      assert {:error, %Error{type: :not_found_error}} =
               Product.get("pro_nonexistent", %{}, config: config)
    end
  end

  describe "OpenAPI query parameter compliance" do
    setup do
      bypass = Bypass.open()
      config = create_bypass_config(bypass)
      {:ok, bypass: bypass, config: config}
    end

    test "validates pagination query parameters", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/products", fn conn ->
        query_params = URI.decode_query(conn.query_string)

        # Validate OpenAPI pagination parameters
        assert query_params["per_page"] == "25"
        assert query_params["after"] == "pro_01gsz4t5hdjse780zja8vvr7jg"

        paginated_response = %{
          "data" => [],
          "meta" => %{
            "request_id" => "req_01gsz4t5hdjse780zja8vvr7jg",
            "pagination" => %{
              "per_page" => 25,
              "next" => "https://api.paddle.com/products?after=pro_next_id",
              "has_more" => true,
              "estimated_total" => 150
            }
          }
        }

        Plug.Conn.resp(conn, 200, Jason.encode!(paginated_response))
      end)

      assert {:ok, _products} =
               Product.list(
                 %{
                   per_page: 25,
                   after: "pro_01gsz4t5hdjse780zja8vvr7jg"
                 },
                 config: config
               )
    end

    test "validates filtering query parameters", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/products", fn conn ->
        query_params = URI.decode_query(conn.query_string)

        # Validate OpenAPI filtering parameters
        assert query_params["id"] == "pro_123,pro_456"
        assert query_params["status"] == "active,archived"
        assert query_params["include"] == "prices"

        Plug.Conn.resp(conn, 200, Jason.encode!(%{"data" => []}))
      end)

      assert {:ok, _products} =
               Product.list(
                 %{
                   id: ["pro_123", "pro_456"],
                   status: ["active", "archived"],
                   include: ["prices"]
                 },
                 config: config
               )
    end

    test "validates search and ordering parameters", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/products", fn conn ->
        query_params = URI.decode_query(conn.query_string)

        # Validate OpenAPI search/ordering parameters
        assert query_params["order_by"] == "name[ASC]"

        Plug.Conn.resp(conn, 200, Jason.encode!(%{"data" => []}))
      end)

      assert {:ok, _products} =
               Product.list(
                 %{
                   order_by: "name[ASC]"
                 },
                 config: config
               )
    end
  end

  describe "OpenAPI request body compliance" do
    setup do
      bypass = Bypass.open()
      config = create_bypass_config(bypass)
      {:ok, bypass: bypass, config: config}
    end

    test "validates product creation request schema", %{bypass: bypass, config: config} do
      # Test all OpenAPI fields for product creation
      complete_product_data = %{
        name: "Complete Product",
        description: "A product with all possible fields",
        type: "standard",
        tax_category: "standard",
        image_url: "https://example.com/product.jpg",
        custom_data: %{
          "category" => "electronics",
          "weight" => 1.5,
          "dimensions" => %{
            "length" => 10,
            "width" => 5,
            "height" => 2
          }
        }
      }

      Bypass.expect_once(bypass, "POST", "/products", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        parsed_body = Jason.decode!(body)

        # Validate all fields are properly serialized per OpenAPI schema
        assert parsed_body["name"] == "Complete Product"
        assert parsed_body["description"] == "A product with all possible fields"
        assert parsed_body["type"] == "standard"
        assert parsed_body["tax_category"] == "standard"
        assert parsed_body["image_url"] == "https://example.com/product.jpg"
        assert is_map(parsed_body["custom_data"])
        assert parsed_body["custom_data"]["category"] == "electronics"
        assert parsed_body["custom_data"]["weight"] == 1.5
        assert is_map(parsed_body["custom_data"]["dimensions"])

        response = %{
          "data" => %{
            "id" => "pro_complete",
            "name" => parsed_body["name"],
            "status" => "active",
            "created_at" => "2023-06-01T13:30:50.302Z",
            "updated_at" => "2023-06-01T13:30:50.302Z"
          }
        }

        Plug.Conn.resp(conn, 201, Jason.encode!(response))
      end)

      assert {:ok, product} = Product.create(complete_product_data, config: config)
      assert product.id == "pro_complete"
    end

    test "validates product update request schema", %{bypass: bypass, config: config} do
      # Test partial update per OpenAPI schema
      update_params = %{
        name: "Updated Product Name",
        description: "Updated description",
        custom_data: %{
          "updated" => true,
          "update_time" => "2024-01-01T15:30:00Z"
        }
      }

      Bypass.expect_once(bypass, "PATCH", "/products/pro_update", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        parsed_body = Jason.decode!(body)

        # Validate partial update fields per OpenAPI schema
        assert parsed_body["name"] == "Updated Product Name"
        assert parsed_body["description"] == "Updated description"
        assert is_map(parsed_body["custom_data"])
        assert parsed_body["custom_data"]["updated"] == true

        response = %{
          "data" => %{
            "id" => "pro_update",
            "name" => parsed_body["name"],
            "description" => parsed_body["description"],
            "custom_data" => parsed_body["custom_data"],
            "status" => "active",
            "created_at" => "2023-06-01T13:30:50.302Z",
            "updated_at" => "2024-01-01T15:30:00Z"
          }
        }

        Plug.Conn.resp(conn, 200, Jason.encode!(response))
      end)

      assert {:ok, product} = Product.update("pro_update", update_params, config: config)
      assert product.name == "Updated Product Name"
      assert product.custom_data["updated"] == true
    end
  end

  describe "OpenAPI ID format validation" do
    setup do
      bypass = Bypass.open()
      config = create_bypass_config(bypass)
      {:ok, bypass: bypass, config: config}
    end

    test "validates Paddle ID format in responses", %{bypass: bypass, config: config} do
      # Test various valid Paddle ID formats per OpenAPI spec
      valid_ids = [
        # Standard format
        "pro_01gsz4t5hdjse780zja8vvr7jg",
        # 26 characters after prefix
        "pro_01h1234567890abcdefghijkl",
        # Different character set
        "pro_01abcdefghijklmnopqrstuvwx"
      ]

      for {product_id, index} <- Enum.with_index(valid_ids) do
        Bypass.expect_once(bypass, "GET", "/products/#{product_id}", fn conn ->
          response = %{
            "data" => %{
              "id" => product_id,
              "name" => "Product #{index}",
              "status" => "active",
              "created_at" => "2023-06-01T13:30:50.302Z",
              "updated_at" => "2023-06-01T13:30:50.302Z"
            }
          }

          Plug.Conn.resp(conn, 200, Jason.encode!(response))
        end)

        assert {:ok, product} = Product.get(product_id, %{}, config: config)

        # Validate ID format matches OpenAPI specification
        assert String.starts_with?(product.id, "pro_")
        # "pro_" + at least 25 characters
        assert String.length(product.id) >= 29
        assert Regex.match?(~r/^pro_[0-9a-z]{25,}$/, product.id)
      end
    end
  end

  describe "OpenAPI timestamp format validation" do
    setup do
      bypass = Bypass.open()
      config = create_bypass_config(bypass)
      {:ok, bypass: bypass, config: config}
    end

    test "validates ISO 8601 timestamp format", %{bypass: bypass, config: config} do
      # Test various valid ISO 8601 formats per OpenAPI spec
      valid_timestamps = [
        # With milliseconds and Z
        "2023-06-01T13:30:50.302Z",
        # Without milliseconds
        "2023-06-01T13:30:50Z",
        # Edge case timestamp
        "2023-12-31T23:59:59.999Z",
        # Boundary timestamp
        "2024-01-01T00:00:00.000Z"
      ]

      for {timestamp, index} <- Enum.with_index(valid_timestamps) do
        Bypass.expect_once(bypass, "GET", "/products/pro_timestamp_#{index}", fn conn ->
          response = %{
            "data" => %{
              "id" => "pro_timestamp_#{index}",
              "name" => "Timestamp Test #{index}",
              "status" => "active",
              "created_at" => timestamp,
              "updated_at" => timestamp
            }
          }

          Plug.Conn.resp(conn, 200, Jason.encode!(response))
        end)

        assert {:ok, product} = Product.get("pro_timestamp_#{index}", %{}, config: config)

        # Validate timestamp format (OpenAPI spec requires ISO 8601)
        assert product.created_at == timestamp
        assert product.updated_at == timestamp

        # Verify it's a valid ISO 8601 format
        assert Regex.match?(
                 ~r/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{3})?Z$/,
                 product.created_at
               )
      end
    end
  end
end
