defmodule PaddleBilling.Transaction do
  @moduledoc """
  Manage transactions in Paddle Billing.

  Transactions represent completed or pending payments for products, subscriptions,
  and adjustments. They contain detailed billing information, payment history,
  and financial breakdowns including taxes, fees, and payouts.
  """

  alias PaddleBilling.{Client, Error}

  @type t :: %__MODULE__{
          id: String.t(),
          status: String.t(),
          customer_id: String.t(),
          address_id: String.t() | nil,
          business_id: String.t() | nil,
          custom_data: map() | nil,
          currency_code: String.t(),
          origin: String.t(),
          subscription_id: String.t() | nil,
          invoice_id: String.t() | nil,
          invoice_number: String.t() | nil,
          collection_mode: String.t(),
          discount_id: String.t() | nil,
          billing_details: map() | nil,
          billing_period: map() | nil,
          items: [map()],
          details: map() | nil,
          payments: [map()],
          checkout: map() | nil,
          created_at: String.t(),
          updated_at: String.t(),
          billed_at: String.t() | nil,
          import_meta: map() | nil
        }

  defstruct [
    :id,
    :status,
    :customer_id,
    :address_id,
    :business_id,
    :custom_data,
    :currency_code,
    :origin,
    :subscription_id,
    :invoice_id,
    :invoice_number,
    :collection_mode,
    :discount_id,
    :billing_details,
    :billing_period,
    :items,
    :details,
    :payments,
    :checkout,
    :created_at,
    :updated_at,
    :billed_at,
    :import_meta
  ]

  @type list_params :: %{
          optional(:after) => String.t(),
          optional(:id) => [String.t()],
          optional(:customer_id) => [String.t()],
          optional(:subscription_id) => [String.t()],
          optional(:invoice_id) => [String.t()],
          optional(:status) => [String.t()],
          optional(:collection_mode) => [String.t()],
          optional(:origin) => [String.t()],
          optional(:billed_at) => map(),
          optional(:created_at) => map(),
          optional(:updated_at) => map(),
          optional(:per_page) => pos_integer(),
          optional(:include) => [String.t()]
        }

  @type create_params :: %{
          :items => [transaction_item()],
          optional(:customer_id) => String.t(),
          optional(:address_id) => String.t(),
          optional(:business_id) => String.t(),
          optional(:currency_code) => String.t(),
          optional(:collection_mode) => String.t(),
          optional(:discount_id) => String.t(),
          optional(:billing_details) => billing_details(),
          optional(:billing_period) => billing_period(),
          optional(:custom_data) => map()
        }

  @type update_params :: %{
          optional(:customer_id) => String.t(),
          optional(:address_id) => String.t(),
          optional(:business_id) => String.t(),
          optional(:collection_mode) => String.t(),
          optional(:discount_id) => String.t(),
          optional(:billing_details) => billing_details(),
          optional(:custom_data) => map()
        }

  @type preview_params :: %{
          :items => [transaction_item()],
          optional(:customer_id) => String.t(),
          optional(:address_id) => String.t(),
          optional(:business_id) => String.t(),
          optional(:currency_code) => String.t(),
          optional(:discount_id) => String.t(),
          optional(:billing_period) => billing_period(),
          optional(:customer_ip_address) => String.t()
        }

  @type transaction_item :: %{
          :price_id => String.t(),
          :quantity => pos_integer(),
          optional(:proration) => proration()
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

  @type billing_period :: %{
          :starts_at => String.t(),
          :ends_at => String.t()
        }

  @type proration :: %{
          :rate => String.t(),
          :billing_period => billing_period()
        }

  @doc """
  Lists all transactions.

  ## Parameters

  * `:after` - Return transactions after this transaction ID (pagination)
  * `:id` - Filter by specific transaction IDs
  * `:customer_id` - Filter by customer IDs
  * `:subscription_id` - Filter by subscription IDs
  * `:invoice_id` - Filter by invoice IDs
  * `:status` - Filter by status (draft, ready, billed, paid, completed, canceled, past_due)
  * `:collection_mode` - Filter by collection mode (automatic, manual)
  * `:origin` - Filter by origin (api, subscription_charge, subscription_payment_method_change, subscription_update, subscription_recurring, adjustment_full, adjustment_partial, adjustment_tax)
  * `:billed_at` - Filter by billing date range
  * `:created_at` - Filter by creation date range
  * `:updated_at` - Filter by update date range
  * `:per_page` - Number of results per page (max 200)
  * `:include` - Include related resources (customer, address, business, discount, adjustments)

  ## Examples

      PaddleBilling.Transaction.list()
      {:ok, [%PaddleBilling.Transaction{}, ...]}

      PaddleBilling.Transaction.list(%{
        customer_id: ["ctm_123"],
        status: ["completed", "paid"],
        collection_mode: ["automatic"],
        include: ["customer", "adjustments"],
        per_page: 50
      })
      {:ok, [%PaddleBilling.Transaction{}, ...]}

      # Filter by date ranges
      PaddleBilling.Transaction.list(%{
        billed_at: %{
          from: "2023-01-01T00:00:00Z",
          to: "2023-12-31T23:59:59Z"
        },
        status: ["completed"]
      })
      {:ok, [%PaddleBilling.Transaction{}, ...]}

      # Filter by subscription to get billing history
      PaddleBilling.Transaction.list(%{subscription_id: ["sub_456"]})
      {:ok, [%PaddleBilling.Transaction{}, ...]}
  """
  @spec list(list_params(), keyword()) :: {:ok, [t()]} | {:error, Error.t()}
  def list(params \\ %{}, opts \\ []) do
    case Client.get("/transactions", params, opts) do
      {:ok, transactions} when is_list(transactions) ->
        {:ok, Enum.map(transactions, &from_api/1)}

      {:ok, response} ->
        {:error, Error.from_response(response)}

      error ->
        error
    end
  end

  @doc """
  Gets a transaction by ID.

  ## Parameters

  * `:include` - Include related resources (customer, address, business, discount, adjustments)

  ## Examples

      PaddleBilling.Transaction.get("txn_123")
      {:ok, %PaddleBilling.Transaction{id: "txn_123", status: "completed"}}

      PaddleBilling.Transaction.get("txn_123", %{include: ["customer", "adjustments"]})
      {:ok, %PaddleBilling.Transaction{}}

      PaddleBilling.Transaction.get("invalid_id")
      {:error, %PaddleBilling.Error{type: :not_found_error}}
  """
  @spec get(String.t(), map(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def get(id, params \\ %{}, opts \\ []) do
    case Client.get("/transactions/#{id}", params, opts) do
      {:ok, transaction} when is_map(transaction) ->
        {:ok, from_api(transaction)}

      {:ok, response} ->
        {:error, Error.from_response(response)}

      error ->
        error
    end
  end

  @doc """
  Creates a new transaction.

  ## Parameters

  * `items` - Array of transaction items with price_id and quantity (required)
  * `customer_id` - Customer ID (optional, can be provided via checkout)
  * `address_id` - Billing address ID (optional)
  * `business_id` - Business ID for B2B transactions (optional)
  * `currency_code` - Currency code (optional, defaults from prices)
  * `collection_mode` - "automatic" or "manual" (optional, default: "automatic")
  * `discount_id` - Discount ID to apply (optional)
  * `billing_details` - Additional billing information (optional)
  * `billing_period` - Billing period for subscription charges (optional)
  * `custom_data` - Custom metadata (optional)

  ## Examples

      # Simple one-time transaction
      PaddleBilling.Transaction.create(%{
        items: [
          %{price_id: "pri_123", quantity: 1}
        ],
        customer_id: "ctm_456"
      })
      {:ok, %PaddleBilling.Transaction{}}

      # Complex B2B transaction with multiple items
      PaddleBilling.Transaction.create(%{
        items: [
          %{price_id: "pri_software_license", quantity: 10},
          %{price_id: "pri_support_package", quantity: 1}
        ],
        customer_id: "ctm_enterprise",
        address_id: "add_billing_123",
        business_id: "biz_company_456",
        collection_mode: "manual",
        discount_id: "dsc_enterprise_discount",
        billing_details: %{
          enable_checkout: false,
          purchase_order_number: "PO-2024-001",
          additional_information: "Net-30 payment terms",
          payment_terms: %{interval: "month", frequency: 1}
        },
        custom_data: %{
          contract_id: "CTR-2024-001",
          sales_rep: "john.doe@company.com"
        }
      })
      {:ok, %PaddleBilling.Transaction{}}

      # Subscription billing with proration
      PaddleBilling.Transaction.create(%{
        items: [
          %{
            price_id: "pri_monthly_plan",
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
        billing_period: %{
          starts_at: "2024-01-01T00:00:00Z",
          ends_at: "2024-02-01T00:00:00Z"
        }
      })
      {:ok, %PaddleBilling.Transaction{}}
  """
  @spec create(create_params(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def create(params, opts \\ []) do
    case Client.post("/transactions", params, opts) do
      {:ok, transaction} when is_map(transaction) ->
        {:ok, from_api(transaction)}

      {:ok, response} ->
        {:error, Error.from_response(response)}

      error ->
        error
    end
  end

  @doc """
  Updates a transaction.

  Only draft transactions can be updated. Once billed, transactions are immutable.

  ## Examples

      PaddleBilling.Transaction.update("txn_123", %{
        collection_mode: "manual",
        billing_details: %{
          purchase_order_number: "PO-UPDATED-2024"
        },
        custom_data: %{
          updated_by: "admin@company.com",
          update_reason: "Customer request"
        }
      })
      {:ok, %PaddleBilling.Transaction{}}

      # Add discount to draft transaction
      PaddleBilling.Transaction.update("txn_draft", %{
        discount_id: "dsc_early_bird"
      })
      {:ok, %PaddleBilling.Transaction{}}
  """
  @spec update(String.t(), update_params(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def update(id, params, opts \\ []) do
    case Client.patch("/transactions/#{id}", params, opts) do
      {:ok, transaction} when is_map(transaction) ->
        {:ok, from_api(transaction)}

      {:ok, response} ->
        {:error, Error.from_response(response)}

      error ->
        error
    end
  end

  @doc """
  Previews a transaction without creating it.

  Returns calculated totals, taxes, and fees for the given items and customer
  without actually creating a transaction. Useful for showing pricing estimates.

  ## Parameters

  * `items` - Array of transaction items with price_id and quantity (required)
  * `customer_id` - Customer ID for tax calculation (optional)
  * `address_id` - Address ID for tax calculation (optional)
  * `business_id` - Business ID for B2B calculations (optional)
  * `currency_code` - Currency code (optional)
  * `discount_id` - Discount ID to apply (optional)
  * `billing_period` - Billing period for calculations (optional)
  * `customer_ip_address` - IP address for tax location (optional)

  ## Examples

      # Preview simple transaction
      PaddleBilling.Transaction.preview(%{
        items: [
          %{price_id: "pri_123", quantity: 2}
        ],
        customer_id: "ctm_456"
      })
      {:ok, %{
        "totals" => %{
          "subtotal" => "4800",
          "tax" => "480",
          "total" => "5280",
          "currency_code" => "USD"
        },
        "tax_rates_used" => [...]
      }}

      # Preview with discount and address
      PaddleBilling.Transaction.preview(%{
        items: [%{price_id: "pri_annual_plan", quantity: 1}],
        customer_id: "ctm_123",
        address_id: "add_billing_456",
        discount_id: "dsc_new_customer"
      })
      {:ok, %{...}}
  """
  @spec preview(preview_params(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def preview(params, opts \\ []) do
    case Client.post("/transactions/preview", params, opts) do
      {:ok, preview} when is_map(preview) ->
        {:ok, preview}

      {:ok, response} ->
        {:error, Error.from_response(response)}

      error ->
        error
    end
  end

  @doc """
  Creates an invoice for a transaction.

  Invoices a completed transaction, generating an invoice that can be sent to customers.
  Only transactions with status "completed" can be invoiced.

  ## Examples

      PaddleBilling.Transaction.invoice("txn_123")
      {:ok, %PaddleBilling.Transaction{status: "completed", invoice_id: "inv_456"}}

      PaddleBilling.Transaction.invoice("txn_draft")
      {:error, %PaddleBilling.Error{type: :validation_error}}
  """
  @spec invoice(String.t(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def invoice(id, opts \\ []) do
    case Client.post("/transactions/#{id}/invoice", %{}, opts) do
      {:ok, transaction} when is_map(transaction) ->
        {:ok, from_api(transaction)}

      {:ok, response} ->
        {:error, Error.from_response(response)}

      error ->
        error
    end
  end

  @doc """
  Gets the invoice details for a transaction.

  Returns invoice information including invoice number, status, and totals.

  ## Examples

      PaddleBilling.Transaction.get_invoice("txn_123")
      {:ok, %{"invoice_id" => "inv_456", "invoice_number" => "INV-2024-001", ...}}

      PaddleBilling.Transaction.get_invoice("txn_no_invoice")
      {:error, %PaddleBilling.Error{type: :not_found_error}}
  """
  @spec get_invoice(String.t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def get_invoice(id, opts \\ []) do
    Client.get("/transactions/#{id}/invoice", %{}, opts)
  end

  @doc """
  Gets the PDF for a transaction.

  Returns the transaction PDF as binary data. The PDF includes transaction details,
  items, totals, and payment information.

  ## Examples

      PaddleBilling.Transaction.get_pdf("txn_123")
      {:ok, <<PDF binary data>>}

      PaddleBilling.Transaction.get_pdf("txn_draft")
      {:error, %PaddleBilling.Error{type: :validation_error}}
  """
  @spec get_pdf(String.t(), keyword()) :: {:ok, binary()} | {:error, Error.t()}
  def get_pdf(id, opts \\ []) do
    case Client.get("/transactions/#{id}/pdf", %{}, opts) do
      {:ok, pdf_data} when is_binary(pdf_data) ->
        {:ok, pdf_data}

      {:ok, response} ->
        {:error, Error.from_response(response)}

      error ->
        error
    end
  end

  @doc """
  Gets transactions for a specific customer.

  Convenience function to find all transactions for a customer.

  ## Examples

      PaddleBilling.Transaction.list_for_customer("ctm_123")
      {:ok, [%PaddleBilling.Transaction{customer_id: "ctm_123"}, ...]}

      PaddleBilling.Transaction.list_for_customer("ctm_123", ["completed", "paid"])
      {:ok, [%PaddleBilling.Transaction{}, ...]}
  """
  @spec list_for_customer(String.t(), [String.t()], keyword()) ::
          {:ok, [t()]} | {:error, Error.t()}
  def list_for_customer(customer_id, statuses \\ ["completed"], opts \\ []) do
    list(%{customer_id: [customer_id], status: statuses}, opts)
  end

  @doc """
  Gets transactions for a specific subscription.

  Convenience function to find billing history for a subscription.

  ## Examples

      PaddleBilling.Transaction.list_for_subscription("sub_123")
      {:ok, [%PaddleBilling.Transaction{subscription_id: "sub_123"}, ...]}
  """
  @spec list_for_subscription(String.t(), keyword()) :: {:ok, [t()]} | {:error, Error.t()}
  def list_for_subscription(subscription_id, opts \\ []) do
    list(%{subscription_id: [subscription_id]}, opts)
  end

  @doc """
  Checks if a transaction is completed.

  ## Examples

      PaddleBilling.Transaction.completed?(%PaddleBilling.Transaction{status: "completed"})
      true

      PaddleBilling.Transaction.completed?(%PaddleBilling.Transaction{status: "draft"})
      false
  """
  @spec completed?(t()) :: boolean()
  def completed?(%__MODULE__{status: "completed"}), do: true
  def completed?(%__MODULE__{}), do: false

  @doc """
  Checks if a transaction is paid.

  ## Examples

      PaddleBilling.Transaction.paid?(%PaddleBilling.Transaction{status: "paid"})
      true
  """
  @spec paid?(t()) :: boolean()
  def paid?(%__MODULE__{status: "paid"}), do: true
  def paid?(%__MODULE__{}), do: false

  @doc """
  Checks if a transaction is billed.

  ## Examples

      PaddleBilling.Transaction.billed?(%PaddleBilling.Transaction{status: "billed"})
      true
  """
  @spec billed?(t()) :: boolean()
  def billed?(%__MODULE__{status: "billed"}), do: true
  def billed?(%__MODULE__{}), do: false

  @doc """
  Checks if a transaction is a draft.

  ## Examples

      PaddleBilling.Transaction.draft?(%PaddleBilling.Transaction{status: "draft"})
      true
  """
  @spec draft?(t()) :: boolean()
  def draft?(%__MODULE__{status: "draft"}), do: true
  def draft?(%__MODULE__{}), do: false

  @doc """
  Checks if a transaction is canceled.

  ## Examples

      PaddleBilling.Transaction.canceled?(%PaddleBilling.Transaction{status: "canceled"})
      true
  """
  @spec canceled?(t()) :: boolean()
  def canceled?(%__MODULE__{status: "canceled"}), do: true
  def canceled?(%__MODULE__{}), do: false

  @doc """
  Checks if a transaction is past due.

  ## Examples

      PaddleBilling.Transaction.past_due?(%PaddleBilling.Transaction{status: "past_due"})
      true
  """
  @spec past_due?(t()) :: boolean()
  def past_due?(%__MODULE__{status: "past_due"}), do: true
  def past_due?(%__MODULE__{}), do: false

  @doc """
  Gets a link to the invoice PDF for a transaction.

  Returns a temporary link to download the invoice PDF. The link
  expires after a certain period for security.

  ## Examples

      PaddleBilling.Transaction.get_invoice_pdf("txn_123")
      {:ok, %{
        "url" => "https://checkout.paddle.com/invoice/txn_123/pdf?token=...",
        "expires_at" => "2024-01-15T11:00:00Z"
      }}

      PaddleBilling.Transaction.get_invoice_pdf("txn_not_billed")
      {:error, %PaddleBilling.Error{type: :validation_error}}
  """
  @spec get_invoice_pdf(String.t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def get_invoice_pdf(id, opts \\ []) do
    Client.get("/transactions/#{id}/invoice", %{}, opts)
  end

  @doc """
  Revises customer information on a transaction.

  Allows you to update customer details on billed or completed transactions.
  This is useful for correcting customer information after billing has occurred.

  ## Parameters

  * `customer_id` - Updated customer ID (optional)
  * `address_id` - Updated address ID (optional)
  * `business_id` - Updated business ID (optional)
  * `custom_data` - Updated custom metadata (optional)

  ## Examples  

      PaddleBilling.Transaction.revise("txn_123", %{
        customer_id: "ctm_updated_456",
        address_id: "add_corrected_789"
      })
      {:ok, %PaddleBilling.Transaction{}}

      # Update business information
      PaddleBilling.Transaction.revise("txn_123", %{
        business_id: "biz_corrected_123",
        custom_data: %{
          corrected_at: "2024-01-15T10:30:00Z",
          correction_reason: "Customer name change"
        }
      })
      {:ok, %PaddleBilling.Transaction{}}
  """
  @spec revise(String.t(), map(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def revise(id, params, opts \\ []) do
    case Client.post("/transactions/#{id}/revise", params, opts) do
      {:ok, transaction} when is_map(transaction) ->
        {:ok, from_api(transaction)}

      {:ok, response} ->
        {:error, Error.from_response(response)}

      error ->
        error
    end
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
      custom_data: Map.get(data, "custom_data"),
      currency_code: Map.get(data, "currency_code"),
      origin: Map.get(data, "origin"),
      subscription_id: Map.get(data, "subscription_id"),
      invoice_id: Map.get(data, "invoice_id"),
      invoice_number: Map.get(data, "invoice_number"),
      collection_mode: Map.get(data, "collection_mode"),
      discount_id: Map.get(data, "discount_id"),
      billing_details: Map.get(data, "billing_details"),
      billing_period: Map.get(data, "billing_period"),
      items: ensure_list(Map.get(data, "items", [])),
      details: Map.get(data, "details"),
      payments: ensure_list(Map.get(data, "payments", [])),
      checkout: Map.get(data, "checkout"),
      created_at: Map.get(data, "created_at"),
      updated_at: Map.get(data, "updated_at"),
      billed_at: Map.get(data, "billed_at"),
      import_meta: Map.get(data, "import_meta")
    }
  end

  @spec ensure_list(any()) :: [any()]
  defp ensure_list(nil), do: []
  defp ensure_list(list) when is_list(list), do: list
  defp ensure_list(_), do: []
end
