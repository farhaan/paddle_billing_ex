defmodule PaddleBilling.EventTest do
  use ExUnit.Case, async: true
  alias PaddleBilling.{Event, Error}
  import PaddleBilling.TestHelpers

  setup do
    bypass = Bypass.open()
    config = create_bypass_config(bypass)
    {:ok, bypass: bypass, config: config}
  end

  describe "list/2" do
    test "returns list of events", %{bypass: bypass, config: config} do
      events_response = [
        %{
          "id" => "evt_123",
          "event_type" => "transaction.completed",
          "occurred_at" => "2024-01-15T10:30:00Z",
          "data" => %{
            "transaction_id" => "txn_456",
            "status" => "completed"
          },
          "notification_id" => "ntf_789"
        }
      ]

      Bypass.expect(bypass, "GET", "/events", fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(200, Jason.encode!(events_response))
      end)

      assert {:ok, [event]} = Event.list(%{}, config: config)
      assert event.id == "evt_123"
      assert event.event_type == "transaction.completed"
      assert event.notification_id == "ntf_789"
      assert event.data["transaction_id"] == "txn_456"
    end

    test "accepts query parameters", %{bypass: bypass, config: config} do
      Bypass.expect(bypass, "GET", "/events", fn conn ->
        assert conn.query_string =~ "event_type=transaction.completed"
        assert conn.query_string =~ "per_page=50"

        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(200, Jason.encode!([]))
      end)

      params = %{
        event_type: ["transaction.completed"],
        per_page: 50
      }

      assert {:ok, []} = Event.list(params, config: config)
    end

    test "handles API errors", %{bypass: bypass, config: config} do
      setup_error_response(bypass, "GET", "/events", 500, %{"error" => "Internal Server Error"})

      assert {:error, %Error{}} = Event.list(%{}, config: config)
    end
  end

  describe "list_types/1" do
    test "returns event types", %{bypass: bypass, config: config} do
      types_response = [
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
        }
      ]

      Bypass.expect(bypass, "GET", "/event-types", fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(200, Jason.encode!(types_response))
      end)

      assert {:ok, types} = Event.list_types(config: config)
      assert length(types) == 2

      transaction_type = Enum.find(types, &(&1["name"] == "transaction.completed"))
      assert transaction_type["group"] == "transaction"
      assert transaction_type["available_versions"] == [1]
    end

    test "handles API errors", %{bypass: bypass, config: config} do
      setup_error_response(bypass, "GET", "/event-types", 500, %{
        "error" => "Internal Server Error"
      })

      assert {:error, %Error{}} = Event.list_types(config: config)
    end
  end

  describe "list_by_type/2" do
    test "filters events by type", %{bypass: bypass, config: config} do
      Bypass.expect(bypass, "GET", "/events", fn conn ->
        assert conn.query_string =~ "event_type=subscription.activated"

        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(200, Jason.encode!([]))
      end)

      assert {:ok, []} = Event.list_by_type("subscription.activated", config: config)
    end
  end

  describe "list_recent/3" do
    test "filters recent events", %{bypass: bypass, config: config} do
      Bypass.expect(bypass, "GET", "/events", fn conn ->
        assert conn.query_string =~ "occurred_at"

        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(200, Jason.encode!([]))
      end)

      assert {:ok, []} = Event.list_recent(24, [], config: config)
    end

    test "filters recent events by type", %{bypass: bypass, config: config} do
      Bypass.expect(bypass, "GET", "/events", fn conn ->
        assert conn.query_string =~ "occurred_at"
        assert conn.query_string =~ "event_type=transaction.completed"

        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(200, Jason.encode!([]))
      end)

      assert {:ok, []} = Event.list_recent(1, ["transaction.completed"], config: config)
    end
  end

  describe "list_transaction_events/1" do
    test "filters transaction events", %{bypass: bypass, config: config} do
      Bypass.expect(bypass, "GET", "/events", fn conn ->
        assert conn.query_string =~ "event_type=transaction.completed"
        assert conn.query_string =~ "transaction.canceled"
        assert conn.query_string =~ "transaction.payment_failed"

        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(200, Jason.encode!([]))
      end)

      assert {:ok, []} = Event.list_transaction_events(config: config)
    end
  end

  describe "list_subscription_events/1" do
    test "filters subscription events", %{bypass: bypass, config: config} do
      Bypass.expect(bypass, "GET", "/events", fn conn ->
        assert conn.query_string =~ "event_type=subscription.activated"
        assert conn.query_string =~ "subscription.canceled"
        assert conn.query_string =~ "subscription.created"

        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(200, Jason.encode!([]))
      end)

      assert {:ok, []} = Event.list_subscription_events(config: config)
    end
  end

  describe "list_customer_events/1" do
    test "filters customer events", %{bypass: bypass, config: config} do
      Bypass.expect(bypass, "GET", "/events", fn conn ->
        # Client uses comma-separated format for array parameters
        assert conn.query_string =~ "event_type=customer.created"
        assert conn.query_string =~ "customer.updated"
        assert conn.query_string =~ "customer.imported"

        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.resp(200, Jason.encode!([]))
      end)

      assert {:ok, []} = Event.list_customer_events(config: config)
    end
  end

  describe "helper functions" do
    test "filter_types_by_group/2" do
      event_types = [
        %{"name" => "transaction.completed", "group" => "transaction"},
        %{"name" => "subscription.activated", "group" => "subscription"},
        %{"name" => "transaction.canceled", "group" => "transaction"}
      ]

      transaction_types = Event.filter_types_by_group(event_types, "transaction")
      assert length(transaction_types) == 2
      assert Enum.all?(transaction_types, &(&1["group"] == "transaction"))

      subscription_types = Event.filter_types_by_group(event_types, "subscription")
      assert length(subscription_types) == 1
      assert List.first(subscription_types)["name"] == "subscription.activated"
    end

    test "get_event_groups/1" do
      event_types = [
        %{"name" => "transaction.completed", "group" => "transaction"},
        %{"name" => "subscription.activated", "group" => "subscription"},
        %{"name" => "customer.created", "group" => "customer"},
        %{"name" => "transaction.canceled", "group" => "transaction"}
      ]

      groups = Event.get_event_groups(event_types)
      assert groups == ["customer", "subscription", "transaction"]
      assert length(groups) == 3
    end

    test "event_type_available?/2" do
      event_types = [
        %{"name" => "transaction.completed", "group" => "transaction"},
        %{"name" => "subscription.activated", "group" => "subscription"}
      ]

      assert Event.event_type_available?(event_types, "transaction.completed") == true
      assert Event.event_type_available?(event_types, "subscription.activated") == true
      assert Event.event_type_available?(event_types, "nonexistent.event") == false
    end

    test "transaction_event?/1" do
      transaction_event = %Event{event_type: "transaction.completed"}
      subscription_event = %Event{event_type: "subscription.activated"}

      assert Event.transaction_event?(transaction_event) == true
      assert Event.transaction_event?(subscription_event) == false
    end

    test "subscription_event?/1" do
      transaction_event = %Event{event_type: "transaction.completed"}
      subscription_event = %Event{event_type: "subscription.activated"}

      assert Event.subscription_event?(transaction_event) == false
      assert Event.subscription_event?(subscription_event) == true
    end

    test "customer_event?/1" do
      customer_event = %Event{event_type: "customer.created"}
      transaction_event = %Event{event_type: "transaction.completed"}

      assert Event.customer_event?(customer_event) == true
      assert Event.customer_event?(transaction_event) == false
    end

    test "has_notification?/1" do
      with_notification = %Event{notification_id: "ntf_123"}
      without_notification = %Event{notification_id: nil}

      assert Event.has_notification?(with_notification) == true
      assert Event.has_notification?(without_notification) == false
    end
  end
end
