defmodule PaddleBilling.Adjustment do
  @moduledoc """
  Manage adjustments in Paddle Billing.

  Adjustments represent changes to completed transactions, such as refunds,
  credits, or additional charges. They allow you to modify billing after
  a transaction has been processed and can be used for customer service,
  partial refunds, or billing corrections.
  """

  alias PaddleBilling.{Client, Error}

  @type t :: %__MODULE__{
          id: String.t(),
          transaction_id: String.t(),
          subscription_id: String.t() | nil,
          customer_id: String.t(),
          reason: String.t(),
          credit_applied_to_balance: boolean(),
          currency_code: String.t(),
          status: String.t(),
          items: [map()],
          totals: map(),
          payout_totals: map() | nil,
          tax_rates_used: [map()],
          created_at: String.t(),
          updated_at: String.t()
        }

  defstruct [
    :id,
    :transaction_id,
    :subscription_id,
    :customer_id,
    :reason,
    :credit_applied_to_balance,
    :currency_code,
    :status,
    :items,
    :totals,
    :payout_totals,
    :tax_rates_used,
    :created_at,
    :updated_at
  ]

  @type list_params :: %{
          optional(:after) => String.t(),
          optional(:id) => [String.t()],
          optional(:transaction_id) => [String.t()],
          optional(:subscription_id) => [String.t()],
          optional(:customer_id) => [String.t()],
          optional(:status) => [String.t()],
          optional(:reason) => [String.t()],
          optional(:created_at) => map(),
          optional(:updated_at) => map(),
          optional(:per_page) => pos_integer(),
          optional(:include) => [String.t()]
        }

  @type create_params :: %{
          :transaction_id => String.t(),
          :action => String.t(),
          :items => [adjustment_item()],
          optional(:reason) => String.t(),
          optional(:credit_applied_to_balance) => boolean()
        }

  @type adjustment_item :: %{
          :item_id => String.t(),
          :type => String.t(),
          optional(:amount) => String.t(),
          optional(:proration) => proration()
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
  Lists all adjustments.

  ## Parameters

  * `:after` - Return adjustments after this adjustment ID (pagination)
  * `:id` - Filter by specific adjustment IDs
  * `:transaction_id` - Filter by transaction IDs
  * `:subscription_id` - Filter by subscription IDs
  * `:customer_id` - Filter by customer IDs
  * `:status` - Filter by status (pending_approval, approved, rejected, reversed)
  * `:reason` - Filter by reason (chargeback, refund, credit, correction)
  * `:created_at` - Filter by creation date range
  * `:updated_at` - Filter by update date range
  * `:per_page` - Number of results per page (max 200)
  * `:include` - Include related resources (customer, transaction)

  ## Examples

      PaddleBilling.Adjustment.list()
      {:ok, [%PaddleBilling.Adjustment{}, ...]}

      PaddleBilling.Adjustment.list(%{
        customer_id: ["ctm_123"],
        status: ["approved"],
        reason: ["refund"],
        include: ["customer", "transaction"],
        per_page: 50
      })
      {:ok, [%PaddleBilling.Adjustment{}, ...]}

      # Filter by date ranges
      PaddleBilling.Adjustment.list(%{
        created_at: %{
          from: "2023-01-01T00:00:00Z",
          to: "2023-12-31T23:59:59Z"
        },
        status: ["approved"]
      })
      {:ok, [%PaddleBilling.Adjustment{}, ...]}
  """
  @spec list(list_params(), keyword()) :: {:ok, [t()]} | {:error, Error.t()}
  def list(params \\ %{}, opts \\ []) do
    case Client.get("/adjustments", params, opts) do
      {:ok, adjustments} when is_list(adjustments) ->
        {:ok, Enum.map(adjustments, &from_api/1)}

      {:ok, response} ->
        {:error, Error.from_response(response)}

      error ->
        error
    end
  end

  @doc """
  Gets an adjustment by ID.

  ## Parameters

  * `:include` - Include related resources (customer, transaction)

  ## Examples

      PaddleBilling.Adjustment.get("adj_123")
      {:ok, %PaddleBilling.Adjustment{id: "adj_123", status: "approved"}}

      PaddleBilling.Adjustment.get("adj_123", %{include: ["customer", "transaction"]})
      {:ok, %PaddleBilling.Adjustment{}}

      PaddleBilling.Adjustment.get("invalid_id")
      {:error, %PaddleBilling.Error{type: :not_found_error}}
  """
  @spec get(String.t(), map(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def get(id, params \\ %{}, opts \\ []) do
    case Client.get("/adjustments/#{id}", params, opts) do
      {:ok, adjustment} when is_map(adjustment) ->
        {:ok, from_api(adjustment)}

      {:ok, response} ->
        {:error, Error.from_response(response)}

      error ->
        error
    end
  end

  @doc """
  Creates a new adjustment.

  ## Parameters

  * `transaction_id` - ID of the transaction to adjust (required)
  * `action` - Type of adjustment: "refund", "credit", or "chargeback" (required)
  * `items` - Array of adjustment items specifying what to adjust (required)
  * `reason` - Reason for the adjustment (optional)
  * `credit_applied_to_balance` - Whether to apply credit to customer balance (optional)

  ## Examples

      # Full refund
      PaddleBilling.Adjustment.create(%{
        transaction_id: "txn_123",
        action: "refund",
        items: [
          %{
            item_id: "txnitm_456",
            type: "full"
          }
        ],
        reason: "Customer request"
      })
      {:ok, %PaddleBilling.Adjustment{}}

      # Partial refund with specific amount
      PaddleBilling.Adjustment.create(%{
        transaction_id: "txn_123",
        action: "refund",
        items: [
          %{
            item_id: "txnitm_456",
            type: "partial",
            amount: "1000"
          }
        ],
        reason: "Partial refund for damaged goods"
      })
      {:ok, %PaddleBilling.Adjustment{}}

      # Credit adjustment with proration
      PaddleBilling.Adjustment.create(%{
        transaction_id: "txn_123",
        action: "credit",
        items: [
          %{
            item_id: "txnitm_456",
            type: "prorated",
            proration: %{
              rate: "0.5",
              billing_period: %{
                starts_at: "2024-01-15T00:00:00Z",
                ends_at: "2024-02-01T00:00:00Z"
              }
            }
          }
        ],
        credit_applied_to_balance: true,
        reason: "Service downtime credit"
      })
      {:ok, %PaddleBilling.Adjustment{}}
  """
  @spec create(create_params(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def create(params, opts \\ []) do
    case Client.post("/adjustments", params, opts) do
      {:ok, adjustment} when is_map(adjustment) ->
        {:ok, from_api(adjustment)}

      {:ok, response} ->
        {:error, Error.from_response(response)}

      error ->
        error
    end
  end

  @doc """
  Gets adjustments for a specific transaction.

  Convenience function to find all adjustments for a transaction.

  ## Examples

      PaddleBilling.Adjustment.list_for_transaction("txn_123")
      {:ok, [%PaddleBilling.Adjustment{transaction_id: "txn_123"}, ...]}

      PaddleBilling.Adjustment.list_for_transaction("txn_123", ["approved"])
      {:ok, [%PaddleBilling.Adjustment{}, ...]}
  """
  @spec list_for_transaction(String.t(), [String.t()], keyword()) ::
          {:ok, [t()]} | {:error, Error.t()}
  def list_for_transaction(transaction_id, statuses \\ ["approved"], opts \\ []) do
    list(%{transaction_id: [transaction_id], status: statuses}, opts)
  end

  @doc """
  Gets adjustments for a specific customer.

  Convenience function to find all adjustments for a customer.

  ## Examples

      PaddleBilling.Adjustment.list_for_customer("ctm_123")
      {:ok, [%PaddleBilling.Adjustment{customer_id: "ctm_123"}, ...]}
  """
  @spec list_for_customer(String.t(), keyword()) :: {:ok, [t()]} | {:error, Error.t()}
  def list_for_customer(customer_id, opts \\ []) do
    list(%{customer_id: [customer_id]}, opts)
  end

  @doc """
  Gets adjustments for a specific subscription.

  Convenience function to find all adjustments for a subscription.

  ## Examples

      PaddleBilling.Adjustment.list_for_subscription("sub_123")
      {:ok, [%PaddleBilling.Adjustment{subscription_id: "sub_123"}, ...]}
  """
  @spec list_for_subscription(String.t(), keyword()) :: {:ok, [t()]} | {:error, Error.t()}
  def list_for_subscription(subscription_id, opts \\ []) do
    list(%{subscription_id: [subscription_id]}, opts)
  end

  @doc """
  Gets the total adjustment amount for a transaction.

  Convenience function to calculate total adjustments for a transaction.

  ## Examples

      PaddleBilling.Adjustment.total_for_transaction("txn_123")
      {:ok, [%PaddleBilling.Adjustment{}, ...]}

      # Then calculate total manually or use adjustment totals
      Enum.reduce(adjustments, 0, fn adj, acc -> 
        String.to_integer(adj.totals["total"]) + acc 
      end)
  """
  @spec total_for_transaction(String.t(), keyword()) :: {:ok, [t()]} | {:error, Error.t()}
  def total_for_transaction(transaction_id, opts \\ []) do
    list_for_transaction(transaction_id, ["approved"], opts)
  end

  @doc """
  Checks if an adjustment is approved.

  ## Examples

      PaddleBilling.Adjustment.approved?(%PaddleBilling.Adjustment{status: "approved"})
      true

      PaddleBilling.Adjustment.approved?(%PaddleBilling.Adjustment{status: "pending_approval"})
      false
  """
  @spec approved?(t()) :: boolean()
  def approved?(%__MODULE__{status: "approved"}), do: true
  def approved?(%__MODULE__{}), do: false

  @doc """
  Checks if an adjustment is pending approval.

  ## Examples

      PaddleBilling.Adjustment.pending_approval?(%PaddleBilling.Adjustment{status: "pending_approval"})
      true
  """
  @spec pending_approval?(t()) :: boolean()
  def pending_approval?(%__MODULE__{status: "pending_approval"}), do: true
  def pending_approval?(%__MODULE__{}), do: false

  @doc """
  Checks if an adjustment is rejected.

  ## Examples

      PaddleBilling.Adjustment.rejected?(%PaddleBilling.Adjustment{status: "rejected"})
      true
  """
  @spec rejected?(t()) :: boolean()
  def rejected?(%__MODULE__{status: "rejected"}), do: true
  def rejected?(%__MODULE__{}), do: false

  @doc """
  Checks if an adjustment is reversed.

  ## Examples

      PaddleBilling.Adjustment.reversed?(%PaddleBilling.Adjustment{status: "reversed"})
      true
  """
  @spec reversed?(t()) :: boolean()
  def reversed?(%__MODULE__{status: "reversed"}), do: true
  def reversed?(%__MODULE__{}), do: false

  @doc """
  Gets a link to the credit note PDF for an adjustment.

  Returns a temporary link to download the credit note PDF for refunds
  and adjustments. The link expires after a certain period for security.

  ## Examples

      PaddleBilling.Adjustment.get_credit_note_pdf("adj_123")
      {:ok, %{
        "url" => "https://checkout.paddle.com/credit-note/adj_123/pdf?token=...",
        "expires_at" => "2024-01-15T11:00:00Z"
      }}

      PaddleBilling.Adjustment.get_credit_note_pdf("adj_pending")
      {:error, %PaddleBilling.Error{type: :validation_error}}
  """
  @spec get_credit_note_pdf(String.t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def get_credit_note_pdf(id, opts \\ []) do
    Client.get("/adjustments/#{id}/credit-note", %{}, opts)
  end

  # Private functions

  @spec from_api(map()) :: t()
  def from_api(data) when is_map(data) do
    %__MODULE__{
      id: Map.get(data, "id"),
      transaction_id: Map.get(data, "transaction_id"),
      subscription_id: Map.get(data, "subscription_id"),
      customer_id: Map.get(data, "customer_id"),
      reason: Map.get(data, "reason"),
      credit_applied_to_balance: Map.get(data, "credit_applied_to_balance", false),
      currency_code: Map.get(data, "currency_code"),
      status: Map.get(data, "status"),
      items: ensure_list(Map.get(data, "items", [])),
      totals: Map.get(data, "totals", %{}),
      payout_totals: Map.get(data, "payout_totals"),
      tax_rates_used: ensure_list(Map.get(data, "tax_rates_used", [])),
      created_at: Map.get(data, "created_at"),
      updated_at: Map.get(data, "updated_at")
    }
  end

  @spec ensure_list(any()) :: [any()]
  defp ensure_list(nil), do: []
  defp ensure_list(list) when is_list(list), do: list
  defp ensure_list(_), do: []
end
