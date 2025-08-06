defmodule PaddleBilling.Notification do
  @moduledoc """
  Manage notifications in Paddle Billing.

  Notifications are webhook events sent by Paddle when changes occur to your
  billing data. They provide real-time updates about transactions, subscriptions,
  customers, and other billing events. You can replay notifications and access
  their delivery logs for debugging and monitoring.
  """

  alias PaddleBilling.{Client, Error}

  @type t :: %__MODULE__{
          id: String.t(),
          type: String.t(),
          status: String.t(),
          payload: map(),
          occurred_at: String.t(),
          delivered_at: String.t() | nil,
          replayed_at: String.t() | nil,
          origin: String.t(),
          last_attempt_at: String.t() | nil,
          retry_at: String.t() | nil,
          times_attempted: integer(),
          notification_setting_id: String.t()
        }

  defstruct [
    :id,
    :type,
    :status,
    :payload,
    :occurred_at,
    :delivered_at,
    :replayed_at,
    :origin,
    :last_attempt_at,
    :retry_at,
    :times_attempted,
    :notification_setting_id
  ]

  @type list_params :: %{
          optional(:after) => String.t(),
          optional(:id) => [String.t()],
          optional(:status) => [String.t()],
          optional(:type) => [String.t()],
          optional(:occurred_at) => map(),
          optional(:delivered_at) => map(),
          optional(:notification_setting_id) => [String.t()],
          optional(:origin) => [String.t()],
          optional(:per_page) => pos_integer(),
          optional(:include) => [String.t()]
        }

  @doc """
  Lists all notifications.

  ## Parameters

  * `:after` - Return notifications after this notification ID (pagination)
  * `:id` - Filter by specific notification IDs
  * `:status` - Filter by status (delivered, failed, not_attempted)
  * `:type` - Filter by notification type (transaction.completed, subscription.activated, etc.)
  * `:occurred_at` - Filter by occurrence date range
  * `:delivered_at` - Filter by delivery date range
  * `:notification_setting_id` - Filter by notification setting IDs
  * `:origin` - Filter by origin (api, subscription_billing, simulation)
  * `:per_page` - Number of results per page (max 200)
  * `:include` - Include related resources

  ## Examples

      PaddleBilling.Notification.list()
      {:ok, [%PaddleBilling.Notification{}, ...]}

      PaddleBilling.Notification.list(%{
        status: ["delivered"],
        type: ["transaction.completed", "subscription.activated"],
        per_page: 50
      })
      {:ok, [%PaddleBilling.Notification{}, ...]}

      # Filter by date ranges
      PaddleBilling.Notification.list(%{
        occurred_at: %{
          from: "2023-01-01T00:00:00Z",
          to: "2023-12-31T23:59:59Z"
        },
        status: ["delivered"]
      })
      {:ok, [%PaddleBilling.Notification{}, ...]}

      # Filter by specific webhook events
      PaddleBilling.Notification.list(%{
        type: ["customer.created", "customer.updated"],
        origin: ["api"]
      })
      {:ok, [%PaddleBilling.Notification{}, ...]}
  """
  @spec list(list_params(), keyword()) :: {:ok, [t()]} | {:error, Error.t()}
  def list(params \\ %{}, opts \\ []) do
    case Client.get("/notifications", params, opts) do
      {:ok, notifications} when is_list(notifications) ->
        {:ok, Enum.map(notifications, &from_api/1)}

      {:ok, response} ->
        {:error, Error.from_response(response)}

      error ->
        error
    end
  end

  @doc """
  Gets a notification by ID.

  ## Parameters

  * `:include` - Include related resources

  ## Examples

      PaddleBilling.Notification.get("ntf_123")
      {:ok, %PaddleBilling.Notification{id: "ntf_123", status: "delivered"}}

      PaddleBilling.Notification.get("ntf_123", %{include: ["notification_setting"]})
      {:ok, %PaddleBilling.Notification{}}

      PaddleBilling.Notification.get("invalid_id")
      {:error, %PaddleBilling.Error{type: :not_found_error}}
  """
  @spec get(String.t(), map(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def get(id, params \\ %{}, opts \\ []) do
    case Client.get("/notifications/#{id}", params, opts) do
      {:ok, notification} when is_map(notification) ->
        {:ok, from_api(notification)}

      {:ok, response} ->
        {:error, Error.from_response(response)}

      error ->
        error
    end
  end

  @doc """
  Replays a notification.

  Replaying a notification causes Paddle to resend the webhook to your endpoint.
  This is useful for debugging webhook handling or recovering from temporary failures.

  ## Examples

      PaddleBilling.Notification.replay("ntf_123")
      {:ok, %PaddleBilling.Notification{replayed_at: "2024-01-15T10:30:00Z"}}

      PaddleBilling.Notification.replay("ntf_failed")
      {:ok, %PaddleBilling.Notification{}}
  """
  @spec replay(String.t(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def replay(id, opts \\ []) do
    case Client.post("/notifications/#{id}/replay", %{}, opts) do
      {:ok, notification} when is_map(notification) ->
        {:ok, from_api(notification)}

      {:ok, response} ->
        {:error, Error.from_response(response)}

      error ->
        error
    end
  end

  @doc """
  Gets notification logs for a specific notification.

  Logs provide detailed information about delivery attempts, including
  HTTP status codes, response bodies, and retry information.

  ## Examples

      PaddleBilling.Notification.get_logs("ntf_123")
      {:ok, [%{"attempt" => 1, "response_code" => 200, "delivered_at" => "..."}, ...]}

      PaddleBilling.Notification.get_logs("ntf_failed")
      {:ok, [%{"attempt" => 1, "response_code" => 500, "error" => "Internal Server Error"}, ...]}
  """
  @spec get_logs(String.t(), keyword()) :: {:ok, [map()]} | {:error, Error.t()}
  def get_logs(id, opts \\ []) do
    Client.get("/notifications/#{id}/logs", %{}, opts)
  end

  @doc """
  Gets delivered notifications only.

  Convenience function to filter successfully delivered notifications.

  ## Examples

      PaddleBilling.Notification.list_delivered()
      {:ok, [%PaddleBilling.Notification{status: "delivered"}, ...]}

      PaddleBilling.Notification.list_delivered(["transaction.completed"])
      {:ok, [%PaddleBilling.Notification{}, ...]}
  """
  @spec list_delivered([String.t()], keyword()) :: {:ok, [t()]} | {:error, Error.t()}
  def list_delivered(types \\ [], opts \\ []) do
    filters = %{status: ["delivered"]}
    filters = if types != [], do: Map.put(filters, :type, types), else: filters
    list(filters, opts)
  end

  @doc """
  Gets failed notifications only.

  Convenience function to filter failed notification deliveries.

  ## Examples

      PaddleBilling.Notification.list_failed()
      {:ok, [%PaddleBilling.Notification{status: "failed"}, ...]}
  """
  @spec list_failed(keyword()) :: {:ok, [t()]} | {:error, Error.t()}
  def list_failed(opts \\ []) do
    list(%{status: ["failed"]}, opts)
  end

  @doc """
  Gets notifications for a specific event type.

  Convenience function to filter notifications by event type.

  ## Examples

      PaddleBilling.Notification.list_by_type("transaction.completed")
      {:ok, [%PaddleBilling.Notification{type: "transaction.completed"}, ...]}

      PaddleBilling.Notification.list_by_type("subscription.activated", ["delivered"])
      {:ok, [%PaddleBilling.Notification{}, ...]}
  """
  @spec list_by_type(String.t(), [String.t()], keyword()) :: {:ok, [t()]} | {:error, Error.t()}
  def list_by_type(event_type, statuses \\ [], opts \\ []) do
    filters = %{type: [event_type]}
    filters = if statuses != [], do: Map.put(filters, :status, statuses), else: filters
    list(filters, opts)
  end

  @doc """
  Gets recent notifications within the last N hours.

  Convenience function to get recent webhook activity.

  ## Examples

      PaddleBilling.Notification.list_recent(24)
      {:ok, [%PaddleBilling.Notification{}, ...]}

      PaddleBilling.Notification.list_recent(1, ["failed"])
      {:ok, [%PaddleBilling.Notification{}, ...]}
  """
  @spec list_recent(integer(), [String.t()], keyword()) :: {:ok, [t()]} | {:error, Error.t()}
  def list_recent(hours \\ 24, statuses \\ [], opts \\ []) do
    from_time =
      DateTime.utc_now()
      |> DateTime.add(-hours * 3600, :second)
      |> DateTime.to_iso8601()

    filters = %{
      occurred_at: %{
        from: from_time
      }
    }

    filters = if statuses != [], do: Map.put(filters, :status, statuses), else: filters
    list(filters, opts)
  end

  @doc """
  Checks if a notification was delivered successfully.

  ## Examples

      PaddleBilling.Notification.delivered?(%PaddleBilling.Notification{status: "delivered"})
      true

      PaddleBilling.Notification.delivered?(%PaddleBilling.Notification{status: "failed"})
      false
  """
  @spec delivered?(t()) :: boolean()
  def delivered?(%__MODULE__{status: "delivered"}), do: true
  def delivered?(%__MODULE__{}), do: false

  @doc """
  Checks if a notification delivery failed.

  ## Examples

      PaddleBilling.Notification.failed?(%PaddleBilling.Notification{status: "failed"})
      true
  """
  @spec failed?(t()) :: boolean()
  def failed?(%__MODULE__{status: "failed"}), do: true
  def failed?(%__MODULE__{}), do: false

  @doc """
  Checks if a notification has been replayed.

  ## Examples

      notification = %PaddleBilling.Notification{replayed_at: "2024-01-15T10:30:00Z"}
      PaddleBilling.Notification.replayed?(notification)
      true

      notification = %PaddleBilling.Notification{replayed_at: nil}
      PaddleBilling.Notification.replayed?(notification)
      false
  """
  @spec replayed?(t()) :: boolean()
  def replayed?(%__MODULE__{replayed_at: nil}), do: false
  def replayed?(%__MODULE__{replayed_at: replayed_at}) when is_binary(replayed_at), do: true
  def replayed?(%__MODULE__{}), do: false

  @doc """
  Gets the number of delivery attempts for a notification.

  ## Examples

      PaddleBilling.Notification.attempt_count(%PaddleBilling.Notification{times_attempted: 3})
      3
  """
  @spec attempt_count(t()) :: integer()
  def attempt_count(%__MODULE__{times_attempted: count}) when is_integer(count), do: count
  def attempt_count(%__MODULE__{}), do: 0

  # Private functions

  @spec from_api(map()) :: t()
  defp from_api(data) when is_map(data) do
    %__MODULE__{
      id: Map.get(data, "id"),
      type: Map.get(data, "type"),
      status: Map.get(data, "status"),
      payload: Map.get(data, "payload", %{}),
      occurred_at: Map.get(data, "occurred_at"),
      delivered_at: Map.get(data, "delivered_at"),
      replayed_at: Map.get(data, "replayed_at"),
      origin: Map.get(data, "origin"),
      last_attempt_at: Map.get(data, "last_attempt_at"),
      retry_at: Map.get(data, "retry_at"),
      times_attempted: Map.get(data, "times_attempted", 0),
      notification_setting_id: Map.get(data, "notification_setting_id")
    }
  end
end
