defmodule PaddleBilling.NotificationTest do
  use ExUnit.Case, async: true
  alias PaddleBilling.{Notification, Error}

  setup do
    bypass = Bypass.open()

    config = %{
      api_key: "pdl_test_123456789",
      environment: :sandbox,
      base_url: "http://localhost:#{bypass.port}",
      timeout: 30_000,
      retry: false
    }

    {:ok, bypass: bypass, config: config}
  end

  describe "list/2" do
    test "returns list of notifications", %{bypass: bypass, config: config} do
      notifications_response = [
        %{
          "id" => "ntf_123",
          "type" => "transaction.completed",
          "status" => "delivered",
          "payload" => %{"transaction_id" => "txn_123"},
          "occurred_at" => "2024-01-15T10:30:00Z",
          "delivered_at" => "2024-01-15T10:30:05Z",
          "times_attempted" => 1,
          "notification_setting_id" => "ntfset_456"
        }
      ]

      Bypass.expect(bypass, "GET", "/notifications", fn conn ->
        Plug.Conn.resp(
          conn,
          200,
          Jason.encode!(%{"data" => notifications_response})
        )
      end)

      assert {:ok, [notification]} = Notification.list(%{}, config: config)
      assert notification.id == "ntf_123"
      assert notification.type == "transaction.completed"
      assert notification.status == "delivered"
      assert notification.times_attempted == 1
    end

    test "accepts query parameters", %{bypass: bypass, config: config} do
      Bypass.expect(bypass, "GET", "/notifications", fn conn ->
        assert conn.query_string =~ "status=delivered"
        assert conn.query_string =~ "type=transaction.completed"
        assert conn.query_string =~ "per_page=50"

        Plug.Conn.resp(conn, 200, Jason.encode!(%{"data" => []}))
      end)

      params = %{
        status: ["delivered"],
        type: ["transaction.completed"],
        per_page: 50
      }

      assert {:ok, []} = Notification.list(params, config: config)
    end

    test "handles API errors", %{bypass: bypass, config: config} do
      Bypass.expect(bypass, "GET", "/notifications", fn conn ->
        Plug.Conn.resp(conn, 500, Jason.encode!(%{"error" => "Internal Server Error"}))
      end)

      assert {:error, %Error{}} = Notification.list(%{}, config: config)
    end
  end

  describe "get/3" do
    test "returns notification by ID", %{bypass: bypass, config: config} do
      notification_response = %{
        "id" => "ntf_123",
        "type" => "customer.created",
        "status" => "failed",
        "payload" => %{"customer_id" => "ctm_456"},
        "occurred_at" => "2024-01-15T10:30:00Z",
        "last_attempt_at" => "2024-01-15T10:35:00Z",
        "retry_at" => "2024-01-15T11:00:00Z",
        "times_attempted" => 3,
        "notification_setting_id" => "ntfset_789"
      }

      Bypass.expect(bypass, "GET", "/notifications/ntf_123", fn conn ->
        Plug.Conn.resp(
          conn,
          200,
          Jason.encode!(%{"data" => notification_response})
        )
      end)

      assert {:ok, notification} = Notification.get("ntf_123", %{}, config: config)
      assert notification.id == "ntf_123"
      assert notification.type == "customer.created"
      assert notification.status == "failed"
      assert notification.times_attempted == 3
      assert notification.retry_at == "2024-01-15T11:00:00Z"
    end

    test "handles not found", %{bypass: bypass, config: config} do
      Bypass.expect(bypass, "GET", "/notifications/invalid", fn conn ->
        Plug.Conn.resp(conn, 404, Jason.encode!(%{"error" => "Not Found"}))
      end)

      assert {:error, %Error{}} = Notification.get("invalid", %{}, config: config)
    end
  end

  describe "replay/2" do
    test "replays notification successfully", %{bypass: bypass, config: config} do
      replayed_response = %{
        "id" => "ntf_123",
        "type" => "transaction.completed",
        "status" => "delivered",
        "payload" => %{"transaction_id" => "txn_123"},
        "occurred_at" => "2024-01-15T10:30:00Z",
        "delivered_at" => "2024-01-15T10:30:05Z",
        "replayed_at" => "2024-01-15T14:00:00Z",
        "times_attempted" => 2,
        "notification_setting_id" => "ntfset_456"
      }

      Bypass.expect(bypass, "POST", "/notifications/ntf_123/replay", fn conn ->
        Plug.Conn.resp(
          conn,
          200,
          Jason.encode!(%{"data" => replayed_response})
        )
      end)

      assert {:ok, notification} = Notification.replay("ntf_123", config: config)
      assert notification.id == "ntf_123"
      assert notification.replayed_at == "2024-01-15T14:00:00Z"
      assert notification.times_attempted == 2
    end

    test "handles replay errors", %{bypass: bypass, config: config} do
      Bypass.expect(bypass, "POST", "/notifications/ntf_123/replay", fn conn ->
        Plug.Conn.resp(conn, 500, Jason.encode!(%{"error" => "Internal Server Error"}))
      end)

      assert {:error, %Error{}} = Notification.replay("ntf_123", config: config)
    end
  end

  describe "get_logs/2" do
    test "returns notification logs", %{bypass: bypass, config: config} do
      logs_response = [
        %{
          "attempt" => 1,
          "response_code" => 500,
          "response_body" => "Internal Server Error",
          "attempted_at" => "2024-01-15T10:30:05Z"
        },
        %{
          "attempt" => 2,
          "response_code" => 200,
          "response_body" => "OK",
          "attempted_at" => "2024-01-15T10:35:00Z"
        }
      ]

      Bypass.expect(bypass, "GET", "/notifications/ntf_123/logs", fn conn ->
        Plug.Conn.resp(
          conn,
          200,
          Jason.encode!(%{"data" => logs_response})
        )
      end)

      assert {:ok, logs} = Notification.get_logs("ntf_123", config: config)
      assert length(logs) == 2
      assert List.first(logs)["attempt"] == 1
      assert List.first(logs)["response_code"] == 500
    end
  end

  describe "list_delivered/2" do
    test "filters delivered notifications", %{bypass: bypass, config: config} do
      Bypass.expect(bypass, "GET", "/notifications", fn conn ->
        assert conn.query_string =~ "status=delivered"

        Plug.Conn.resp(conn, 200, Jason.encode!(%{"data" => []}))
      end)

      assert {:ok, []} = Notification.list_delivered([], config: config)
    end

    test "filters delivered notifications by type", %{bypass: bypass, config: config} do
      Bypass.expect(bypass, "GET", "/notifications", fn conn ->
        assert conn.query_string =~ "status=delivered"
        assert conn.query_string =~ "type=transaction.completed"

        Plug.Conn.resp(conn, 200, Jason.encode!(%{"data" => []}))
      end)

      assert {:ok, []} = Notification.list_delivered(["transaction.completed"], config: config)
    end
  end

  describe "list_failed/2" do
    test "filters failed notifications", %{bypass: bypass, config: config} do
      Bypass.expect(bypass, "GET", "/notifications", fn conn ->
        assert conn.query_string =~ "status=failed"

        Plug.Conn.resp(conn, 200, Jason.encode!(%{"data" => []}))
      end)

      assert {:ok, []} = Notification.list_failed(config: config)
    end
  end

  describe "list_by_type/3" do
    test "filters notifications by event type", %{bypass: bypass, config: config} do
      Bypass.expect(bypass, "GET", "/notifications", fn conn ->
        assert conn.query_string =~ "type=subscription.activated"

        Plug.Conn.resp(conn, 200, Jason.encode!(%{"data" => []}))
      end)

      assert {:ok, []} = Notification.list_by_type("subscription.activated", [], config: config)
    end

    test "filters notifications by event type and status", %{bypass: bypass, config: config} do
      Bypass.expect(bypass, "GET", "/notifications", fn conn ->
        assert conn.query_string =~ "type=subscription.activated"
        assert conn.query_string =~ "status=delivered"

        Plug.Conn.resp(conn, 200, Jason.encode!(%{"data" => []}))
      end)

      assert {:ok, []} =
               Notification.list_by_type("subscription.activated", ["delivered"], config: config)
    end
  end

  describe "list_recent/3" do
    test "filters recent notifications", %{bypass: bypass, config: config} do
      Bypass.expect(bypass, "GET", "/notifications", fn conn ->
        assert conn.query_string =~ "occurred_at"

        Plug.Conn.resp(conn, 200, Jason.encode!(%{"data" => []}))
      end)

      assert {:ok, []} = Notification.list_recent(24, [], config: config)
    end
  end

  describe "helper functions" do
    test "delivered?/1" do
      delivered = %Notification{status: "delivered"}
      failed = %Notification{status: "failed"}

      assert Notification.delivered?(delivered) == true
      assert Notification.delivered?(failed) == false
    end

    test "failed?/1" do
      delivered = %Notification{status: "delivered"}
      failed = %Notification{status: "failed"}

      assert Notification.failed?(delivered) == false
      assert Notification.failed?(failed) == true
    end

    test "replayed?/1" do
      replayed = %Notification{replayed_at: "2024-01-15T10:30:00Z"}
      not_replayed = %Notification{replayed_at: nil}

      assert Notification.replayed?(replayed) == true
      assert Notification.replayed?(not_replayed) == false
    end

    test "attempt_count/1" do
      notification = %Notification{times_attempted: 3}
      no_attempts = %Notification{times_attempted: nil}

      assert Notification.attempt_count(notification) == 3
      assert Notification.attempt_count(no_attempts) == 0
    end
  end
end
