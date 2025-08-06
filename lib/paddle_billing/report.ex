defmodule PaddleBilling.Report do
  @moduledoc """
  Manage reports in Paddle Billing.

  Reports provide analytics and insights into your billing data, including
  transaction summaries, subscription metrics, tax reports, and custom
  data exports. Reports can be generated on-demand or scheduled, and are
  available in various formats including CSV downloads.
  """

  alias PaddleBilling.{Client, Error}

  @type t :: %__MODULE__{
          id: String.t(),
          type: String.t(),
          status: String.t(),
          filters: map() | nil,
          parameters: map() | nil,
          rows: integer() | nil,
          expires_at: String.t() | nil,
          created_at: String.t(),
          updated_at: String.t()
        }

  defstruct [
    :id,
    :type,
    :status,
    :filters,
    :parameters,
    :rows,
    :expires_at,
    :created_at,
    :updated_at
  ]

  @type list_params :: %{
          optional(:after) => String.t(),
          optional(:type) => [String.t()],
          optional(:status) => [String.t()],
          optional(:created_at) => map(),
          optional(:updated_at) => map(),
          optional(:per_page) => pos_integer()
        }

  @type create_params :: %{
          :type => String.t(),
          optional(:filters) => map(),
          optional(:parameters) => map()
        }

  @doc """
  Lists all reports.

  ## Parameters

  * `:after` - Return reports after this report ID (pagination)
  * `:type` - Filter by report type (transactions, subscriptions, adjustments, discounts, tax_summary, etc.)
  * `:status` - Filter by status (pending, generating, ready, failed, expired)
  * `:created_at` - Filter by creation date range
  * `:updated_at` - Filter by update date range
  * `:per_page` - Number of results per page (max 200)

  ## Examples

      PaddleBilling.Report.list()
      {:ok, [%PaddleBilling.Report{}, ...]}

      PaddleBilling.Report.list(%{
        type: ["transactions", "subscriptions"],
        status: ["ready"],
        per_page: 50
      })
      {:ok, [%PaddleBilling.Report{}, ...]}

      # Filter by date ranges
      PaddleBilling.Report.list(%{
        created_at: %{
          from: "2023-01-01T00:00:00Z",
          to: "2023-12-31T23:59:59Z"
        },
        status: ["ready"]
      })
      {:ok, [%PaddleBilling.Report{}, ...]}
  """
  @spec list(list_params(), keyword()) :: {:ok, [t()]} | {:error, Error.t()}
  def list(params \\ %{}, opts \\ []) do
    case Client.get("/reports", params, opts) do
      {:ok, reports} when is_list(reports) ->
        {:ok, Enum.map(reports, &from_api/1)}

      {:ok, response} ->
        {:error, Error.from_response(response)}

      error ->
        error
    end
  end

  @doc """
  Gets a report by ID.

  ## Examples

      PaddleBilling.Report.get("rep_123")
      {:ok, %PaddleBilling.Report{id: "rep_123", status: "ready"}}

      PaddleBilling.Report.get("invalid_id")
      {:error, %PaddleBilling.Error{type: :not_found_error}}
  """
  @spec get(String.t(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def get(id, opts \\ []) do
    case Client.get("/reports/#{id}", %{}, opts) do
      {:ok, report} when is_map(report) ->
        {:ok, from_api(report)}

      {:ok, response} ->
        {:error, Error.from_response(response)}

      error ->
        error
    end
  end

  @doc """
  Creates a new report.

  ## Parameters

  * `type` - Type of report to generate (required)
    - "transactions" - Transaction summary report
    - "subscriptions" - Subscription analytics
    - "adjustments" - Adjustment summary
    - "discounts" - Discount usage report
    - "tax_summary" - Tax summary report
    - "product_summary" - Product performance
    - "customer_summary" - Customer analytics
  * `filters` - Filters to apply to the report data (optional)
  * `parameters` - Additional parameters for report generation (optional)

  ## Examples

      # Basic transaction report
      PaddleBilling.Report.create(%{
        type: "transactions"
      })
      {:ok, %PaddleBilling.Report{type: "transactions", status: "pending"}}

      # Filtered subscription report
      PaddleBilling.Report.create(%{
        type: "subscriptions",
        filters: %{
          status: ["active", "trialing"],
          created_at: %{
            from: "2023-01-01T00:00:00Z",
            to: "2023-12-31T23:59:59Z"
          }
        }
      })
      {:ok, %PaddleBilling.Report{}}

      # Tax summary report with parameters
      PaddleBilling.Report.create(%{
        type: "tax_summary",
        filters: %{
          created_at: %{
            from: "2023-01-01T00:00:00Z",
            to: "2023-03-31T23:59:59Z"
          }
        },
        parameters: %{
          group_by: "tax_rate",
          include_zero_tax: false
        }
      })
      {:ok, %PaddleBilling.Report{}}

      # Product performance report
      PaddleBilling.Report.create(%{
        type: "product_summary",
        filters: %{
          product_id: ["pro_123", "pro_456"]
        },
        parameters: %{
          metrics: ["revenue", "quantity", "conversion_rate"],
          group_by: "month"
        }
      })
      {:ok, %PaddleBilling.Report{}}
  """
  @spec create(create_params(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def create(params, opts \\ []) do
    case Client.post("/reports", params, opts) do
      {:ok, report} when is_map(report) ->
        {:ok, from_api(report)}

      {:ok, response} ->
        {:error, Error.from_response(response)}

      error ->
        error
    end
  end

  @doc """
  Downloads a report as CSV.

  Returns the CSV data as a binary string for completed reports.

  ## Examples

      PaddleBilling.Report.download_csv("rep_123")
      {:ok, "Date,Transaction ID,Amount,Currency\\n2023-01-01,txn_123,1000,USD\\n..."}

      PaddleBilling.Report.download_csv("rep_pending")
      {:error, %PaddleBilling.Error{type: :validation_error, message: "Report not ready"}}
  """
  @spec download_csv(String.t(), keyword()) :: {:ok, binary()} | {:error, Error.t()}
  def download_csv(id, opts \\ []) do
    case Client.get("/reports/#{id}/csv", %{}, opts) do
      {:ok, csv_data} when is_binary(csv_data) ->
        {:ok, csv_data}

      {:ok, response} ->
        {:error, Error.from_response(response)}

      error ->
        error
    end
  end

  @doc """
  Gets a temporary download URL for a report CSV.

  Returns a secure temporary URL that can be used to download the CSV
  directly. The URL expires after 3 minutes for security.

  ## Examples

      PaddleBilling.Report.get_download_url("rep_123")
      {:ok, %{
        "url" => "https://api.paddle.com/reports/rep_123/download?token=...",
        "expires_at" => "2024-01-15T10:33:00Z"
      }}

      PaddleBilling.Report.get_download_url("rep_pending")
      {:error, %PaddleBilling.Error{type: :validation_error}}
  """
  @spec get_download_url(String.t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def get_download_url(id, opts \\ []) do
    Client.get("/reports/#{id}/download-url", %{}, opts)
  end

  @doc """
  Gets ready reports.

  Convenience function to list only completed reports that are ready for download.

  ## Examples

      PaddleBilling.Report.list_ready()
      {:ok, [%PaddleBilling.Report{status: "ready"}, ...]}

      PaddleBilling.Report.list_ready(["transactions", "subscriptions"])
      {:ok, [%PaddleBilling.Report{}, ...]}
  """
  @spec list_ready([String.t()], keyword()) :: {:ok, [t()]} | {:error, Error.t()}
  def list_ready(types \\ [], opts \\ []) do
    filters = %{status: ["ready"]}
    filters = if types != [], do: Map.put(filters, :type, types), else: filters
    list(filters, opts)
  end

  @doc """
  Gets pending reports.

  Convenience function to list reports that are still being generated.

  ## Examples

      PaddleBilling.Report.list_pending()
      {:ok, [%PaddleBilling.Report{status: "pending"}, ...]}
  """
  @spec list_pending(keyword()) :: {:ok, [t()]} | {:error, Error.t()}
  def list_pending(opts \\ []) do
    list(%{status: ["pending", "generating"]}, opts)
  end

  @doc """
  Creates a transaction report for a date range.

  Convenience function for generating transaction reports.

  ## Examples

      PaddleBilling.Report.create_transaction_report("2023-01-01T00:00:00Z", "2023-12-31T23:59:59Z")
      {:ok, %PaddleBilling.Report{type: "transactions"}}

      PaddleBilling.Report.create_transaction_report(
        "2023-01-01T00:00:00Z", 
        "2023-12-31T23:59:59Z",
        %{status: ["completed", "paid"]}
      )
      {:ok, %PaddleBilling.Report{}}
  """
  @spec create_transaction_report(String.t(), String.t(), map(), keyword()) ::
          {:ok, t()} | {:error, Error.t()}
  def create_transaction_report(from_date, to_date, additional_filters \\ %{}, opts \\ []) do
    filters =
      Map.merge(
        %{
          created_at: %{
            from: from_date,
            to: to_date
          }
        },
        additional_filters
      )

    create(
      %{
        type: "transactions",
        filters: filters
      },
      opts
    )
  end

  @doc """
  Creates a subscription report for a date range.

  Convenience function for generating subscription reports.

  ## Examples

      PaddleBilling.Report.create_subscription_report("2023-01-01T00:00:00Z", "2023-12-31T23:59:59Z")
      {:ok, %PaddleBilling.Report{type: "subscriptions"}}
  """
  @spec create_subscription_report(String.t(), String.t(), map(), keyword()) ::
          {:ok, t()} | {:error, Error.t()}
  def create_subscription_report(from_date, to_date, additional_filters \\ %{}, opts \\ []) do
    filters =
      Map.merge(
        %{
          created_at: %{
            from: from_date,
            to: to_date
          }
        },
        additional_filters
      )

    create(
      %{
        type: "subscriptions",
        filters: filters
      },
      opts
    )
  end

  @doc """
  Checks if a report is ready for download.

  ## Examples

      PaddleBilling.Report.ready?(%PaddleBilling.Report{status: "ready"})
      true

      PaddleBilling.Report.ready?(%PaddleBilling.Report{status: "pending"})
      false
  """
  @spec ready?(t()) :: boolean()
  def ready?(%__MODULE__{status: "ready"}), do: true
  def ready?(%__MODULE__{}), do: false

  @doc """
  Checks if a report is still being generated.

  ## Examples

      PaddleBilling.Report.generating?(%PaddleBilling.Report{status: "generating"})
      true

      PaddleBilling.Report.generating?(%PaddleBilling.Report{status: "pending"})
      true
  """
  @spec generating?(t()) :: boolean()
  def generating?(%__MODULE__{status: status}) when status in ["pending", "generating"], do: true
  def generating?(%__MODULE__{}), do: false

  @doc """
  Checks if a report generation failed.

  ## Examples

      PaddleBilling.Report.failed?(%PaddleBilling.Report{status: "failed"})
      true
  """
  @spec failed?(t()) :: boolean()
  def failed?(%__MODULE__{status: "failed"}), do: true
  def failed?(%__MODULE__{}), do: false

  @doc """
  Checks if a report has expired.

  ## Examples

      PaddleBilling.Report.expired?(%PaddleBilling.Report{status: "expired"})
      true
  """
  @spec expired?(t()) :: boolean()
  def expired?(%__MODULE__{status: "expired"}), do: true
  def expired?(%__MODULE__{}), do: false

  # Private functions

  @spec from_api(map()) :: t()
  def from_api(data) when is_map(data) do
    %__MODULE__{
      id: Map.get(data, "id"),
      type: Map.get(data, "type"),
      status: Map.get(data, "status"),
      filters: Map.get(data, "filters"),
      parameters: Map.get(data, "parameters"),
      rows: Map.get(data, "rows"),
      expires_at: Map.get(data, "expires_at"),
      created_at: Map.get(data, "created_at"),
      updated_at: Map.get(data, "updated_at")
    }
  end
end
