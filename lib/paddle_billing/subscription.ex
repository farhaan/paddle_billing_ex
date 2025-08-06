defmodule PaddleBilling.Subscription do
  @moduledoc """
  Manage subscriptions in Paddle Billing.

  Subscriptions represent recurring billing relationships between customers and products.
  They handle billing cycles, trial periods, pricing changes, and lifecycle management
  including activation, cancellation, pausing, and resumption.
  """

  alias PaddleBilling.{Client, Error}

  @type t :: %__MODULE__{
          id: String.t(),
          status: String.t(),
          customer_id: String.t(),
          address_id: String.t() | nil,
          business_id: String.t() | nil,
          currency_code: String.t(),
          created_at: String.t(),
          updated_at: String.t(),
          started_at: String.t() | nil,
          first_billed_at: String.t() | nil,
          next_billed_at: String.t() | nil,
          paused_at: String.t() | nil,
          canceled_at: String.t() | nil,
          custom_data: map() | nil,
          collection_mode: String.t(),
          billing_details: map() | nil,
          current_billing_period: map() | nil,
          billing_cycle: map() | nil,
          recurring_transaction_details: map() | nil,
          scheduled_change: map() | nil,
          items: [map()],
          discount: map() | nil,
          import_meta: map() | nil
        }

  defstruct [
    :id,
    :status,
    :customer_id,
    :address_id,
    :business_id,
    :currency_code,
    :created_at,
    :updated_at,
    :started_at,
    :first_billed_at,
    :next_billed_at,
    :paused_at,
    :canceled_at,
    :custom_data,
    :collection_mode,
    :billing_details,
    :current_billing_period,
    :billing_cycle,
    :recurring_transaction_details,
    :scheduled_change,
    :items,
    :discount,
    :import_meta
  ]

  @type list_params :: %{
          optional(:after) => String.t(),
          optional(:id) => [String.t()],
          optional(:customer_id) => [String.t()],
          optional(:price_id) => [String.t()],
          optional(:status) => [String.t()],
          optional(:collection_mode) => [String.t()],
          optional(:per_page) => pos_integer(),
          optional(:include) => [String.t()]
        }

  @type create_params :: %{
          :items => [subscription_item()],
          optional(:customer_id) => String.t(),
          optional(:address_id) => String.t(),
          optional(:business_id) => String.t(),
          optional(:currency_code) => String.t(),
          optional(:collection_mode) => String.t(),
          optional(:billing_details) => billing_details(),
          optional(:billing_cycle) => billing_cycle(),
          optional(:scheduled_change) => scheduled_change(),
          optional(:proration_billing_mode) => String.t(),
          optional(:custom_data) => map()
        }

  @type update_params :: %{
          optional(:customer_id) => String.t(),
          optional(:address_id) => String.t(),
          optional(:business_id) => String.t(),
          optional(:collection_mode) => String.t(),
          optional(:billing_details) => billing_details(),
          optional(:scheduled_change) => scheduled_change(),
          optional(:proration_billing_mode) => String.t(),
          optional(:custom_data) => map()
        }

  @type subscription_item :: %{
          :price_id => String.t(),
          optional(:quantity) => pos_integer()
        }

  @type billing_details :: %{
          optional(:enable_checkout) => boolean(),
          optional(:purchase_order_number) => String.t(),
          optional(:additional_information) => String.t(),
          optional(:payment_terms) => payment_terms()
        }

  @type payment_terms :: %{
          :interval => String.t(),
          :frequency => pos_integer()
        }

  @type billing_cycle :: %{
          :interval => String.t(),
          :frequency => pos_integer()
        }

  @type scheduled_change :: %{
          :action => String.t(),
          optional(:effective_at) => String.t(),
          optional(:resume_at) => String.t(),
          optional(:items) => [subscription_item()]
        }

  @type lifecycle_action_params :: %{
          optional(:effective_from) => String.t(),
          optional(:resume_at) => String.t(),
          optional(:proration_billing_mode) => String.t()
        }

  @type one_time_charge_params :: %{
          :items => [charge_item()],
          optional(:effective_from) => String.t(),
          optional(:on_payment_failure) => String.t()
        }

  @type charge_item :: %{
          :price_id => String.t(),
          optional(:quantity) => pos_integer()
        }

  @type preview_params :: %{
          optional(:customer_id) => String.t(),
          optional(:address_id) => String.t(),
          optional(:business_id) => String.t(),
          optional(:currency_code) => String.t(),
          optional(:discount_id) => String.t(),
          optional(:address) => map(),
          optional(:customer) => map(),
          optional(:items) => [subscription_item()],
          optional(:proration_billing_mode) => String.t(),
          optional(:billing_cycle) => billing_cycle(),
          optional(:scheduled_change) => scheduled_change(),
          optional(:collection_mode) => String.t(),
          optional(:billing_details) => billing_details(),
          optional(:custom_data) => map()
        }

  @doc """
  Lists all subscriptions.

  ## Parameters

  * `:after` - Return subscriptions after this subscription ID (pagination)
  * `:id` - Filter by specific subscription IDs
  * `:customer_id` - Filter by customer IDs
  * `:price_id` - Filter by price IDs
  * `:status` - Filter by status (active, canceled, past_due, paused, trialing)
  * `:collection_mode` - Filter by collection mode (automatic, manual)
  * `:per_page` - Number of results per page (max 200)
  * `:include` - Include related resources (customer, address, business, discount)

  ## Examples

      PaddleBilling.Subscription.list()
      {:ok, [%PaddleBilling.Subscription{}, ...]}

      PaddleBilling.Subscription.list(%{
        customer_id: ["ctm_123"],
        status: ["active", "trialing"],
        include: ["customer", "discount"],
        per_page: 50
      })
      {:ok, [%PaddleBilling.Subscription{}, ...]}

      # Filter by price to find subscriptions for specific products
      PaddleBilling.Subscription.list(%{price_id: ["pri_456"]})
      {:ok, [%PaddleBilling.Subscription{}, ...]}
  """
  @spec list(list_params(), keyword()) :: {:ok, [t()]} | {:error, Error.t()}
  def list(params \\ %{}, opts \\ []) do
    case Client.get("/subscriptions", params, opts) do
      {:ok, subscriptions} when is_list(subscriptions) ->
        {:ok, Enum.map(subscriptions, &from_api/1)}

      {:ok, response} ->
        {:error, Error.from_response(response)}

      error ->
        error
    end
  end

  @doc """
  Gets a subscription by ID.

  ## Parameters

  * `:include` - Include related resources (customer, address, business, discount)

  ## Examples

      PaddleBilling.Subscription.get("sub_123")
      {:ok, %PaddleBilling.Subscription{id: "sub_123", status: "active"}}

      PaddleBilling.Subscription.get("sub_123", %{include: ["customer", "discount"]})
      {:ok, %PaddleBilling.Subscription{}}

      PaddleBilling.Subscription.get("invalid_id")
      {:error, %PaddleBilling.Error{type: :not_found_error}}
  """
  @spec get(String.t(), map(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def get(id, params \\ %{}, opts \\ []) do
    case Client.get("/subscriptions/#{id}", params, opts) do
      {:ok, subscription} when is_map(subscription) ->
        {:ok, from_api(subscription)}

      {:ok, response} ->
        {:error, Error.from_response(response)}

      error ->
        error
    end
  end

  @doc """
  Creates a new subscription.

  ## Parameters

  * `items` - Array of subscription items with price_id and optional quantity (required)
  * `customer_id` - Customer ID (optional, can be provided via checkout)
  * `address_id` - Billing address ID (optional)
  * `business_id` - Business ID for B2B subscriptions (optional)
  * `currency_code` - Currency code (optional, defaults from prices)
  * `collection_mode` - "automatic" or "manual" (optional, default: "automatic")
  * `billing_details` - Additional billing information (optional)
  * `billing_cycle` - Override billing cycle (optional)
  * `scheduled_change` - Schedule future changes (optional)
  * `proration_billing_mode` - How to handle prorations (optional)
  * `custom_data` - Custom metadata (optional)

  ## Examples

      # Simple subscription with one item
      PaddleBilling.Subscription.create(%{
        items: [
          %{price_id: "pri_123", quantity: 1}
        ],
        customer_id: "ctm_456"
      })
      {:ok, %PaddleBilling.Subscription{}}

      # Complex subscription with multiple items and billing details
      PaddleBilling.Subscription.create(%{
        items: [
          %{price_id: "pri_base_plan", quantity: 1},
          %{price_id: "pri_addon_users", quantity: 5}
        ],
        customer_id: "ctm_enterprise",
        address_id: "add_billing_123",
        collection_mode: "manual",
        billing_details: %{
          enable_checkout: false,
          purchase_order_number: "PO-2024-001",
          payment_terms: %{interval: "month", frequency: 1}
        },
        custom_data: %{
          contract_id: "CTR-2024-001",
          account_manager: "jane.doe@company.com"
        }
      })
      {:ok, %PaddleBilling.Subscription{}}

      # Schedule future changes during creation
      PaddleBilling.Subscription.create(%{
        items: [%{price_id: "pri_trial", quantity: 1}],
        customer_id: "ctm_123",
        scheduled_change: %{
          action: "update",
          effective_at: "2024-02-01T00:00:00Z",
          items: [%{price_id: "pri_paid_plan", quantity: 1}]
        }
      })
      {:ok, %PaddleBilling.Subscription{}}
  """
  @spec create(create_params(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def create(params, opts \\ []) do
    case Client.post("/subscriptions", params, opts) do
      {:ok, subscription} when is_map(subscription) ->
        {:ok, from_api(subscription)}

      {:ok, response} ->
        {:error, Error.from_response(response)}

      error ->
        error
    end
  end

  @doc """
  Updates a subscription.

  ## Examples

      PaddleBilling.Subscription.update("sub_123", %{
        collection_mode: "manual",
        custom_data: %{
          tier: "enterprise",
          renewal_date: "2024-12-31"
        }
      })
      {:ok, %PaddleBilling.Subscription{}}

      # Schedule a change for the future
      PaddleBilling.Subscription.update("sub_123", %{
        scheduled_change: %{
          action: "update",
          effective_at: "2024-03-01T00:00:00Z",
          items: [%{price_id: "pri_new_plan", quantity: 1}]
        }
      })
      {:ok, %PaddleBilling.Subscription{}}
  """
  @spec update(String.t(), update_params(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def update(id, params, opts \\ []) do
    case Client.patch("/subscriptions/#{id}", params, opts) do
      {:ok, subscription} when is_map(subscription) ->
        {:ok, from_api(subscription)}

      {:ok, response} ->
        {:error, Error.from_response(response)}

      error ->
        error
    end
  end

  @doc """
  Activates a subscription.

  Moves a subscription from trialing or past_due status to active.

  ## Examples

      PaddleBilling.Subscription.activate("sub_123")
      {:ok, %PaddleBilling.Subscription{status: "active"}}

      # Activate with specific effective time
      PaddleBilling.Subscription.activate("sub_123", %{
        effective_from: "immediately"
      })
      {:ok, %PaddleBilling.Subscription{}}
  """
  @spec activate(String.t(), lifecycle_action_params(), keyword()) ::
          {:ok, t()} | {:error, Error.t()}
  def activate(id, params \\ %{}, opts \\ []) do
    case Client.post("/subscriptions/#{id}/activate", params, opts) do
      {:ok, subscription} when is_map(subscription) ->
        {:ok, from_api(subscription)}

      {:ok, response} ->
        {:error, Error.from_response(response)}

      error ->
        error
    end
  end

  @doc """
  Cancels a subscription.

  ## Parameters

  * `effective_from` - When to cancel: "immediately" or "next_billing_period" (default: "next_billing_period")
  * `proration_billing_mode` - How to handle prorations: "full_immediately", "prorated_immediately", "prorated_next_billing_period"

  ## Examples

      # Cancel at end of current billing period
      PaddleBilling.Subscription.cancel("sub_123")
      {:ok, %PaddleBilling.Subscription{status: "canceled"}}

      # Cancel immediately with prorated refund
      PaddleBilling.Subscription.cancel("sub_123", %{
        effective_from: "immediately",
        proration_billing_mode: "prorated_immediately"
      })
      {:ok, %PaddleBilling.Subscription{}}
  """
  @spec cancel(String.t(), lifecycle_action_params(), keyword()) ::
          {:ok, t()} | {:error, Error.t()}
  def cancel(id, params \\ %{}, opts \\ []) do
    case Client.post("/subscriptions/#{id}/cancel", params, opts) do
      {:ok, subscription} when is_map(subscription) ->
        {:ok, from_api(subscription)}

      {:ok, response} ->
        {:error, Error.from_response(response)}

      error ->
        error
    end
  end

  @doc """
  Pauses a subscription.

  ## Parameters

  * `effective_from` - When to pause: "immediately" or "next_billing_period" (default: "next_billing_period")
  * `resume_at` - When to automatically resume (ISO 8601 datetime, optional)

  ## Examples

      # Pause at end of current billing period
      PaddleBilling.Subscription.pause("sub_123")
      {:ok, %PaddleBilling.Subscription{status: "paused"}}

      # Pause immediately and resume in 3 months
      PaddleBilling.Subscription.pause("sub_123", %{
        effective_from: "immediately",
        resume_at: "2024-04-01T00:00:00Z"
      })
      {:ok, %PaddleBilling.Subscription{}}
  """
  @spec pause(String.t(), lifecycle_action_params(), keyword()) ::
          {:ok, t()} | {:error, Error.t()}
  def pause(id, params \\ %{}, opts \\ []) do
    case Client.post("/subscriptions/#{id}/pause", params, opts) do
      {:ok, subscription} when is_map(subscription) ->
        {:ok, from_api(subscription)}

      {:ok, response} ->
        {:error, Error.from_response(response)}

      error ->
        error
    end
  end

  @doc """
  Resumes a paused subscription.

  ## Parameters

  * `effective_from` - When to resume: "immediately" or "next_billing_period" (default: "immediately")

  ## Examples

      PaddleBilling.Subscription.resume("sub_123")
      {:ok, %PaddleBilling.Subscription{status: "active"}}

      # Resume at next billing period
      PaddleBilling.Subscription.resume("sub_123", %{
        effective_from: "next_billing_period"
      })
      {:ok, %PaddleBilling.Subscription{}}
  """
  @spec resume(String.t(), lifecycle_action_params(), keyword()) ::
          {:ok, t()} | {:error, Error.t()}
  def resume(id, params \\ %{}, opts \\ []) do
    case Client.post("/subscriptions/#{id}/resume", params, opts) do
      {:ok, subscription} when is_map(subscription) ->
        {:ok, from_api(subscription)}

      {:ok, response} ->
        {:error, Error.from_response(response)}

      error ->
        error
    end
  end

  @doc """
  Gets active subscriptions for a customer.

  Convenience function to find all active subscriptions for a specific customer.

  ## Examples

      PaddleBilling.Subscription.list_for_customer("ctm_123")
      {:ok, [%PaddleBilling.Subscription{customer_id: "ctm_123"}, ...]}

      PaddleBilling.Subscription.list_for_customer("ctm_123", ["active", "trialing"])
      {:ok, [%PaddleBilling.Subscription{}, ...]}
  """
  @spec list_for_customer(String.t(), [String.t()], keyword()) ::
          {:ok, [t()]} | {:error, Error.t()}
  def list_for_customer(customer_id, statuses \\ ["active"], opts \\ []) do
    list(%{customer_id: [customer_id], status: statuses}, opts)
  end

  @doc """
  Gets subscriptions for a specific price.

  Convenience function to find all subscriptions using a specific price.

  ## Examples

      PaddleBilling.Subscription.list_for_price("pri_123")
      {:ok, [%PaddleBilling.Subscription{}, ...]}
  """
  @spec list_for_price(String.t(), keyword()) :: {:ok, [t()]} | {:error, Error.t()}
  def list_for_price(price_id, opts \\ []) do
    list(%{price_id: [price_id]}, opts)
  end

  @doc """
  Checks if a subscription is active.

  ## Examples

      PaddleBilling.Subscription.active?(%PaddleBilling.Subscription{status: "active"})
      true

      PaddleBilling.Subscription.active?(%PaddleBilling.Subscription{status: "canceled"})  
      false
  """
  @spec active?(t()) :: boolean()
  def active?(%__MODULE__{status: "active"}), do: true
  def active?(%__MODULE__{}), do: false

  @doc """
  Checks if a subscription is canceled.

  ## Examples

      PaddleBilling.Subscription.canceled?(%PaddleBilling.Subscription{status: "canceled"})
      true
  """
  @spec canceled?(t()) :: boolean()
  def canceled?(%__MODULE__{status: "canceled"}), do: true
  def canceled?(%__MODULE__{}), do: false

  @doc """
  Checks if a subscription is paused.

  ## Examples

      PaddleBilling.Subscription.paused?(%PaddleBilling.Subscription{status: "paused"})
      true
  """
  @spec paused?(t()) :: boolean()
  def paused?(%__MODULE__{status: "paused"}), do: true
  def paused?(%__MODULE__{}), do: false

  @doc """
  Checks if a subscription is in trial.

  ## Examples

      PaddleBilling.Subscription.trialing?(%PaddleBilling.Subscription{status: "trialing"})
      true
  """
  @spec trialing?(t()) :: boolean()
  def trialing?(%__MODULE__{status: "trialing"}), do: true
  def trialing?(%__MODULE__{}), do: false

  @doc """
  Creates a one-time charge for a subscription.

  Adds one-time charges to an existing subscription that will be billed
  on the next billing cycle or immediately.

  ## Parameters

  * `items` - Array of charge items with price_id and optional quantity (required)
  * `effective_from` - When to apply the charge: "immediately" or "next_billing_period" (default: "next_billing_period")
  * `on_payment_failure` - What to do if payment fails: "prevent_change" or "apply_change" (default: "prevent_change")

  ## Examples

      # Add one-time charge for next billing period
      PaddleBilling.Subscription.charge("sub_123", %{
        items: [
          %{price_id: "pri_setup_fee", quantity: 1}
        ]
      })
      {:ok, %PaddleBilling.Subscription{}}

      # Apply charge immediately
      PaddleBilling.Subscription.charge("sub_123", %{
        items: [
          %{price_id: "pri_addon", quantity: 2}
        ],
        effective_from: "immediately",
        on_payment_failure: "apply_change"
      })
      {:ok, %PaddleBilling.Subscription{}}
  """
  @spec charge(String.t(), one_time_charge_params(), keyword()) ::
          {:ok, t()} | {:error, Error.t()}
  def charge(id, params, opts \\ []) do
    case Client.post("/subscriptions/#{id}/charge", params, opts) do
      {:ok, subscription} when is_map(subscription) ->
        {:ok, from_api(subscription)}

      {:ok, response} ->
        {:error, Error.from_response(response)}

      error ->
        error
    end
  end

  @doc """
  Gets the update payment method transaction for a subscription.

  Returns the transaction created when updating a subscription's payment method,
  which may include prorated charges or credits.

  ## Examples

      PaddleBilling.Subscription.get_update_payment_method_transaction("sub_123")
      {:ok, %{"id" => "txn_456", "status" => "completed", ...}}

      PaddleBilling.Subscription.get_update_payment_method_transaction("invalid_id")
      {:error, %PaddleBilling.Error{type: :not_found_error}}
  """
  @spec get_update_payment_method_transaction(String.t(), keyword()) ::
          {:ok, map()} | {:error, Error.t()}
  def get_update_payment_method_transaction(id, opts \\ []) do
    Client.get("/subscriptions/#{id}/update-payment-method-transaction", %{}, opts)
  end

  @doc """
  Preview a subscription before creating it.

  Returns pricing information and totals for a subscription without actually creating it.
  Useful for showing customers pricing before they commit to a subscription.

  ## Parameters

  All parameters are optional and allow you to preview different scenarios:

  * `customer_id` - Existing customer ID
  * `address_id` - Address ID for tax calculations
  * `business_id` - Business ID for B2B pricing
  * `currency_code` - Currency for pricing
  * `discount_id` - Discount to apply
  * `address` - Address details for tax calculations (alternative to address_id)
  * `customer` - Customer details (alternative to customer_id)
  * `items` - Array of subscription items to preview
  * `proration_billing_mode` - How to handle prorations
  * `billing_cycle` - Billing cycle override
  * `scheduled_change` - Preview with scheduled changes
  * `collection_mode` - Collection mode ("automatic" or "manual")
  * `billing_details` - Billing details
  * `custom_data` - Custom metadata

  ## Examples

      # Basic preview with items
      PaddleBilling.Subscription.preview(%{
        items: [
          %{price_id: "pri_123", quantity: 1}
        ],
        customer_id: "ctm_456"
      })
      {:ok, %{"data" => %{"details" => %{"totals" => %{"subtotal" => "1000", ...}}}}}

      # Preview with new customer and address
      PaddleBilling.Subscription.preview(%{
        items: [%{price_id: "pri_123", quantity: 1}],
        customer: %{
          email: "customer@example.com",
          name: "John Doe"
        },
        address: %{
          country_code: "US",
          postal_code: "10001"
        }
      })
      {:ok, %{"data" => %{...}}}

      # Preview with discount applied
      PaddleBilling.Subscription.preview(%{
        items: [%{price_id: "pri_123", quantity: 1}],
        customer_id: "ctm_456",
        discount_id: "dsc_25percent"
      })
      {:ok, %{"data" => %{...}}}
  """
  @spec preview(preview_params(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def preview(params \\ %{}, opts \\ []) do
    Client.post("/subscriptions/preview", params, opts)
  end

  @doc """
  Preview subscription updates.

  Shows what would happen if you updated an existing subscription with new parameters.
  Returns pricing differences, prorations, and new totals.

  ## Parameters

  * `subscription_id` - ID of existing subscription to preview updates for (required in params)
  * Additional parameters same as `preview/2`

  ## Examples

      # Preview changing subscription items
      PaddleBilling.Subscription.preview_update(%{
        subscription_id: "sub_123",
        items: [
          %{price_id: "pri_new_plan", quantity: 1}
        ],
        proration_billing_mode: "prorated_immediately"
      })
      {:ok, %{"data" => %{"immediate_transaction" => %{...}, "next_transaction" => %{...}}}}

      # Preview adding items to existing subscription
      PaddleBilling.Subscription.preview_update(%{
        subscription_id: "sub_123",
        items: [
          %{price_id: "pri_base", quantity: 1},
          %{price_id: "pri_addon", quantity: 2}
        ]
      })
      {:ok, %{"data" => %{...}}}
  """
  @spec preview_update(preview_params(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def preview_update(params, opts \\ []) do
    Client.patch("/subscriptions/preview", params, opts)
  end

  # Private functions

  @spec from_api(map()) :: t()
  defp from_api(data) when is_map(data) do
    %__MODULE__{
      id: Map.get(data, "id"),
      status: Map.get(data, "status"),
      customer_id: Map.get(data, "customer_id"),
      address_id: Map.get(data, "address_id"),
      business_id: Map.get(data, "business_id"),
      currency_code: Map.get(data, "currency_code"),
      created_at: Map.get(data, "created_at"),
      updated_at: Map.get(data, "updated_at"),
      started_at: Map.get(data, "started_at"),
      first_billed_at: Map.get(data, "first_billed_at"),
      next_billed_at: Map.get(data, "next_billed_at"),
      paused_at: Map.get(data, "paused_at"),
      canceled_at: Map.get(data, "canceled_at"),
      custom_data: Map.get(data, "custom_data"),
      collection_mode: Map.get(data, "collection_mode"),
      billing_details: Map.get(data, "billing_details"),
      current_billing_period: Map.get(data, "current_billing_period"),
      billing_cycle: Map.get(data, "billing_cycle"),
      recurring_transaction_details: Map.get(data, "recurring_transaction_details"),
      scheduled_change: Map.get(data, "scheduled_change"),
      items: ensure_list(Map.get(data, "items", [])),
      discount: Map.get(data, "discount"),
      import_meta: Map.get(data, "import_meta")
    }
  end

  @spec ensure_list(any()) :: [any()]
  defp ensure_list(nil), do: []
  defp ensure_list(list) when is_list(list), do: list
  defp ensure_list(_), do: []
end
