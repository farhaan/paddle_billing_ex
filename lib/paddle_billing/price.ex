defmodule PaddleBilling.Price do
  @moduledoc """
  Manage prices in Paddle Billing.

  Prices represent the cost of a product. They include information like billing cycles,
  currencies, tax handling, and trial periods. Prices are linked to products and used
  to create subscriptions and transactions.
  """

  alias PaddleBilling.{Client, Error}

  @type t :: %__MODULE__{
          id: String.t(),
          description: String.t() | nil,
          product_id: String.t(),
          name: String.t() | nil,
          type: String.t(),
          billing_cycle: map() | nil,
          trial_period: map() | nil,
          tax_mode: String.t(),
          unit_price: map(),
          unit_price_overrides: [map()] | nil,
          quantity: map() | nil,
          custom_data: map() | nil,
          status: String.t(),
          created_at: String.t(),
          updated_at: String.t(),
          import_meta: map() | nil
        }

  defstruct [
    :id,
    :description,
    :product_id,
    :name,
    :type,
    :billing_cycle,
    :trial_period,
    :tax_mode,
    :unit_price,
    :unit_price_overrides,
    :quantity,
    :custom_data,
    :status,
    :created_at,
    :updated_at,
    :import_meta
  ]

  @type list_params :: %{
          optional(:after) => String.t(),
          optional(:id) => [String.t()],
          optional(:product_id) => [String.t()],
          optional(:status) => [String.t()],
          optional(:type) => [String.t()],
          optional(:per_page) => pos_integer(),
          optional(:include) => [String.t()],
          optional(:recurring) => boolean()
        }

  @type create_params :: %{
          :product_id => String.t(),
          optional(:description) => String.t(),
          optional(:name) => String.t(),
          optional(:type) => String.t(),
          optional(:billing_cycle) => billing_cycle(),
          optional(:trial_period) => trial_period(),
          optional(:tax_mode) => String.t(),
          optional(:unit_price) => unit_price(),
          optional(:unit_price_overrides) => [unit_price_override()],
          optional(:quantity) => quantity(),
          optional(:custom_data) => map()
        }

  @type update_params :: %{
          optional(:description) => String.t(),
          optional(:name) => String.t(),
          optional(:billing_cycle) => billing_cycle(),
          optional(:trial_period) => trial_period(),
          optional(:tax_mode) => String.t(),
          optional(:unit_price) => unit_price(),
          optional(:unit_price_overrides) => [unit_price_override()],
          optional(:quantity) => quantity(),
          optional(:custom_data) => map(),
          optional(:status) => String.t()
        }

  @type billing_cycle :: %{
          :interval => String.t(),
          :frequency => pos_integer()
        }

  @type trial_period :: %{
          :interval => String.t(),
          :frequency => pos_integer()
        }

  @type unit_price :: %{
          :amount => String.t(),
          :currency_code => String.t()
        }

  @type unit_price_override :: %{
          :country_codes => [String.t()],
          :unit_price => unit_price()
        }

  @type quantity :: %{
          :minimum => pos_integer(),
          :maximum => pos_integer()
        }

  @doc """
  Lists all prices.

  ## Parameters

  * `:after` - Return prices after this price ID (pagination)
  * `:id` - Filter by specific price IDs
  * `:product_id` - Filter by product IDs
  * `:status` - Filter by status (active, archived)
  * `:type` - Filter by type (standard, custom)
  * `:per_page` - Number of results per page (max 200)
  * `:include` - Include related resources (product)
  * `:recurring` - Filter by recurring prices (true/false)

  ## Examples

      PaddleBilling.Price.list()
      {:ok, [%PaddleBilling.Price{}, ...]}

      PaddleBilling.Price.list(%{
        product_id: ["pro_123"],
        status: ["active"],
        include: ["product"],
        per_page: 50
      })
      {:ok, [%PaddleBilling.Price{}, ...]}

      # Filter by recurring prices only
      PaddleBilling.Price.list(%{recurring: true})
      {:ok, [%PaddleBilling.Price{billing_cycle: %{...}}, ...]}
  """
  @spec list(list_params(), keyword()) :: {:ok, [t()]} | {:error, Error.t()}
  def list(params \\ %{}, opts \\ []) do
    case Client.get("/prices", params, opts) do
      {:ok, prices} when is_list(prices) ->
        {:ok, Enum.map(prices, &from_api/1)}

      {:ok, response} ->
        {:error, Error.from_response(response)}

      error ->
        error
    end
  end

  @doc """
  Gets a price by ID.

  ## Parameters

  * `:include` - Include related resources (product)

  ## Examples

      PaddleBilling.Price.get("pri_123")
      {:ok, %PaddleBilling.Price{id: "pri_123", product_id: "pro_456"}}

      PaddleBilling.Price.get("pri_123", %{include: ["product"]})
      {:ok, %PaddleBilling.Price{}}

      PaddleBilling.Price.get("invalid_id")
      {:error, %PaddleBilling.Error{type: :not_found_error}}
  """
  @spec get(String.t(), map(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def get(id, params \\ %{}, opts \\ []) do
    case Client.get("/prices/#{id}", params, opts) do
      {:ok, price} when is_map(price) ->
        {:ok, from_api(price)}

      {:ok, response} ->
        {:error, Error.from_response(response)}

      error ->
        error
    end
  end

  @doc """
  Creates a new price for a product.

  ## Parameters

  * `product_id` - Product ID this price belongs to (required)
  * `description` - Price description (optional)
  * `name` - Price name (optional)
  * `type` - Price type: "standard", "custom" (default: "standard")
  * `billing_cycle` - Billing cycle for recurring prices (optional)
  * `trial_period` - Trial period for subscriptions (optional)
  * `tax_mode` - Tax handling: "account_setting", "external" (default: "account_setting")
  * `unit_price` - Price amount and currency (required for standard prices)
  * `unit_price_overrides` - Country-specific price overrides (optional)
  * `quantity` - Quantity constraints (minimum/maximum) (optional)
  * `custom_data` - Custom metadata (optional)

  ## Examples

      # One-time price
      PaddleBilling.Price.create(%{
        product_id: "pro_123",
        description: "One-time purchase",
        unit_price: %{
          amount: "2999",
          currency_code: "USD"
        }
      })
      {:ok, %PaddleBilling.Price{id: "pri_456", type: "standard"}}

      # Monthly recurring price with trial
      PaddleBilling.Price.create(%{
        product_id: "pro_123",
        description: "Monthly Pro Plan",
        billing_cycle: %{
          interval: "month",
          frequency: 1
        },
        trial_period: %{
          interval: "day",
          frequency: 14
        },
        unit_price: %{
          amount: "2999",
          currency_code: "USD"
        },
        tax_mode: "account_setting"
      })
      {:ok, %PaddleBilling.Price{billing_cycle: %{...}}}

      # Price with quantity constraints and overrides
      PaddleBilling.Price.create(%{
        product_id: "pro_123",
        description: "Bulk pricing",
        unit_price: %{
          amount: "1000",
          currency_code: "USD"
        },
        quantity: %{
          minimum: 10,
          maximum: 100
        },
        unit_price_overrides: [
          %{
            country_codes: ["GB", "DE"],
            unit_price: %{
              amount: "850",
              currency_code: "EUR"
            }
          }
        ],
        custom_data: %{
          tier: "enterprise",
          discount_eligible: true
        }
      })
      {:ok, %PaddleBilling.Price{}}
  """
  @spec create(create_params(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def create(params, opts \\ []) do
    case Client.post("/prices", params, opts) do
      {:ok, price} when is_map(price) ->
        {:ok, from_api(price)}

      {:ok, response} ->
        {:error, Error.from_response(response)}

      error ->
        error
    end
  end

  @doc """
  Updates a price.

  Note: Some fields like product_id and type cannot be updated after creation.
  Billing cycle changes may affect existing subscriptions.

  ## Parameters

  * `description` - Price description (optional)
  * `name` - Price name (optional)
  * `billing_cycle` - Billing cycle for recurring prices (optional)
  * `trial_period` - Trial period for subscriptions (optional)
  * `tax_mode` - Tax handling mode (optional)
  * `unit_price` - Price amount and currency (optional)
  * `unit_price_overrides` - Country-specific price overrides (optional)
  * `quantity` - Quantity constraints (optional)
  * `custom_data` - Custom metadata (optional)
  * `status` - Price status: "active" or "archived" (optional)

  ## Examples

      PaddleBilling.Price.update("pri_123", %{
        description: "Updated Monthly Plan",
        unit_price: %{
          amount: "3499",
          currency_code: "USD"
        }
      })
      {:ok, %PaddleBilling.Price{description: "Updated Monthly Plan"}}

      # Update trial period
      PaddleBilling.Price.update("pri_123", %{
        trial_period: %{
          interval: "day",
          frequency: 30
        }
      })
      {:ok, %PaddleBilling.Price{}}

      # Add custom data
      PaddleBilling.Price.update("pri_123", %{
        custom_data: %{
          featured: true,
          promotion: "summer2024"
        }
      })
      {:ok, %PaddleBilling.Price{}}

      # Archive a price
      PaddleBilling.Price.update("pri_123", %{
        status: "archived"
      })
      {:ok, %PaddleBilling.Price{status: "archived"}}
  """
  @spec update(String.t(), update_params(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def update(id, params, opts \\ []) do
    case Client.patch("/prices/#{id}", params, opts) do
      {:ok, price} when is_map(price) ->
        {:ok, from_api(price)}

      {:ok, response} ->
        {:error, Error.from_response(response)}

      error ->
        error
    end
  end

  @doc """
  Archives a price.

  Archived prices cannot be used to create new subscriptions or transactions,
  but existing subscriptions continue to work.

  ## Examples

      PaddleBilling.Price.archive("pri_123")
      {:ok, %PaddleBilling.Price{status: "archived"}}
  """
  @spec archive(String.t(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def archive(id, opts \\ []) do
    update(id, %{status: "archived"}, opts)
  end

  @doc """
  Creates a one-time price for a product.

  Convenience function for creating non-recurring prices.

  ## Examples

      PaddleBilling.Price.create_one_time("pro_123", %{
        amount: "4999",
        currency_code: "USD"
      }, %{
        description: "One-time Pro License"
      })
      {:ok, %PaddleBilling.Price{billing_cycle: nil}}
  """
  @spec create_one_time(String.t(), unit_price(), map(), keyword()) ::
          {:ok, t()} | {:error, Error.t()}
  def create_one_time(product_id, unit_price, additional_params \\ %{}, opts \\ []) do
    params =
      Map.merge(
        %{
          product_id: product_id,
          unit_price: unit_price,
          type: "standard"
        },
        additional_params
      )

    create(params, opts)
  end

  @doc """
  Creates a recurring price for a product.

  Convenience function for creating subscription prices with billing cycles.

  ## Examples

      PaddleBilling.Price.create_recurring("pro_123", %{
        amount: "2999",
        currency_code: "USD"
      }, %{
        interval: "month",
        frequency: 1
      }, %{
        description: "Monthly Subscription",
        trial_period: %{interval: "day", frequency: 7}
      })
      {:ok, %PaddleBilling.Price{billing_cycle: %{interval: "month"}}}
  """
  @spec create_recurring(String.t(), unit_price(), billing_cycle(), map(), keyword()) ::
          {:ok, t()} | {:error, Error.t()}
  def create_recurring(
        product_id,
        unit_price,
        billing_cycle,
        additional_params \\ %{},
        opts \\ []
      ) do
    params =
      Map.merge(
        %{
          product_id: product_id,
          unit_price: unit_price,
          billing_cycle: billing_cycle,
          type: "standard"
        },
        additional_params
      )

    create(params, opts)
  end

  # Private functions

  @spec from_api(map()) :: t()
  defp from_api(data) when is_map(data) do
    %__MODULE__{
      id: Map.get(data, "id"),
      description: Map.get(data, "description"),
      product_id: Map.get(data, "product_id"),
      name: Map.get(data, "name"),
      type: Map.get(data, "type"),
      billing_cycle: Map.get(data, "billing_cycle"),
      trial_period: Map.get(data, "trial_period"),
      tax_mode: Map.get(data, "tax_mode"),
      unit_price: Map.get(data, "unit_price"),
      unit_price_overrides: ensure_list(Map.get(data, "unit_price_overrides")),
      quantity: Map.get(data, "quantity"),
      custom_data: Map.get(data, "custom_data"),
      status: Map.get(data, "status"),
      created_at: Map.get(data, "created_at"),
      updated_at: Map.get(data, "updated_at"),
      import_meta: Map.get(data, "import_meta")
    }
  end

  @spec ensure_list(any()) :: [any()] | nil
  defp ensure_list(nil), do: nil
  defp ensure_list(list) when is_list(list), do: list
  defp ensure_list(_), do: nil
end
