defmodule PaddleBilling.NotificationSettingTest do
  use ExUnit.Case, async: true
  alias PaddleBilling.{NotificationSetting, Error}

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
    test "returns list of notification settings", %{bypass: bypass, config: config} do
      settings_response = [
        %{
          "id" => "ntfset_123",
          "description" => "Production Webhook",
          "destination" => "https://api.myapp.com/webhooks",
          "active" => true,
          "include_sensitive_fields" => false,
          "subscribed_events" => [
            %{"name" => "transaction.completed"},
            %{"name" => "subscription.activated"}
          ],
          "api_version" => 1,
          "created_at" => "2024-01-15T10:30:00Z",
          "updated_at" => "2024-01-15T10:30:00Z"
        }
      ]

      Bypass.expect(bypass, "GET", "/notification-settings", fn conn ->
        Plug.Conn.resp(
          conn,
          200,
          Jason.encode!(%{"data" => settings_response})
        )
      end)

      assert {:ok, [setting]} = NotificationSetting.list(%{}, config: config)
      assert setting.id == "ntfset_123"
      assert setting.description == "Production Webhook"
      assert setting.active == true
      assert length(setting.subscribed_events) == 2
    end

    test "accepts query parameters", %{bypass: bypass, config: config} do
      Bypass.expect(bypass, "GET", "/notification-settings", fn conn ->
        assert conn.query_string =~ "active=true"
        assert conn.query_string =~ "per_page=50"

        Plug.Conn.resp(conn, 200, Jason.encode!(%{"data" => []}))
      end)

      params = %{
        active: true,
        per_page: 50
      }

      assert {:ok, []} = NotificationSetting.list(params, config: config)
    end

    test "handles API errors", %{bypass: bypass, config: config} do
      Bypass.expect(bypass, "GET", "/notification-settings", fn conn ->
        Plug.Conn.resp(conn, 500, Jason.encode!(%{"error" => "Internal Server Error"}))
      end)

      assert {:error, %Error{}} = NotificationSetting.list(%{}, config: config)
    end
  end

  describe "get/3" do
    test "returns notification setting by ID", %{bypass: bypass, config: config} do
      setting_response = %{
        "id" => "ntfset_123",
        "description" => "Development Webhook",
        "destination" => "https://dev-api.myapp.com/webhooks",
        "active" => false,
        "include_sensitive_fields" => true,
        "subscribed_events" => [
          %{"name" => "transaction.completed", "description" => "Payment notifications"}
        ],
        "api_version" => 1,
        "created_at" => "2024-01-15T10:30:00Z",
        "updated_at" => "2024-01-15T11:00:00Z"
      }

      Bypass.expect(bypass, "GET", "/notification-settings/ntfset_123", fn conn ->
        Plug.Conn.resp(
          conn,
          200,
          Jason.encode!(%{"data" => setting_response})
        )
      end)

      assert {:ok, setting} = NotificationSetting.get("ntfset_123", %{}, config: config)
      assert setting.id == "ntfset_123"
      assert setting.active == false
      assert setting.include_sensitive_fields == true
    end

    test "handles not found", %{bypass: bypass, config: config} do
      Bypass.expect(bypass, "GET", "/notification-settings/invalid", fn conn ->
        Plug.Conn.resp(conn, 404, Jason.encode!(%{"error" => "Not Found"}))
      end)

      assert {:error, %Error{}} = NotificationSetting.get("invalid", %{}, config: config)
    end
  end

  describe "create/2" do
    test "creates notification setting successfully", %{bypass: bypass, config: config} do
      create_params = %{
        description: "New Webhook Endpoint",
        destination: "https://api.example.com/webhooks",
        subscribed_events: [
          %{name: "transaction.completed"},
          %{name: "subscription.activated"}
        ],
        active: true
      }

      created_response = %{
        "id" => "ntfset_456",
        "description" => "New Webhook Endpoint",
        "destination" => "https://api.example.com/webhooks",
        "active" => true,
        "include_sensitive_fields" => false,
        "subscribed_events" => [
          %{"name" => "transaction.completed"},
          %{"name" => "subscription.activated"}
        ],
        "api_version" => 1,
        "created_at" => "2024-01-15T12:00:00Z",
        "updated_at" => "2024-01-15T12:00:00Z"
      }

      Bypass.expect(bypass, "POST", "/notification-settings", fn conn ->
        {:ok, body, _} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)

        assert params["description"] == "New Webhook Endpoint"
        assert params["destination"] == "https://api.example.com/webhooks"
        assert params["active"] == true
        assert length(params["subscribed_events"]) == 2

        Plug.Conn.resp(
          conn,
          200,
          Jason.encode!(%{"data" => created_response})
        )
      end)

      assert {:ok, setting} = NotificationSetting.create(create_params, config: config)
      assert setting.id == "ntfset_456"
      assert setting.active == true
      assert length(setting.subscribed_events) == 2
    end

    test "handles validation errors", %{bypass: bypass, config: config} do
      Bypass.expect(bypass, "POST", "/notification-settings", fn conn ->
        Plug.Conn.resp(conn, 400, Jason.encode!(%{"error" => "Validation failed"}))
      end)

      params = %{
        description: "Invalid Webhook",
        destination: "invalid-url",
        subscribed_events: []
      }

      assert {:error, %Error{}} = NotificationSetting.create(params, config: config)
    end
  end

  describe "update/3" do
    test "updates notification setting successfully", %{bypass: bypass, config: config} do
      update_params = %{
        description: "Updated Webhook Description",
        active: false
      }

      updated_response = %{
        "id" => "ntfset_123",
        "description" => "Updated Webhook Description",
        "destination" => "https://api.myapp.com/webhooks",
        "active" => false,
        "include_sensitive_fields" => false,
        "subscribed_events" => [
          %{"name" => "transaction.completed"}
        ],
        "api_version" => 1,
        "created_at" => "2024-01-15T10:30:00Z",
        "updated_at" => "2024-01-15T13:00:00Z"
      }

      Bypass.expect(bypass, "PATCH", "/notification-settings/ntfset_123", fn conn ->
        {:ok, body, _} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)

        assert params["description"] == "Updated Webhook Description"
        assert params["active"] == false

        Plug.Conn.resp(
          conn,
          200,
          Jason.encode!(%{"data" => updated_response})
        )
      end)

      assert {:ok, setting} =
               NotificationSetting.update("ntfset_123", update_params, config: config)

      assert setting.description == "Updated Webhook Description"
      assert setting.active == false
    end

    test "handles update errors", %{bypass: bypass, config: config} do
      Bypass.expect(bypass, "PATCH", "/notification-settings/ntfset_123", fn conn ->
        Plug.Conn.resp(conn, 500, Jason.encode!(%{"error" => "Internal Server Error"}))
      end)

      assert {:error, %Error{}} = NotificationSetting.update("ntfset_123", %{}, config: config)
    end
  end

  describe "delete/2" do
    test "deletes notification setting successfully", %{bypass: bypass, config: config} do
      Bypass.expect(bypass, "DELETE", "/notification-settings/ntfset_123", fn conn ->
        Plug.Conn.resp(conn, 204, "")
      end)

      assert {:ok, nil} = NotificationSetting.delete("ntfset_123", config: config)
    end

    test "handles delete errors", %{bypass: bypass, config: config} do
      Bypass.expect(bypass, "DELETE", "/notification-settings/invalid", fn conn ->
        Plug.Conn.resp(conn, 404, Jason.encode!(%{"error" => "Not Found"}))
      end)

      assert {:error, %Error{}} = NotificationSetting.delete("invalid", config: config)
    end
  end

  describe "list_active/1" do
    test "filters active notification settings", %{bypass: bypass, config: config} do
      Bypass.expect(bypass, "GET", "/notification-settings", fn conn ->
        assert conn.query_string =~ "active=true"

        Plug.Conn.resp(conn, 200, Jason.encode!(%{"data" => []}))
      end)

      assert {:ok, []} = NotificationSetting.list_active(config: config)
    end
  end

  describe "list_inactive/1" do
    test "filters inactive notification settings", %{bypass: bypass, config: config} do
      Bypass.expect(bypass, "GET", "/notification-settings", fn conn ->
        assert conn.query_string =~ "active=false"

        Plug.Conn.resp(conn, 200, Jason.encode!(%{"data" => []}))
      end)

      assert {:ok, []} = NotificationSetting.list_inactive(config: config)
    end
  end

  describe "activate/2" do
    test "activates notification setting", %{bypass: bypass, config: config} do
      activated_response = %{
        "id" => "ntfset_123",
        "description" => "Activated Webhook",
        "destination" => "https://api.myapp.com/webhooks",
        "active" => true,
        "include_sensitive_fields" => false,
        "subscribed_events" => [],
        "api_version" => 1,
        "created_at" => "2024-01-15T10:30:00Z",
        "updated_at" => "2024-01-15T13:30:00Z"
      }

      Bypass.expect(bypass, "PATCH", "/notification-settings/ntfset_123", fn conn ->
        {:ok, body, _} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)
        assert params["active"] == true

        Plug.Conn.resp(
          conn,
          200,
          Jason.encode!(%{"data" => activated_response})
        )
      end)

      assert {:ok, setting} = NotificationSetting.activate("ntfset_123", config: config)
      assert setting.active == true
    end
  end

  describe "deactivate/2" do
    test "deactivates notification setting", %{bypass: bypass, config: config} do
      deactivated_response = %{
        "id" => "ntfset_123",
        "description" => "Deactivated Webhook",
        "destination" => "https://api.myapp.com/webhooks",
        "active" => false,
        "include_sensitive_fields" => false,
        "subscribed_events" => [],
        "api_version" => 1,
        "created_at" => "2024-01-15T10:30:00Z",
        "updated_at" => "2024-01-15T13:45:00Z"
      }

      Bypass.expect(bypass, "PATCH", "/notification-settings/ntfset_123", fn conn ->
        {:ok, body, _} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)
        assert params["active"] == false

        Plug.Conn.resp(
          conn,
          200,
          Jason.encode!(%{"data" => deactivated_response})
        )
      end)

      assert {:ok, setting} = NotificationSetting.deactivate("ntfset_123", config: config)
      assert setting.active == false
    end
  end

  describe "helper functions" do
    test "active?/1" do
      active = %NotificationSetting{active: true}
      inactive = %NotificationSetting{active: false}

      assert NotificationSetting.active?(active) == true
      assert NotificationSetting.active?(inactive) == false
    end

    test "includes_sensitive_fields?/1" do
      with_sensitive = %NotificationSetting{include_sensitive_fields: true}
      without_sensitive = %NotificationSetting{include_sensitive_fields: false}

      assert NotificationSetting.includes_sensitive_fields?(with_sensitive) == true
      assert NotificationSetting.includes_sensitive_fields?(without_sensitive) == false
    end

    test "subscribed_event_names/1" do
      setting = %NotificationSetting{
        subscribed_events: [
          %{"name" => "transaction.completed"},
          %{"name" => "subscription.activated"}
        ]
      }

      event_names = NotificationSetting.subscribed_event_names(setting)
      assert "transaction.completed" in event_names
      assert "subscription.activated" in event_names
      assert length(event_names) == 2
    end

    test "subscribed_to?/2" do
      setting = %NotificationSetting{
        subscribed_events: [
          %{"name" => "transaction.completed"}
        ]
      }

      assert NotificationSetting.subscribed_to?(setting, "transaction.completed") == true
      assert NotificationSetting.subscribed_to?(setting, "customer.created") == false
    end
  end
end
