defmodule PaddleBilling.NotificationSetting do
  @moduledoc """
  Manage notification settings in Paddle Billing.

  Notification settings define webhook endpoints and configure which events
  should be sent to your application. You can set up multiple endpoints,
  filter events by type, and configure delivery options including retry
  policies and authentication headers.
  """

  alias PaddleBilling.{Client, Error}

  @type t :: %__MODULE__{
          id: String.t(),
          description: String.t(),
          destination: String.t(),
          active: boolean(),
          endpoint_secret_key: String.t() | nil,
          include_sensitive_fields: boolean(),
          subscribed_events: [map()],
          api_version: integer(),
          created_at: String.t(),
          updated_at: String.t()
        }

  defstruct [
    :id,
    :description,
    :destination,
    :active,
    :endpoint_secret_key,
    :include_sensitive_fields,
    :subscribed_events,
    :api_version,
    :created_at,
    :updated_at
  ]

  @type list_params :: %{
          optional(:after) => String.t(),
          optional(:id) => [String.t()],
          optional(:active) => boolean(),
          optional(:destination) => String.t(),
          optional(:per_page) => pos_integer(),
          optional(:include) => [String.t()]
        }

  @type create_params :: %{
          :description => String.t(),
          :destination => String.t(),
          :subscribed_events => [subscribed_event()],
          optional(:active) => boolean(),
          optional(:include_sensitive_fields) => boolean(),
          optional(:api_version) => integer()
        }

  @type update_params :: %{
          optional(:description) => String.t(),
          optional(:destination) => String.t(),
          optional(:subscribed_events) => [subscribed_event()],
          optional(:active) => boolean(),
          optional(:include_sensitive_fields) => boolean(),
          optional(:api_version) => integer()
        }

  @type subscribed_event :: %{
          :name => String.t(),
          optional(:description) => String.t(),
          optional(:group) => String.t()
        }

  @doc """
  Lists all notification settings.

  ## Parameters

  * `:after` - Return settings after this setting ID (pagination)
  * `:id` - Filter by specific setting IDs
  * `:active` - Filter by active status (true/false)
  * `:destination` - Filter by destination URL
  * `:per_page` - Number of results per page (max 200)
  * `:include` - Include related resources

  ## Examples

      PaddleBilling.NotificationSetting.list()
      {:ok, [%PaddleBilling.NotificationSetting{}, ...]}

      PaddleBilling.NotificationSetting.list(%{
        active: true,
        per_page: 50
      })
      {:ok, [%PaddleBilling.NotificationSetting{}, ...]}

      # Filter by destination
      PaddleBilling.NotificationSetting.list(%{
        destination: "https://api.myapp.com/webhooks"
      })
      {:ok, [%PaddleBilling.NotificationSetting{}, ...]}
  """
  @spec list(list_params(), keyword()) :: {:ok, [t()]} | {:error, Error.t()}
  def list(params \\ %{}, opts \\ []) do
    case Client.get("/notification-settings", params, opts) do
      {:ok, settings} when is_list(settings) ->
        {:ok, Enum.map(settings, &from_api/1)}

      {:ok, response} ->
        {:error, Error.from_response(response)}

      error ->
        error
    end
  end

  @doc """
  Gets a notification setting by ID.

  ## Parameters

  * `:include` - Include related resources

  ## Examples

      PaddleBilling.NotificationSetting.get("ntfset_123")
      {:ok, %PaddleBilling.NotificationSetting{id: "ntfset_123", active: true}}

      PaddleBilling.NotificationSetting.get("invalid_id")
      {:error, %PaddleBilling.Error{type: :not_found_error}}
  """
  @spec get(String.t(), map(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def get(id, params \\ %{}, opts \\ []) do
    case Client.get("/notification-settings/#{id}", params, opts) do
      {:ok, setting} when is_map(setting) ->
        {:ok, from_api(setting)}

      {:ok, response} ->
        {:error, Error.from_response(response)}

      error ->
        error
    end
  end

  @doc """
  Creates a new notification setting.

  ## Parameters

  * `description` - Description of the webhook endpoint (required)
  * `destination` - Webhook endpoint URL (required, must be HTTPS)
  * `subscribed_events` - Array of events to subscribe to (required)
  * `active` - Whether the setting is active (optional, default: true)
  * `include_sensitive_fields` - Include sensitive data in webhooks (optional, default: false)
  * `api_version` - API version for webhook payloads (optional, default: 1)

  ## Examples

      # Basic webhook setup
      PaddleBilling.NotificationSetting.create(%{
        description: "Production Webhook Endpoint",
        destination: "https://api.myapp.com/paddle/webhooks",
        subscribed_events: [
          %{name: "transaction.completed"},
          %{name: "transaction.payment_failed"},
          %{name: "subscription.activated"},
          %{name: "subscription.canceled"}
        ]
      })
      {:ok, %PaddleBilling.NotificationSetting{}}

      # Advanced webhook with all event types
      PaddleBilling.NotificationSetting.create(%{
        description: "Comprehensive Webhook Handler",
        destination: "https://webhooks.enterprise.com/paddle",
        subscribed_events: [
          %{
            name: "transaction.completed",
            description: "Payment successful notifications"
          },
          %{
            name: "subscription.activated",
            description: "New subscription notifications"
          },
          %{
            name: "customer.created",
            description: "New customer notifications"
          },
          %{
            name: "adjustment.created",
            description: "Refund and adjustment notifications"
          }
        ],
        active: true,
        include_sensitive_fields: true,
        api_version: 1
      })
      {:ok, %PaddleBilling.NotificationSetting{}}

      # Development webhook (inactive by default)
      PaddleBilling.NotificationSetting.create(%{
        description: "Development Testing Endpoint",
        destination: "https://dev-api.myapp.com/webhooks",
        subscribed_events: [
          %{name: "transaction.completed"}
        ],
        active: false,
        include_sensitive_fields: false
      })
      {:ok, %PaddleBilling.NotificationSetting{}}
  """
  @spec create(create_params(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def create(params, opts \\ []) do
    case Client.post("/notification-settings", params, opts) do
      {:ok, setting} when is_map(setting) ->
        {:ok, from_api(setting)}

      {:ok, response} ->
        {:error, Error.from_response(response)}

      error ->
        error
    end
  end

  @doc """
  Updates a notification setting.

  ## Parameters

  * `description` - Description of the webhook endpoint (optional)
  * `destination` - Webhook endpoint URL (optional)
  * `subscribed_events` - Array of events to subscribe to (optional)
  * `active` - Whether the setting is active (optional)
  * `include_sensitive_fields` - Include sensitive data in webhooks (optional)
  * `api_version` - API version for webhook payloads (optional)

  ## Examples

      PaddleBilling.NotificationSetting.update("ntfset_123", %{
        description: "Updated Production Webhook",
        active: true
      })
      {:ok, %PaddleBilling.NotificationSetting{}}

      # Add more event subscriptions
      PaddleBilling.NotificationSetting.update("ntfset_123", %{
        subscribed_events: [
          %{name: "transaction.completed"},
          %{name: "transaction.payment_failed"},
          %{name: "subscription.activated"},
          %{name: "subscription.canceled"},
          %{name: "customer.created"},
          %{name: "customer.updated"}
        ]
      })
      {:ok, %PaddleBilling.NotificationSetting{}}

      # Update destination URL
      PaddleBilling.NotificationSetting.update("ntfset_123", %{
        destination: "https://new-api.myapp.com/webhooks"
      })
      {:ok, %PaddleBilling.NotificationSetting{}}
  """
  @spec update(String.t(), update_params(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def update(id, params, opts \\ []) do
    case Client.patch("/notification-settings/#{id}", params, opts) do
      {:ok, setting} when is_map(setting) ->
        {:ok, from_api(setting)}

      {:ok, response} ->
        {:error, Error.from_response(response)}

      error ->
        error
    end
  end

  @doc """
  Deletes a notification setting.

  ## Examples

      PaddleBilling.NotificationSetting.delete("ntfset_123")
      {:ok, nil}
  """
  @spec delete(String.t(), keyword()) :: {:ok, nil} | {:error, Error.t()}
  def delete(id, opts \\ []) do
    case Client.request(:delete, "/notification-settings/#{id}", nil, %{}, opts) do
      {:ok, _} ->
        {:ok, nil}

      error ->
        error
    end
  end

  @doc """
  Gets active notification settings only.

  Convenience function to filter active webhook endpoints.

  ## Examples

      PaddleBilling.NotificationSetting.list_active()
      {:ok, [%PaddleBilling.NotificationSetting{active: true}, ...]}
  """
  @spec list_active(keyword()) :: {:ok, [t()]} | {:error, Error.t()}
  def list_active(opts \\ []) do
    list(%{active: true}, opts)
  end

  @doc """
  Gets inactive notification settings only.

  Convenience function to filter inactive webhook endpoints.

  ## Examples

      PaddleBilling.NotificationSetting.list_inactive()
      {:ok, [%PaddleBilling.NotificationSetting{active: false}, ...]}
  """
  @spec list_inactive(keyword()) :: {:ok, [t()]} | {:error, Error.t()}
  def list_inactive(opts \\ []) do
    list(%{active: false}, opts)
  end

  @doc """
  Activates a notification setting.

  Convenience function to enable webhook delivery.

  ## Examples

      PaddleBilling.NotificationSetting.activate("ntfset_123")
      {:ok, %PaddleBilling.NotificationSetting{active: true}}
  """
  @spec activate(String.t(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def activate(id, opts \\ []) do
    update(id, %{active: true}, opts)
  end

  @doc """
  Deactivates a notification setting.

  Convenience function to disable webhook delivery.

  ## Examples

      PaddleBilling.NotificationSetting.deactivate("ntfset_123")
      {:ok, %PaddleBilling.NotificationSetting{active: false}}
  """
  @spec deactivate(String.t(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def deactivate(id, opts \\ []) do
    update(id, %{active: false}, opts)
  end

  @doc """
  Checks if a notification setting is active.

  ## Examples

      PaddleBilling.NotificationSetting.active?(%PaddleBilling.NotificationSetting{active: true})
      true

      PaddleBilling.NotificationSetting.active?(%PaddleBilling.NotificationSetting{active: false})
      false
  """
  @spec active?(t()) :: boolean()
  def active?(%__MODULE__{active: true}), do: true
  def active?(%__MODULE__{}), do: false

  @doc """
  Checks if a notification setting includes sensitive fields.

  ## Examples

      setting = %PaddleBilling.NotificationSetting{include_sensitive_fields: true}
      PaddleBilling.NotificationSetting.includes_sensitive_fields?(setting)
      true
  """
  @spec includes_sensitive_fields?(t()) :: boolean()
  def includes_sensitive_fields?(%__MODULE__{include_sensitive_fields: true}), do: true
  def includes_sensitive_fields?(%__MODULE__{}), do: false

  @doc """
  Gets the event names this setting is subscribed to.

  ## Examples

      setting = %PaddleBilling.NotificationSetting{
        subscribed_events: [
          %{"name" => "transaction.completed"},
          %{"name" => "subscription.activated"}
        ]
      }
      PaddleBilling.NotificationSetting.subscribed_event_names(setting)
      ["transaction.completed", "subscription.activated"]
  """
  @spec subscribed_event_names(t()) :: [String.t()]
  def subscribed_event_names(%__MODULE__{subscribed_events: events}) do
    Enum.map(events, fn event -> Map.get(event, "name") end)
    |> Enum.filter(& &1)
  end

  @doc """
  Checks if a setting is subscribed to a specific event.

  ## Examples

      setting = %PaddleBilling.NotificationSetting{
        subscribed_events: [%{"name" => "transaction.completed"}]
      }
      PaddleBilling.NotificationSetting.subscribed_to?(setting, "transaction.completed")
      true

      PaddleBilling.NotificationSetting.subscribed_to?(setting, "customer.created")
      false
  """
  @spec subscribed_to?(t(), String.t()) :: boolean()
  def subscribed_to?(%__MODULE__{} = setting, event_name) do
    event_name in subscribed_event_names(setting)
  end

  # Private functions

  @spec from_api(map()) :: t()
  defp from_api(data) when is_map(data) do
    %__MODULE__{
      id: Map.get(data, "id"),
      description: Map.get(data, "description"),
      destination: Map.get(data, "destination"),
      active: Map.get(data, "active", false),
      endpoint_secret_key: Map.get(data, "endpoint_secret_key"),
      include_sensitive_fields: Map.get(data, "include_sensitive_fields", false),
      subscribed_events: ensure_list(Map.get(data, "subscribed_events", [])),
      api_version: Map.get(data, "api_version", 1),
      created_at: Map.get(data, "created_at"),
      updated_at: Map.get(data, "updated_at")
    }
  end

  @spec ensure_list(any()) :: [any()]
  defp ensure_list(nil), do: []
  defp ensure_list(list) when is_list(list), do: list
  defp ensure_list(_), do: []
end
