defmodule PaddleBilling.PricingPreviewTest do
  use ExUnit.Case, async: true
  alias PaddleBilling.{PricingPreview, Error}
  import PaddleBilling.TestHelpers

  setup do
    bypass = Bypass.open()
    config = create_bypass_config(bypass)
    {:ok, bypass: bypass, config: config}
  end

  describe "preview/2" do
    test "returns pricing preview", %{bypass: bypass, config: config} do
      preview_response = %{
        "customer_id" => "ctm_123",
        "currency_code" => "USD",
        "discount_id" => nil,
        "address" => nil,
        "customer_ip_address" => nil,
        "details" => %{
          "line_items" => [
            %{
              "price_id" => "pri_123",
              "quantity" => 2,
              "tax_rate" => "0.08",
              "unit_totals" => %{
                "subtotal" => "1000",
                "tax" => "80",
                "total" => "1080",
                "currency_code" => "USD"
              },
              "totals" => %{
                "subtotal" => "2000",
                "tax" => "160",
                "total" => "2160",
                "currency_code" => "USD"
              },
              "product" => %{"id" => "pro_456", "name" => "Premium Plan"},
              "price" => %{"id" => "pri_123", "description" => "Monthly Premium"}
            }
          ],
          "totals" => %{
            "subtotal" => "2000",
            "discount" => "0",
            "tax" => "160",
            "total" => "2160",
            "credit" => "0",
            "balance" => "0",
            "grand_total" => "2160",
            "currency_code" => "USD"
          }
        },
        "available_payment_methods" => ["card", "paypal"]
      }

      preview_params = %{
        items: [
          %{
            price_id: "pri_123",
            quantity: 2
          }
        ],
        customer_id: "ctm_123"
      }

      Bypass.expect(bypass, "POST", "/pricing-preview", fn conn ->
        {:ok, body, _} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)

        assert params["customer_id"] == "ctm_123"
        assert length(params["items"]) == 1
        assert List.first(params["items"])["price_id"] == "pri_123"
        assert List.first(params["items"])["quantity"] == 2

        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(200, Jason.encode!(preview_response))
      end)

      assert {:ok, preview} = PricingPreview.preview(preview_params, config: config)
      assert preview.customer_id == "ctm_123"
      assert preview.currency_code == "USD"
      assert preview.details["totals"]["total"] == "2160"
      assert length(preview.available_payment_methods) == 2
    end

    test "handles validation errors", %{bypass: bypass, config: config} do
      setup_error_response(bypass, "POST", "/pricing-preview", 400, %{
        "error" => %{
          "code" => "validation_failed",
          "detail" => "Items cannot be empty"
        }
      })

      params = %{
        items: []
      }

      assert {:error, %Error{type: :validation_error}} =
               PricingPreview.preview(params, config: config)
    end

    test "supports all preview parameters", %{bypass: bypass, config: config} do
      preview_params = %{
        items: [
          %{
            price_id: "pri_123",
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
        address_id: "add_456",
        business_id: "biz_789",
        currency_code: "EUR",
        discount_id: "dsc_123",
        address: %{
          country_code: "GB",
          postal_code: "SW1A 1AA",
          city: "London"
        },
        customer_ip_address: "192.168.1.1",
        ignore_trials: true,
        include: ["tax_rate"]
      }

      Bypass.expect(bypass, "POST", "/pricing-preview", fn conn ->
        {:ok, body, _} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)

        assert params["customer_id"] == "ctm_123"
        assert params["address_id"] == "add_456"
        assert params["business_id"] == "biz_789"
        assert params["currency_code"] == "EUR"
        assert params["discount_id"] == "dsc_123"
        assert params["address"]["country_code"] == "GB"
        assert params["customer_ip_address"] == "192.168.1.1"
        assert params["ignore_trials"] == true
        assert params["include"] == ["tax_rate"]

        item = List.first(params["items"])
        assert item["proration"]["rate"] == "0.5"

        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "currency_code" => "EUR",
            "details" => %{"totals" => %{}, "line_items" => []},
            "available_payment_methods" => []
          })
        )
      end)

      assert {:ok, _preview} = PricingPreview.preview(preview_params, config: config)
    end
  end

  describe "preview_item/4" do
    test "previews single item", %{bypass: bypass, config: config} do
      Bypass.expect(bypass, "POST", "/pricing-preview", fn conn ->
        {:ok, body, _} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)

        assert length(params["items"]) == 1
        item = List.first(params["items"])
        assert item["price_id"] == "pri_123"
        assert item["quantity"] == 3

        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "currency_code" => "USD",
            "details" => %{"totals" => %{}, "line_items" => []},
            "available_payment_methods" => []
          })
        )
      end)

      assert {:ok, _preview} = PricingPreview.preview_item("pri_123", 3, %{}, config: config)
    end

    test "supports additional parameters", %{bypass: bypass, config: config} do
      Bypass.expect(bypass, "POST", "/pricing-preview", fn conn ->
        {:ok, body, _} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)

        assert params["customer_id"] == "ctm_456"
        assert params["currency_code"] == "GBP"

        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "currency_code" => "GBP",
            "details" => %{"totals" => %{}, "line_items" => []},
            "available_payment_methods" => []
          })
        )
      end)

      additional_params = %{
        customer_id: "ctm_456",
        currency_code: "GBP"
      }

      assert {:ok, _preview} =
               PricingPreview.preview_item("pri_123", 1, additional_params, config: config)
    end
  end

  describe "preview_for_customer/4" do
    test "previews with customer context", %{bypass: bypass, config: config} do
      items = [
        %{price_id: "pri_123", quantity: 1},
        %{price_id: "pri_456", quantity: 2}
      ]

      Bypass.expect(bypass, "POST", "/pricing-preview", fn conn ->
        {:ok, body, _} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)

        assert params["customer_id"] == "ctm_789"
        assert length(params["items"]) == 2

        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "customer_id" => "ctm_789",
            "currency_code" => "USD",
            "details" => %{"totals" => %{}, "line_items" => []},
            "available_payment_methods" => []
          })
        )
      end)

      assert {:ok, preview} =
               PricingPreview.preview_for_customer("ctm_789", items, %{}, config: config)

      assert preview.customer_id == "ctm_789"
    end
  end

  describe "preview_with_discount/4" do
    test "previews with discount applied", %{bypass: bypass, config: config} do
      items = [
        %{price_id: "pri_123", quantity: 1}
      ]

      Bypass.expect(bypass, "POST", "/pricing-preview", fn conn ->
        {:ok, body, _} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)

        assert params["discount_id"] == "dsc_123"
        assert length(params["items"]) == 1

        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(
          200,
          Jason.encode!(%{
            "discount_id" => "dsc_123",
            "currency_code" => "USD",
            "details" => %{"totals" => %{"discount" => "200"}, "line_items" => []},
            "available_payment_methods" => []
          })
        )
      end)

      assert {:ok, preview} =
               PricingPreview.preview_with_discount(items, "dsc_123", %{}, config: config)

      assert preview.discount_id == "dsc_123"
    end
  end

  describe "helper functions" do
    setup do
      preview = %PricingPreview{
        customer_id: "ctm_123",
        discount_id: "dsc_456",
        details: %{
          totals: %{
            subtotal: "1000",
            discount: "200",
            tax: "80",
            total: "880",
            grand_total: "880"
          },
          line_items: [
            %{"price_id" => "pri_123"},
            %{"price_id" => "pri_456"}
          ]
        }
      }

      {:ok, preview: preview}
    end

    test "get_total/1", %{preview: preview} do
      assert PricingPreview.get_total(preview) == "880"

      empty_preview = %PricingPreview{}
      assert PricingPreview.get_total(empty_preview) == nil
    end

    test "get_grand_total/1", %{preview: preview} do
      assert PricingPreview.get_grand_total(preview) == "880"

      empty_preview = %PricingPreview{}
      assert PricingPreview.get_grand_total(empty_preview) == nil
    end

    test "get_tax/1", %{preview: preview} do
      assert PricingPreview.get_tax(preview) == "80"

      empty_preview = %PricingPreview{}
      assert PricingPreview.get_tax(empty_preview) == nil
    end

    test "get_discount/1", %{preview: preview} do
      assert PricingPreview.get_discount(preview) == "200"

      empty_preview = %PricingPreview{}
      assert PricingPreview.get_discount(empty_preview) == nil
    end

    test "get_subtotal/1", %{preview: preview} do
      assert PricingPreview.get_subtotal(preview) == "1000"

      empty_preview = %PricingPreview{}
      assert PricingPreview.get_subtotal(empty_preview) == nil
    end

    test "has_discount?/1", %{preview: preview} do
      assert PricingPreview.has_discount?(preview) == true

      no_discount = %PricingPreview{discount_id: nil}
      assert PricingPreview.has_discount?(no_discount) == false
    end

    test "item_count/1", %{preview: preview} do
      assert PricingPreview.item_count(preview) == 2

      empty_preview = %PricingPreview{}
      assert PricingPreview.item_count(empty_preview) == 0
    end
  end
end
