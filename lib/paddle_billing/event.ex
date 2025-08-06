defmodule PaddleBilling.Event do
  @moduledoc """
  Manage events and event types in Paddle Billing.

  Events represent activities that happen in Paddle, such as transactions
  being completed, subscriptions being activated, or customers being created.
  This module provides functionality to list events and get information about
  available event types for webhook configuration.
  """

  alias PaddleBilling.{Client, Error}

  @type t :: %__MODULE__{
          id: String.t(),
          event_type: String.t(),
          occurred_at: String.t(),
          data: map(),
          notification_id: String.t() | nil
        }

  defstruct [
    :id,
    :event_type,
    :occurred_at,
    :data,
    :notification_id
  ]

  @type list_params :: %{
          optional(:after) => String.t(),
          optional(:event_type) => [String.t()],
          optional(:occurred_at) => map(),
          optional(:per_page) => pos_integer()
        }

  @type event_type :: %{
          name: String.t(),
          description: String.t(),
          group: String.t(),
          available_versions: [integer()]
        }

  @doc """
  Lists all events.

  ## Parameters

  * `:after` - Return events after this event ID (pagination)
  * `:event_type` - Filter by specific event types
  * `:occurred_at` - Filter by occurrence date range
  * `:per_page` - Number of results per page (max 200)

  ## Examples

      PaddleBilling.Event.list()
      {:ok, [%PaddleBilling.Event{}, ...]}

      PaddleBilling.Event.list(%{
        event_type: ["transaction.completed", "subscription.activated"],
        per_page: 50
      })
      {:ok, [%PaddleBilling.Event{}, ...]}

      # Filter by date range
      PaddleBilling.Event.list(%{
        occurred_at: %{
          from: "2023-01-01T00:00:00Z",
          to: "2023-12-31T23:59:59Z"
        }
      })
      {:ok, [%PaddleBilling.Event{}, ...]}

      # Filter transaction events only
      PaddleBilling.Event.list(%{
        event_type: [
          "transaction.completed",
          "transaction.payment_failed",
          "transaction.canceled"
        ]
      })
      {:ok, [%PaddleBilling.Event{}, ...]}
  """
  @spec list(list_params(), keyword()) :: {:ok, [t()]} | {:error, Error.t()}
  def list(params \\ %{}, opts \\ []) do
    case Client.get("/events", params, opts) do
      {:ok, events} when is_list(events) ->
        {:ok, Enum.map(events, &from_api/1)}

      {:ok, response} ->
        {:error, Error.from_response(response)}

      error ->
        error
    end
  end

  @doc """
  Lists all available event types.

  Returns information about all event types that can be used for webhook
  subscriptions, including their descriptions, groups, and available API versions.

  ## Examples

      PaddleBilling.Event.list_types()
      {:ok, [
        %{
          "name" => "transaction.completed",
          "description" => "Occurs when a transaction is completed and payment is collected.",
          "group" => "transaction",
          "available_versions" => [1]
        },
        %{
          "name" => "subscription.activated", 
          "description" => "Occurs when a subscription becomes active.",
          "group" => "subscription",
          "available_versions" => [1]
        },
        ...
      ]}

      PaddleBilling.Event.list_types(config: custom_config)
      {:ok, [...]}
  """
  @spec list_types(keyword()) :: {:ok, [map()]} | {:error, Error.t()}
  def list_types(opts \\ []) do
    Client.get("/event-types", %{}, opts)
  end

  @doc """
  Gets events for a specific type.

  Convenience function to filter events by type.

  ## Examples

      PaddleBilling.Event.list_by_type("transaction.completed")
      {:ok, [%PaddleBilling.Event{event_type: "transaction.completed"}, ...]}

      PaddleBilling.Event.list_by_type("subscription.activated")
      {:ok, [%PaddleBilling.Event{}, ...]}
  """
  @spec list_by_type(String.t(), keyword()) :: {:ok, [t()]} | {:error, Error.t()}
  def list_by_type(event_type, opts \\ []) do
    list(%{event_type: [event_type]}, opts)
  end

  @doc """
  Gets recent events within the last N hours.

  Convenience function to get recent event activity.

  ## Examples

      PaddleBilling.Event.list_recent(24)
      {:ok, [%PaddleBilling.Event{}, ...]}

      PaddleBilling.Event.list_recent(1, ["transaction.completed"])
      {:ok, [%PaddleBilling.Event{}, ...]}
  """
  @spec list_recent(integer(), [String.t()], keyword()) :: {:ok, [t()]} | {:error, Error.t()}
  def list_recent(hours \\ 24, event_types \\ [], opts \\ []) do
    from_time =
      DateTime.utc_now()
      |> DateTime.add(-hours * 3600, :second)
      |> DateTime.to_iso8601()

    filters = %{
      occurred_at: %{
        from: from_time
      }
    }

    filters = if event_types != [], do: Map.put(filters, :event_type, event_types), else: filters
    list(filters, opts)
  end

  @doc """
  Gets transaction-related events.

  Convenience function to filter transaction events.

  ## Examples

      PaddleBilling.Event.list_transaction_events()
      {:ok, [%PaddleBilling.Event{event_type: "transaction.completed"}, ...]}
  """
  @spec list_transaction_events(keyword()) :: {:ok, [t()]} | {:error, Error.t()}
  def list_transaction_events(opts \\ []) do
    list(
      %{
        event_type: [
          "transaction.completed",
          "transaction.canceled",
          "transaction.payment_failed",
          "transaction.created",
          "transaction.updated"
        ]
      },
      opts
    )
  end

  @doc """
  Gets subscription-related events.

  Convenience function to filter subscription events.

  ## Examples

      PaddleBilling.Event.list_subscription_events()
      {:ok, [%PaddleBilling.Event{event_type: "subscription.activated"}, ...]}
  """
  @spec list_subscription_events(keyword()) :: {:ok, [t()]} | {:error, Error.t()}
  def list_subscription_events(opts \\ []) do
    list(
      %{
        event_type: [
          "subscription.activated",
          "subscription.canceled",
          "subscription.created",
          "subscription.imported",
          "subscription.paused",
          "subscription.resumed",
          "subscription.trialing",
          "subscription.updated"
        ]
      },
      opts
    )
  end

  @doc """
  Gets customer-related events.

  Convenience function to filter customer events.

  ## Examples

      PaddleBilling.Event.list_customer_events()
      {:ok, [%PaddleBilling.Event{event_type: "customer.created"}, ...]}
  """
  @spec list_customer_events(keyword()) :: {:ok, [t()]} | {:error, Error.t()}
  def list_customer_events(opts \\ []) do
    list(
      %{
        event_type: [
          "customer.created",
          "customer.updated",
          "customer.imported"
        ]
      },
      opts
    )
  end

  @doc """
  Gets event types by group.

  Filters event types to those belonging to a specific group.

  ## Examples

      {:ok, all_types} = PaddleBilling.Event.list_types()
      transaction_types = PaddleBilling.Event.filter_types_by_group(all_types, "transaction")
      # Returns only transaction-related event types

      subscription_types = PaddleBilling.Event.filter_types_by_group(all_types, "subscription")
      # Returns only subscription-related event types
  """
  @spec filter_types_by_group([map()], String.t()) :: [map()]
  def filter_types_by_group(event_types, group) when is_list(event_types) do
    Enum.filter(event_types, fn event_type ->
      Map.get(event_type, "group") == group
    end)
  end

  @doc """
  Gets all available event groups.

  Extracts unique groups from event types.

  ## Examples

      {:ok, all_types} = PaddleBilling.Event.list_types()
      groups = PaddleBilling.Event.get_event_groups(all_types)
      # Returns ["transaction", "subscription", "customer", "adjustment", ...]
  """
  @spec get_event_groups([map()]) :: [String.t()]
  def get_event_groups(event_types) when is_list(event_types) do
    event_types
    |> Enum.map(fn event_type -> Map.get(event_type, "group") end)
    |> Enum.filter(& &1)
    |> Enum.uniq()
    |> Enum.sort()
  end

  @doc """
  Checks if an event type is available.

  ## Examples

      {:ok, all_types} = PaddleBilling.Event.list_types()
      PaddleBilling.Event.event_type_available?(all_types, "transaction.completed")
      true

      PaddleBilling.Event.event_type_available?(all_types, "nonexistent.event")
      false  
  """
  @spec event_type_available?([map()], String.t()) :: boolean()
  def event_type_available?(event_types, event_name) when is_list(event_types) do
    Enum.any?(event_types, fn event_type ->
      Map.get(event_type, "name") == event_name
    end)
  end

  @doc """
  Checks if an event is a transaction event.

  ## Examples

      PaddleBilling.Event.transaction_event?(%PaddleBilling.Event{event_type: "transaction.completed"})
      true

      PaddleBilling.Event.transaction_event?(%PaddleBilling.Event{event_type: "customer.created"})
      false
  """
  @spec transaction_event?(t()) :: boolean()
  def transaction_event?(%__MODULE__{event_type: event_type}) do
    String.starts_with?(event_type, "transaction.")
  end

  @doc """
  Checks if an event is a subscription event.

  ## Examples

      PaddleBilling.Event.subscription_event?(%PaddleBilling.Event{event_type: "subscription.activated"})
      true
  """
  @spec subscription_event?(t()) :: boolean()
  def subscription_event?(%__MODULE__{event_type: event_type}) do
    String.starts_with?(event_type, "subscription.")
  end

  @doc """
  Checks if an event is a customer event.

  ## Examples

      PaddleBilling.Event.customer_event?(%PaddleBilling.Event{event_type: "customer.created"})
      true
  """
  @spec customer_event?(t()) :: boolean()
  def customer_event?(%__MODULE__{event_type: event_type}) do
    String.starts_with?(event_type, "customer.")
  end

  @doc """
  Checks if an event has an associated notification.

  ## Examples

      event = %PaddleBilling.Event{notification_id: "ntf_123"}
      PaddleBilling.Event.has_notification?(event)
      true

      event = %PaddleBilling.Event{notification_id: nil}
      PaddleBilling.Event.has_notification?(event)
      false
  """
  @spec has_notification?(t()) :: boolean()
  def has_notification?(%__MODULE__{notification_id: nil}), do: false

  def has_notification?(%__MODULE__{notification_id: notification_id})
      when is_binary(notification_id),
      do: true

  def has_notification?(%__MODULE__{}), do: false

  # Private functions

  @spec from_api(map()) :: t()
  defp from_api(data) when is_map(data) do
    %__MODULE__{
      id: Map.get(data, "id"),
      event_type: Map.get(data, "event_type"),
      occurred_at: Map.get(data, "occurred_at"),
      data: Map.get(data, "data", %{}),
      notification_id: Map.get(data, "notification_id")
    }
  end
end
