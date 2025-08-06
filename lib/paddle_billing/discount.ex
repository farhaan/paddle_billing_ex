defmodule PaddleBilling.Discount do
  @moduledoc """
  Manage discounts in Paddle Billing.

  Discounts allow you to offer percentage or fixed amount reductions to customers.
  They can be applied to specific products, entire orders, or subscriptions,
  with configurable usage limits, expiration dates, and eligibility criteria.
  """

  alias PaddleBilling.{Client, Error}

  @type t :: %__MODULE__{
          id: String.t(),
          status: String.t(),
          description: String.t(),
          enabled_for_checkout: boolean(),
          code: String.t() | nil,
          type: String.t(),
          amount: String.t(),
          currency_code: String.t() | nil,
          recur: boolean(),
          maximum_recurring_intervals: integer() | nil,
          usage_limit: integer() | nil,
          restrict_to: [String.t()],
          expires_at: String.t() | nil,
          custom_data: map() | nil,
          created_at: String.t(),
          updated_at: String.t(),
          import_meta: map() | nil
        }

  defstruct [
    :id,
    :status,
    :description,
    :enabled_for_checkout,
    :code,
    :type,
    :amount,
    :currency_code,
    :recur,
    :maximum_recurring_intervals,
    :usage_limit,
    :restrict_to,
    :expires_at,
    :custom_data,
    :created_at,
    :updated_at,
    :import_meta
  ]

  @type list_params :: %{
          optional(:after) => String.t(),
          optional(:id) => [String.t()],
          optional(:status) => [String.t()],
          optional(:code) => String.t(),
          optional(:per_page) => pos_integer(),
          optional(:include) => [String.t()]
        }

  @type create_params :: %{
          :description => String.t(),
          :type => String.t(),
          :amount => String.t(),
          optional(:enabled_for_checkout) => boolean(),
          optional(:code) => String.t(),
          optional(:currency_code) => String.t(),
          optional(:recur) => boolean(),
          optional(:maximum_recurring_intervals) => integer(),
          optional(:usage_limit) => integer(),
          optional(:restrict_to) => [String.t()],
          optional(:expires_at) => String.t(),
          optional(:custom_data) => map()
        }

  @type update_params :: %{
          optional(:description) => String.t(),
          optional(:enabled_for_checkout) => boolean(),
          optional(:code) => String.t(),
          optional(:recur) => boolean(),
          optional(:maximum_recurring_intervals) => integer(),
          optional(:usage_limit) => integer(),
          optional(:restrict_to) => [String.t()],
          optional(:expires_at) => String.t(),
          optional(:status) => String.t(),
          optional(:custom_data) => map()
        }

  @doc """
  Lists all discounts.

  ## Parameters

  * `:after` - Return discounts after this discount ID (pagination)
  * `:id` - Filter by specific discount IDs
  * `:status` - Filter by status (active, archived)
  * `:code` - Filter by discount code
  * `:per_page` - Number of results per page (max 200)
  * `:include` - Include related resources

  ## Examples

      PaddleBilling.Discount.list()
      {:ok, [%PaddleBilling.Discount{}, ...]}

      PaddleBilling.Discount.list(%{
        status: ["active"],
        code: "SUMMER2024",
        per_page: 50
      })
      {:ok, [%PaddleBilling.Discount{}, ...]}

      # Filter by specific discount codes
      PaddleBilling.Discount.list(%{code: "BLACKFRIDAY"})
      {:ok, [%PaddleBilling.Discount{code: "BLACKFRIDAY"}, ...]}
  """
  @spec list(list_params(), keyword()) :: {:ok, [t()]} | {:error, Error.t()}
  def list(params \\ %{}, opts \\ []) do
    case Client.get("/discounts", params, opts) do
      {:ok, discounts} when is_list(discounts) ->
        {:ok, Enum.map(discounts, &from_api/1)}

      {:ok, response} ->
        {:error, Error.from_response(response)}

      error ->
        error
    end
  end

  @doc """
  Gets a discount by ID.

  ## Parameters

  * `:include` - Include related resources

  ## Examples

      PaddleBilling.Discount.get("dsc_123")
      {:ok, %PaddleBilling.Discount{id: "dsc_123", description: "Summer Sale"}}

      PaddleBilling.Discount.get("dsc_123", %{include: ["products"]})
      {:ok, %PaddleBilling.Discount{}}

      PaddleBilling.Discount.get("invalid_id")
      {:error, %PaddleBilling.Error{type: :not_found_error}}
  """
  @spec get(String.t(), map(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def get(id, params \\ %{}, opts \\ []) do
    case Client.get("/discounts/#{id}", params, opts) do
      {:ok, discount} when is_map(discount) ->
        {:ok, from_api(discount)}

      {:ok, response} ->
        {:error, Error.from_response(response)}

      error ->
        error
    end
  end

  @doc """
  Creates a new discount.

  ## Parameters

  * `description` - Discount description (required)
  * `type` - Discount type: "percentage" or "flat" (required)
  * `amount` - Discount amount as string (required)
  * `enabled_for_checkout` - Whether discount can be used in checkout (optional)
  * `code` - Discount code for customer use (optional)
  * `currency_code` - Currency for flat discounts (required for flat type)
  * `recur` - Whether discount applies to recurring charges (optional)
  * `maximum_recurring_intervals` - Max recurring applications (optional)
  * `usage_limit` - Maximum number of uses (optional)
  * `restrict_to` - Array of product IDs to restrict to (optional)
  * `expires_at` - Expiration date (ISO 8601, optional)
  * `custom_data` - Custom metadata (optional)

  ## Examples

      # Percentage discount
      PaddleBilling.Discount.create(%{
        description: "Summer Sale - 20% Off",
        type: "percentage",
        amount: "20",
        code: "SUMMER20",
        enabled_for_checkout: true,
        expires_at: "2024-08-31T23:59:59Z"
      })
      {:ok, %PaddleBilling.Discount{}}

      # Fixed amount discount
      PaddleBilling.Discount.create(%{
        description: "New Customer Discount",
        type: "flat",
        amount: "1000",
        currency_code: "USD",
        code: "WELCOME10",
        usage_limit: 100,
        recur: false
      })
      {:ok, %PaddleBilling.Discount{}}

      # Product-specific recurring discount
      PaddleBilling.Discount.create(%{
        description: "Annual Plan Discount",
        type: "percentage",
        amount: "15",
        code: "ANNUAL15",
        recur: true,
        maximum_recurring_intervals: 12,
        restrict_to: ["pro_annual_plan"],
        custom_data: %{
          "campaign" => "annual_promotion",
          "target_audience" => "enterprise"
        }
      })
      {:ok, %PaddleBilling.Discount{}}

      # Unlimited usage discount
      PaddleBilling.Discount.create(%{
        description: "Partner Discount",
        type: "percentage", 
        amount: "25",
        code: "PARTNER25",
        enabled_for_checkout: true,
        custom_data: %{
          "partner_tier" => "platinum",
          "automated" => true
        }
      })
      {:ok, %PaddleBilling.Discount{}}
  """
  @spec create(create_params(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def create(params, opts \\ []) do
    case Client.post("/discounts", params, opts) do
      {:ok, discount} when is_map(discount) ->
        {:ok, from_api(discount)}

      {:ok, response} ->
        {:error, Error.from_response(response)}

      error ->
        error
    end
  end

  @doc """
  Updates a discount.

  ## Parameters

  * `description` - Discount description (optional)
  * `enabled_for_checkout` - Whether discount can be used in checkout (optional)
  * `code` - Discount code for customer use (optional)
  * `recur` - Whether discount applies to recurring charges (optional)
  * `maximum_recurring_intervals` - Max recurring applications (optional)
  * `usage_limit` - Maximum number of uses (optional)
  * `restrict_to` - Array of product IDs to restrict to (optional)
  * `expires_at` - Expiration date (ISO 8601, optional)
  * `status` - Discount status: "active" or "archived" (optional)
  * `custom_data` - Custom metadata (optional)

  ## Examples

      PaddleBilling.Discount.update("dsc_123", %{
        description: "Updated Summer Sale - 25% Off",
        expires_at: "2024-09-15T23:59:59Z",
        usage_limit: 500
      })
      {:ok, %PaddleBilling.Discount{}}

      # Enable for checkout
      PaddleBilling.Discount.update("dsc_123", %{
        enabled_for_checkout: true,
        custom_data: %{
          "checkout_enabled_at" => "2024-01-15T10:00:00Z",
          "enabled_by" => "admin@company.com"
        }
      })
      {:ok, %PaddleBilling.Discount{}}

      # Restrict to specific products
      PaddleBilling.Discount.update("dsc_123", %{
        restrict_to: ["pro_premium", "pro_enterprise"],
        custom_data: %{
          "restriction_reason" => "Premium products only"
        }
      })
      {:ok, %PaddleBilling.Discount{}}
  """
  @spec update(String.t(), update_params(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def update(id, params, opts \\ []) do
    case Client.patch("/discounts/#{id}", params, opts) do
      {:ok, discount} when is_map(discount) ->
        {:ok, from_api(discount)}

      {:ok, response} ->
        {:error, Error.from_response(response)}

      error ->
        error
    end
  end

  @doc """
  Archives a discount.

  Archived discounts cannot be used for new transactions but existing
  usage history remains accessible.

  ## Examples

      PaddleBilling.Discount.archive("dsc_123")
      {:ok, %PaddleBilling.Discount{status: "archived"}}
  """
  @spec archive(String.t(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def archive(id, opts \\ []) do
    update(id, %{status: "archived"}, opts)
  end

  @doc """
  Finds discounts by code.

  Convenience function for finding discounts by their code.

  ## Examples

      PaddleBilling.Discount.find_by_code("SUMMER20")
      {:ok, [%PaddleBilling.Discount{code: "SUMMER20"}, ...]}

      PaddleBilling.Discount.find_by_code("NONEXISTENT")
      {:ok, []}  # Empty list if not found
  """
  @spec find_by_code(String.t(), keyword()) :: {:ok, [t()]} | {:error, Error.t()}
  def find_by_code(code, opts \\ []) do
    list(%{code: code}, opts)
  end

  @doc """
  Gets active discounts only.

  Convenience function to filter active discounts.

  ## Examples

      PaddleBilling.Discount.list_active()
      {:ok, [%PaddleBilling.Discount{status: "active"}, ...]}
  """
  @spec list_active(keyword()) :: {:ok, [t()]} | {:error, Error.t()}
  def list_active(opts \\ []) do
    list(%{status: ["active"]}, opts)
  end

  @doc """
  Validates if a discount amount is valid for its type.

  ## Examples

      PaddleBilling.Discount.valid_amount?("percentage", "25")
      true

      PaddleBilling.Discount.valid_amount?("percentage", "150")
      false

      PaddleBilling.Discount.valid_amount?("flat", "1000")
      true

      PaddleBilling.Discount.valid_amount?("flat", "-100")
      false
  """
  @spec valid_amount?(String.t(), String.t()) :: boolean()
  def valid_amount?(type, amount) do
    case {type, parse_amount(amount)} do
      {"percentage", amount_num} when is_number(amount_num) ->
        amount_num > 0 and amount_num <= 100

      {"flat", amount_num} when is_number(amount_num) ->
        amount_num > 0

      _ ->
        false
    end
  end

  @doc """
  Checks if a discount is active.

  ## Examples

      PaddleBilling.Discount.active?(%PaddleBilling.Discount{status: "active"})
      true

      PaddleBilling.Discount.active?(%PaddleBilling.Discount{status: "archived"})
      false
  """
  @spec active?(t()) :: boolean()
  def active?(%__MODULE__{status: "active"}), do: true
  def active?(%__MODULE__{}), do: false

  @doc """
  Checks if a discount is archived.

  ## Examples

      PaddleBilling.Discount.archived?(%PaddleBilling.Discount{status: "archived"})
      true
  """
  @spec archived?(t()) :: boolean()
  def archived?(%__MODULE__{status: "archived"}), do: true
  def archived?(%__MODULE__{}), do: false

  @doc """
  Checks if a discount is a percentage discount.

  ## Examples

      PaddleBilling.Discount.percentage?(%PaddleBilling.Discount{type: "percentage"})
      true
  """
  @spec percentage?(t()) :: boolean()
  def percentage?(%__MODULE__{type: "percentage"}), do: true
  def percentage?(%__MODULE__{}), do: false

  @doc """
  Checks if a discount is a flat amount discount.

  ## Examples

      PaddleBilling.Discount.flat?(%PaddleBilling.Discount{type: "flat"})
      true
  """
  @spec flat?(t()) :: boolean()
  def flat?(%__MODULE__{type: "flat"}), do: true
  def flat?(%__MODULE__{}), do: false

  @doc """
  Checks if a discount has usage limits.

  ## Examples

      discount = %PaddleBilling.Discount{usage_limit: 100}
      PaddleBilling.Discount.has_usage_limit?(discount)
      true

      discount = %PaddleBilling.Discount{usage_limit: nil}
      PaddleBilling.Discount.has_usage_limit?(discount)
      false
  """
  @spec has_usage_limit?(t()) :: boolean()
  def has_usage_limit?(%__MODULE__{usage_limit: limit}) do
    not is_nil(limit) and limit > 0
  end

  @doc """
  Checks if a discount is expired.

  ## Examples

      discount = %PaddleBilling.Discount{expires_at: "2023-01-01T00:00:00Z"}
      PaddleBilling.Discount.expired?(discount)
      true

      discount = %PaddleBilling.Discount{expires_at: nil}
      PaddleBilling.Discount.expired?(discount)
      false
  """
  @spec expired?(t()) :: boolean()
  def expired?(%__MODULE__{expires_at: nil}), do: false

  def expired?(%__MODULE__{expires_at: expires_at}) when is_binary(expires_at) do
    case DateTime.from_iso8601(expires_at) do
      {:ok, expiry_date, _} ->
        DateTime.compare(DateTime.utc_now(), expiry_date) == :gt

      _ ->
        false
    end
  end

  def expired?(%__MODULE__{}), do: false

  @doc """
  Checks if a discount applies to recurring charges.

  ## Examples

      PaddleBilling.Discount.recurring?(%PaddleBilling.Discount{recur: true})
      true
  """
  @spec recurring?(t()) :: boolean()
  def recurring?(%__MODULE__{recur: true}), do: true
  def recurring?(%__MODULE__{}), do: false

  # Private functions

  @spec from_api(map()) :: t()
  defp from_api(data) when is_map(data) do
    %__MODULE__{
      id: Map.get(data, "id"),
      status: Map.get(data, "status"),
      description: Map.get(data, "description"),
      enabled_for_checkout: Map.get(data, "enabled_for_checkout", false),
      code: Map.get(data, "code"),
      type: Map.get(data, "type"),
      amount: Map.get(data, "amount"),
      currency_code: Map.get(data, "currency_code"),
      recur: Map.get(data, "recur", false),
      maximum_recurring_intervals: Map.get(data, "maximum_recurring_intervals"),
      usage_limit: Map.get(data, "usage_limit"),
      restrict_to: ensure_list(Map.get(data, "restrict_to", [])),
      expires_at: Map.get(data, "expires_at"),
      custom_data: Map.get(data, "custom_data"),
      created_at: Map.get(data, "created_at"),
      updated_at: Map.get(data, "updated_at"),
      import_meta: Map.get(data, "import_meta")
    }
  end

  @spec ensure_list(any()) :: [any()]
  defp ensure_list(nil), do: []
  defp ensure_list(list) when is_list(list), do: list
  defp ensure_list(_), do: []

  @spec parse_amount(String.t()) :: number() | nil
  defp parse_amount(amount) when is_binary(amount) do
    case Float.parse(amount) do
      {num, ""} ->
        num

      _ ->
        case Integer.parse(amount) do
          {num, ""} -> num
          _ -> nil
        end
    end
  end

  defp parse_amount(_), do: nil
end
