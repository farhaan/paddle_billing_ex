defmodule PaddleBilling.PricingPreview do
  @moduledoc """
  Preview pricing calculations in Paddle Billing.

  The pricing preview endpoint allows you to calculate totals, tax, and other
  pricing information before creating actual transactions or subscriptions.
  This is useful for showing pricing information to customers, building
  custom checkout flows, or calculating costs programmatically.
  """

  alias PaddleBilling.{Client, Error}

  @type t :: %__MODULE__{
          customer_id: String.t() | nil,
          address_id: String.t() | nil,
          business_id: String.t() | nil,
          currency_code: String.t(),
          discount_id: String.t() | nil,
          address: map() | nil,
          customer_ip_address: String.t() | nil,
          details: pricing_details(),
          available_payment_methods: [String.t()]
        }

  defstruct [
    :customer_id,
    :address_id,
    :business_id,
    :currency_code,
    :discount_id,
    :address,
    :customer_ip_address,
    :details,
    :available_payment_methods
  ]

  @type pricing_details :: %{
          line_items: [line_item()],
          totals: totals()
        }

  @type line_item :: %{
          price_id: String.t(),
          quantity: integer(),
          proration: map() | nil,
          tax_rate: String.t(),
          unit_totals: totals(),
          totals: totals(),
          product: map(),
          price: map()
        }

  @type totals :: %{
          subtotal: String.t(),
          discount: String.t(),
          tax: String.t(),
          total: String.t(),
          credit: String.t(),
          balance: String.t(),
          grand_total: String.t(),
          fee: String.t() | nil,
          earnings: String.t() | nil,
          currency_code: String.t()
        }

  @type preview_params :: %{
          :items => [preview_item()],
          optional(:customer_id) => String.t(),
          optional(:address_id) => String.t(),
          optional(:business_id) => String.t(),
          optional(:currency_code) => String.t(),
          optional(:discount_id) => String.t(),
          optional(:address) => address(),
          optional(:customer_ip_address) => String.t(),
          optional(:ignore_trials) => boolean(),
          optional(:include) => [String.t()]
        }

  @type preview_item :: %{
          :price_id => String.t(),
          :quantity => integer(),
          optional(:proration) => proration()
        }

  @type address :: %{
          optional(:description) => String.t(),
          optional(:first_line) => String.t(),
          optional(:second_line) => String.t(),
          optional(:city) => String.t(),
          optional(:postal_code) => String.t(),
          optional(:region) => String.t(),
          optional(:country_code) => String.t()
        }

  @type proration :: %{
          :rate => String.t(),
          :billing_period => billing_period()
        }

  @type billing_period :: %{
          :starts_at => String.t(),
          :ends_at => String.t()
        }

  @doc """
  Previews pricing for items.

  Calculate totals, tax, and other pricing information without creating
  actual transactions. This is useful for building custom checkout flows
  or displaying pricing information to customers.

  ## Parameters

  * `items` - Array of items to price (required)
  * `customer_id` - Customer ID for personalized pricing (optional)
  * `address_id` - Address ID for tax calculation (optional)
  * `business_id` - Business ID for tax calculation (optional)
  * `currency_code` - Currency code for pricing (optional)
  * `discount_id` - Discount ID to apply (optional)
  * `address` - Address information for tax calculation (optional)
  * `customer_ip_address` - Customer IP for geo-location tax (optional)
  * `ignore_trials` - Whether to ignore trial periods (optional)
  * `include` - Include additional data (optional)

  ## Examples

      # Basic pricing preview
      PaddleBilling.PricingPreview.preview(%{
        items: [
          %{
            price_id: "pri_123",
            quantity: 1
          }
        ]
      })
      {:ok, %PaddleBilling.PricingPreview{
        currency_code: "USD",
        details: %{
          line_items: [...],
          totals: %{
            subtotal: "1000",
            tax: "80",
            total: "1080",
            ...
          }
        }
      }}

      # Preview with customer context
      PaddleBilling.PricingPreview.preview(%{
        items: [
          %{
            price_id: "pri_123",
            quantity: 2
          },
          %{
            price_id: "pri_456", 
            quantity: 1
          }
        ],
        customer_id: "ctm_123",
        currency_code: "EUR"
      })
      {:ok, %PaddleBilling.PricingPreview{}}

      # Preview with address for tax calculation
      PaddleBilling.PricingPreview.preview(%{
        items: [
          %{
            price_id: "pri_123",
            quantity: 1
          }
        ],
        address: %{
          country_code: "GB",
          postal_code: "SW1A 1AA",
          city: "London"
        }
      })
      {:ok, %PaddleBilling.PricingPreview{}}

      # Preview with discount applied
      PaddleBilling.PricingPreview.preview(%{
        items: [
          %{
            price_id: "pri_123",
            quantity: 3
          }
        ],
        discount_id: "dsc_123",
        customer_ip_address: "192.168.1.1"
      })
      {:ok, %PaddleBilling.PricingPreview{}}

      # Preview with proration for subscription changes
      PaddleBilling.PricingPreview.preview(%{
        items: [
          %{
            price_id: "pri_annual",
            quantity: 1,
            proration: %{
              rate: "0.75",
              billing_period: %{
                starts_at: "2024-01-15T00:00:00Z",
                ends_at: "2024-02-01T00:00:00Z"
              }
            }
          }
        ],
        customer_id: "ctm_123"
      })
      {:ok, %PaddleBilling.PricingPreview{}}
  """
  @spec preview(preview_params(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def preview(params, opts \\ []) do
    case Client.post("/pricing-preview", params, opts) do
      {:ok, preview} when is_map(preview) ->
        {:ok, from_api(preview)}

      {:ok, response} ->
        {:error, Error.from_response(response)}

      error ->
        error
    end
  end

  @doc """
  Previews pricing for a single item.

  Convenience function for single-item pricing previews.

  ## Examples

      PaddleBilling.PricingPreview.preview_item("pri_123", 2)
      {:ok, %PaddleBilling.PricingPreview{}}

      PaddleBilling.PricingPreview.preview_item("pri_123", 1, %{
        customer_id: "ctm_123",
        currency_code: "GBP"
      })
      {:ok, %PaddleBilling.PricingPreview{}}
  """
  @spec preview_item(String.t(), integer(), map(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def preview_item(price_id, quantity, additional_params \\ %{}, opts \\ []) do
    params =
      Map.merge(
        %{
          items: [
            %{
              price_id: price_id,
              quantity: quantity
            }
          ]
        },
        additional_params
      )

    preview(params, opts)
  end

  @doc """
  Previews pricing with customer context.

  Convenience function for customer-specific pricing previews.

  ## Examples

      PaddleBilling.PricingPreview.preview_for_customer("ctm_123", [
        %{price_id: "pri_123", quantity: 1}
      ])
      {:ok, %PaddleBilling.PricingPreview{}}

      PaddleBilling.PricingPreview.preview_for_customer("ctm_123", [
        %{price_id: "pri_123", quantity: 2}
      ], %{currency_code: "CAD"})
      {:ok, %PaddleBilling.PricingPreview{}}
  """
  @spec preview_for_customer(String.t(), [preview_item()], map(), keyword()) ::
          {:ok, t()} | {:error, Error.t()}
  def preview_for_customer(customer_id, items, additional_params \\ %{}, opts \\ []) do
    params =
      Map.merge(
        %{
          items: items,
          customer_id: customer_id
        },
        additional_params
      )

    preview(params, opts)
  end

  @doc """
  Previews pricing with discount applied.

  Convenience function for discount-enabled pricing previews.

  ## Examples

      PaddleBilling.PricingPreview.preview_with_discount([
        %{price_id: "pri_123", quantity: 1}
      ], "dsc_123")
      {:ok, %PaddleBilling.PricingPreview{}}
  """
  @spec preview_with_discount([preview_item()], String.t(), map(), keyword()) ::
          {:ok, t()} | {:error, Error.t()}
  def preview_with_discount(items, discount_id, additional_params \\ %{}, opts \\ []) do
    params =
      Map.merge(
        %{
          items: items,
          discount_id: discount_id
        },
        additional_params
      )

    preview(params, opts)
  end

  @doc """
  Gets the total amount from a pricing preview.

  ## Examples

      {:ok, preview} = PaddleBilling.PricingPreview.preview(%{...})
      PaddleBilling.PricingPreview.get_total(preview)
      "1080"
  """
  @spec get_total(t()) :: String.t() | nil
  def get_total(%__MODULE__{details: %{totals: %{total: total}}}) when is_binary(total), do: total
  def get_total(%__MODULE__{}), do: nil

  @doc """
  Gets the grand total amount from a pricing preview.

  ## Examples

      {:ok, preview} = PaddleBilling.PricingPreview.preview(%{...})
      PaddleBilling.PricingPreview.get_grand_total(preview)
      "1080"
  """
  @spec get_grand_total(t()) :: String.t() | nil
  def get_grand_total(%__MODULE__{details: %{totals: %{grand_total: grand_total}}})
      when is_binary(grand_total),
      do: grand_total

  def get_grand_total(%__MODULE__{}), do: nil

  @doc """
  Gets the tax amount from a pricing preview.

  ## Examples

      {:ok, preview} = PaddleBilling.PricingPreview.preview(%{...})
      PaddleBilling.PricingPreview.get_tax(preview)
      "80"
  """
  @spec get_tax(t()) :: String.t() | nil
  def get_tax(%__MODULE__{details: %{totals: %{tax: tax}}}) when is_binary(tax), do: tax
  def get_tax(%__MODULE__{}), do: nil

  @doc """
  Gets the discount amount from a pricing preview.

  ## Examples

      {:ok, preview} = PaddleBilling.PricingPreview.preview(%{...})
      PaddleBilling.PricingPreview.get_discount(preview)
      "200"
  """
  @spec get_discount(t()) :: String.t() | nil
  def get_discount(%__MODULE__{details: %{totals: %{discount: discount}}})
      when is_binary(discount),
      do: discount

  def get_discount(%__MODULE__{}), do: nil

  @doc """
  Gets the subtotal amount from a pricing preview.

  ## Examples

      {:ok, preview} = PaddleBilling.PricingPreview.preview(%{...})
      PaddleBilling.PricingPreview.get_subtotal(preview)
      "1000"
  """
  @spec get_subtotal(t()) :: String.t() | nil
  def get_subtotal(%__MODULE__{details: %{totals: %{subtotal: subtotal}}})
      when is_binary(subtotal),
      do: subtotal

  def get_subtotal(%__MODULE__{}), do: nil

  @doc """
  Checks if a discount was applied in the preview.

  ## Examples

      {:ok, preview} = PaddleBilling.PricingPreview.preview(%{...})
      PaddleBilling.PricingPreview.has_discount?(preview)
      true
  """
  @spec has_discount?(t()) :: boolean()
  def has_discount?(%__MODULE__{discount_id: discount_id}) when is_binary(discount_id), do: true
  def has_discount?(%__MODULE__{}), do: false

  @doc """
  Gets the number of line items in the preview.

  ## Examples

      {:ok, preview} = PaddleBilling.PricingPreview.preview(%{...})
      PaddleBilling.PricingPreview.item_count(preview)
      2
  """
  @spec item_count(t()) :: integer()
  def item_count(%__MODULE__{details: %{line_items: items}}) when is_list(items),
    do: length(items)

  def item_count(%__MODULE__{}), do: 0

  # Private functions

  @spec from_api(map()) :: t()
  defp from_api(data) when is_map(data) do
    %__MODULE__{
      customer_id: Map.get(data, "customer_id"),
      address_id: Map.get(data, "address_id"),
      business_id: Map.get(data, "business_id"),
      currency_code: Map.get(data, "currency_code"),
      discount_id: Map.get(data, "discount_id"),
      address: Map.get(data, "address"),
      customer_ip_address: Map.get(data, "customer_ip_address"),
      details: Map.get(data, "details", %{}),
      available_payment_methods: ensure_list(Map.get(data, "available_payment_methods", []))
    }
  end

  @spec ensure_list(any()) :: [any()]
  defp ensure_list(nil), do: []
  defp ensure_list(list) when is_list(list), do: list
  defp ensure_list(_), do: []
end
