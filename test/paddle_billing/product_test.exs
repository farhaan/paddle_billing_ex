defmodule PaddleBilling.ProductTest do
  use ExUnit.Case, async: true

  alias PaddleBilling.{Product, Error}

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

  describe "list/1" do
    test "returns list of products", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/products", fn conn ->
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer pdl_test_123456789"]
        assert Plug.Conn.get_req_header(conn, "paddle-version") == ["1"]

        Plug.Conn.resp(
          conn,
          200,
          Jason.encode!(%{
            "data" => [
              %{
                "id" => "pro_123",
                "name" => "Test Product",
                "description" => "A test product",
                "type" => "standard",
                "tax_category" => "standard",
                "status" => "active",
                "created_at" => "2025-01-01T00:00:00Z",
                "updated_at" => "2025-01-01T00:00:00Z"
              }
            ]
          })
        )
      end)

      assert {:ok, [product]} = Product.list(%{}, config: config)
      assert %Product{} = product
      assert product.id == "pro_123"
      assert product.name == "Test Product"
      assert product.description == "A test product"
      assert product.type == "standard"
      assert product.status == "active"
    end

    test "handles API errors", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/products", fn conn ->
        Plug.Conn.resp(
          conn,
          401,
          Jason.encode!(%{
            "error" => %{
              "code" => "authentication_failed",
              "detail" => "Invalid API key"
            }
          })
        )
      end)

      assert {:error, %Error{} = error} = Product.list(%{}, config: config)
      assert error.type == :authentication_error
      assert error.code == "authentication_failed"
      assert error.message == "Invalid API key"
    end
  end

  describe "get/2" do
    test "returns a single product", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/products/pro_123", fn conn ->
        Plug.Conn.resp(
          conn,
          200,
          Jason.encode!(%{
            "data" => %{
              "id" => "pro_123",
              "name" => "Test Product",
              "description" => "A test product",
              "type" => "standard",
              "tax_category" => "standard",
              "status" => "active",
              "created_at" => "2025-01-01T00:00:00Z",
              "updated_at" => "2025-01-01T00:00:00Z"
            }
          })
        )
      end)

      assert {:ok, product} = Product.get("pro_123", %{}, config: config)
      assert %Product{} = product
      assert product.id == "pro_123"
      assert product.name == "Test Product"
    end

    test "handles not found error", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "GET", "/products/invalid", fn conn ->
        Plug.Conn.resp(
          conn,
          404,
          Jason.encode!(%{
            "error" => %{
              "code" => "product_not_found",
              "detail" => "Product not found"
            }
          })
        )
      end)

      assert {:error, %Error{} = error} = Product.get("invalid", %{}, config: config)
      assert error.message == "Product not found"
    end
  end

  describe "create/1" do
    test "creates a new product", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "POST", "/products", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)

        assert params["name"] == "New Product"
        assert params["description"] == "A new product"
        assert params["type"] == "standard"

        Plug.Conn.resp(
          conn,
          201,
          Jason.encode!(%{
            "data" => %{
              "id" => "pro_new",
              "name" => "New Product",
              "description" => "A new product",
              "type" => "standard",
              "tax_category" => "standard",
              "status" => "active",
              "created_at" => "2025-01-01T00:00:00Z",
              "updated_at" => "2025-01-01T00:00:00Z"
            }
          })
        )
      end)

      params = %{
        name: "New Product",
        description: "A new product",
        type: "standard"
      }

      assert {:ok, product} = Product.create(params, config: config)
      assert product.id == "pro_new"
      assert product.name == "New Product"
    end

    test "handles validation errors", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "POST", "/products", fn conn ->
        Plug.Conn.resp(
          conn,
          400,
          Jason.encode!(%{
            "errors" => [
              %{
                "field" => "name",
                "code" => "required",
                "detail" => "Name is required"
              }
            ]
          })
        )
      end)

      assert {:error, %Error{} = error} = Product.create(%{}, config: config)
      assert error.type == :validation_error
      assert String.contains?(error.message, "name: Name is required")
    end
  end

  describe "update/2" do
    test "updates an existing product", %{bypass: bypass, config: config} do
      Bypass.expect_once(bypass, "PATCH", "/products/pro_123", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)

        assert params["name"] == "Updated Product"

        Plug.Conn.resp(
          conn,
          200,
          Jason.encode!(%{
            "data" => %{
              "id" => "pro_123",
              "name" => "Updated Product",
              "description" => "A test product",
              "type" => "standard",
              "tax_category" => "standard",
              "status" => "active",
              "created_at" => "2025-01-01T00:00:00Z",
              "updated_at" => "2025-01-01T01:00:00Z"
            }
          })
        )
      end)

      assert {:ok, product} =
               Product.update("pro_123", %{name: "Updated Product"}, config: config)

      assert product.name == "Updated Product"
    end
  end
end
