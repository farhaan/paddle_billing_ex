defmodule PaddleBilling.SimulationTest do
  use ExUnit.Case, async: true
  alias PaddleBilling.{Simulation, Error}

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
    test "returns list of simulations", %{bypass: bypass, config: config} do
      simulations_response = [
        %{
          "id" => "sim_123",
          "status" => "ready",
          "name" => "Test Subscription Lifecycle",
          "type" => "subscription_lifecycle",
          "single_use" => true,
          "payload" => %{
            "subscription_id" => "sub_456",
            "events" => [%{"type" => "subscription.canceled", "delay" => "1h"}]
          },
          "created_at" => "2024-01-15T10:30:00Z",
          "updated_at" => "2024-01-15T10:30:00Z"
        }
      ]

      Bypass.expect(bypass, "GET", "/simulations", fn conn ->
        Plug.Conn.resp(
          conn,
          200,
          Jason.encode!(%{"data" => simulations_response})
        )
      end)

      assert {:ok, [simulation]} = Simulation.list(%{}, config: config)
      assert simulation.id == "sim_123"
      assert simulation.status == "ready"
      assert simulation.name == "Test Subscription Lifecycle"
      assert simulation.type == "subscription_lifecycle"
      assert simulation.single_use == true
    end

    test "accepts query parameters", %{bypass: bypass, config: config} do
      Bypass.expect(bypass, "GET", "/simulations", fn conn ->
        assert conn.query_string =~ "status=ready,running"
        assert conn.query_string =~ "type=subscription_lifecycle"
        assert conn.query_string =~ "per_page=50"

        Plug.Conn.resp(conn, 200, Jason.encode!(%{"data" => []}))
      end)

      params = %{
        status: ["ready", "running"],
        type: ["subscription_lifecycle"],
        per_page: 50
      }

      assert {:ok, []} = Simulation.list(params, config: config)
    end

    test "handles API errors", %{bypass: bypass, config: config} do
      Bypass.expect(bypass, "GET", "/simulations", fn conn ->
        Plug.Conn.resp(conn, 500, Jason.encode!(%{"error" => "Internal Server Error"}))
      end)

      assert {:error, %Error{}} = Simulation.list(%{}, config: config)
    end
  end

  describe "get/2" do
    test "returns simulation by ID", %{bypass: bypass, config: config} do
      simulation_response = %{
        "id" => "sim_123",
        "status" => "completed",
        "name" => "Payment Failure Test",
        "type" => "payment_scenarios",
        "single_use" => false,
        "payload" => %{
          "customer_id" => "ctm_789",
          "scenarios" => [%{"type" => "payment_failed", "amount" => "2999"}]
        },
        "created_at" => "2024-01-15T10:30:00Z",
        "updated_at" => "2024-01-15T11:00:00Z"
      }

      Bypass.expect(bypass, "GET", "/simulations/sim_123", fn conn ->
        Plug.Conn.resp(
          conn,
          200,
          Jason.encode!(%{"data" => simulation_response})
        )
      end)

      assert {:ok, simulation} = Simulation.get("sim_123", config: config)
      assert simulation.id == "sim_123"
      assert simulation.status == "completed"
      assert simulation.type == "payment_scenarios"
      assert simulation.single_use == false
    end

    test "handles not found", %{bypass: bypass, config: config} do
      Bypass.expect(bypass, "GET", "/simulations/invalid", fn conn ->
        Plug.Conn.resp(conn, 404, Jason.encode!(%{"error" => "Not Found"}))
      end)

      assert {:error, %Error{}} = Simulation.get("invalid", config: config)
    end
  end

  describe "create/2" do
    test "creates simulation successfully", %{bypass: bypass, config: config} do
      create_params = %{
        name: "New Subscription Test",
        type: "subscription_lifecycle",
        payload: %{
          subscription_id: "sub_123",
          events: [
            %{type: "subscription.canceled", delay: "1h"},
            %{type: "subscription.reactivated", delay: "2h"}
          ]
        },
        single_use: true
      }

      created_response = %{
        "id" => "sim_456",
        "status" => "draft",
        "name" => "New Subscription Test",
        "type" => "subscription_lifecycle",
        "single_use" => true,
        "payload" => %{
          "subscription_id" => "sub_123",
          "events" => [
            %{"type" => "subscription.canceled", "delay" => "1h"},
            %{"type" => "subscription.reactivated", "delay" => "2h"}
          ]
        },
        "created_at" => "2024-01-15T12:00:00Z",
        "updated_at" => "2024-01-15T12:00:00Z"
      }

      Bypass.expect(bypass, "POST", "/simulations", fn conn ->
        {:ok, body, _} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)

        assert params["name"] == "New Subscription Test"
        assert params["type"] == "subscription_lifecycle"
        assert params["single_use"] == true
        assert length(params["payload"]["events"]) == 2

        Plug.Conn.resp(
          conn,
          200,
          Jason.encode!(%{"data" => created_response})
        )
      end)

      assert {:ok, simulation} = Simulation.create(create_params, config: config)
      assert simulation.id == "sim_456"
      assert simulation.name == "New Subscription Test"
      assert simulation.single_use == true
    end

    test "handles validation errors", %{bypass: bypass, config: config} do
      Bypass.expect(bypass, "POST", "/simulations", fn conn ->
        Plug.Conn.resp(conn, 400, Jason.encode!(%{"error" => "Validation failed"}))
      end)

      params = %{
        name: "",
        type: "invalid_type",
        payload: %{}
      }

      assert {:error, %Error{}} = Simulation.create(params, config: config)
    end
  end

  describe "update/3" do
    test "updates simulation successfully", %{bypass: bypass, config: config} do
      update_params = %{
        name: "Updated Simulation Name",
        status: "ready"
      }

      updated_response = %{
        "id" => "sim_123",
        "status" => "ready",
        "name" => "Updated Simulation Name",
        "type" => "subscription_lifecycle",
        "single_use" => false,
        "payload" => %{},
        "created_at" => "2024-01-15T10:30:00Z",
        "updated_at" => "2024-01-15T13:00:00Z"
      }

      Bypass.expect(bypass, "PATCH", "/simulations/sim_123", fn conn ->
        {:ok, body, _} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)

        assert params["name"] == "Updated Simulation Name"
        assert params["status"] == "ready"

        Plug.Conn.resp(
          conn,
          200,
          Jason.encode!(%{"data" => updated_response})
        )
      end)

      assert {:ok, simulation} = Simulation.update("sim_123", update_params, config: config)
      assert simulation.name == "Updated Simulation Name"
      assert simulation.status == "ready"
    end

    test "handles update errors", %{bypass: bypass, config: config} do
      Bypass.expect(bypass, "PATCH", "/simulations/sim_123", fn conn ->
        Plug.Conn.resp(conn, 500, Jason.encode!(%{"error" => "Internal Server Error"}))
      end)

      assert {:error, %Error{}} = Simulation.update("sim_123", %{}, config: config)
    end
  end

  describe "simulation runs" do
    test "create_run/3 creates simulation run", %{bypass: bypass, config: config} do
      run_response = %{
        "id" => "simrun_456",
        "status" => "running",
        "created_at" => "2024-01-15T14:00:00Z"
      }

      Bypass.expect(bypass, "POST", "/simulations/sim_123/runs", fn conn ->
        {:ok, body, _} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)

        assert params["name"] == "Test Run"

        Plug.Conn.resp(
          conn,
          200,
          Jason.encode!(%{"data" => run_response})
        )
      end)

      assert {:ok, run} = Simulation.create_run("sim_123", %{name: "Test Run"}, config: config)
      assert run["id"] == "simrun_456"
      assert run["status"] == "running"
    end

    test "list_runs/2 lists simulation runs", %{bypass: bypass, config: config} do
      runs_response = [
        %{
          "id" => "simrun_456",
          "status" => "completed",
          "created_at" => "2024-01-15T14:00:00Z",
          "updated_at" => "2024-01-15T14:05:00Z"
        }
      ]

      Bypass.expect(bypass, "GET", "/simulations/sim_123/runs", fn conn ->
        Plug.Conn.resp(
          conn,
          200,
          Jason.encode!(%{"data" => runs_response})
        )
      end)

      assert {:ok, runs} = Simulation.list_runs("sim_123", config: config)
      assert length(runs) == 1
      assert List.first(runs)["id"] == "simrun_456"
    end

    test "get_run/3 gets specific simulation run", %{bypass: bypass, config: config} do
      run_response = %{
        "id" => "simrun_456",
        "status" => "completed",
        "events_generated" => 15,
        "created_at" => "2024-01-15T14:00:00Z",
        "completed_at" => "2024-01-15T14:05:00Z"
      }

      Bypass.expect(bypass, "GET", "/simulations/sim_123/runs/simrun_456", fn conn ->
        Plug.Conn.resp(
          conn,
          200,
          Jason.encode!(%{"data" => run_response})
        )
      end)

      assert {:ok, run} = Simulation.get_run("sim_123", "simrun_456", config: config)
      assert run["id"] == "simrun_456"
      assert run["events_generated"] == 15
    end
  end

  describe "simulation events" do
    test "list_run_events/3 lists events from simulation run", %{bypass: bypass, config: config} do
      events_response = [
        %{
          "id" => "evt_789",
          "event_type" => "subscription.canceled",
          "occurred_at" => "2024-01-15T14:01:00Z",
          "data" => %{"subscription_id" => "sub_123"}
        }
      ]

      Bypass.expect(bypass, "GET", "/simulations/sim_123/runs/simrun_456/events", fn conn ->
        Plug.Conn.resp(
          conn,
          200,
          Jason.encode!(%{"data" => events_response})
        )
      end)

      assert {:ok, events} = Simulation.list_run_events("sim_123", "simrun_456", config: config)
      assert length(events) == 1
      assert List.first(events)["event_type"] == "subscription.canceled"
    end

    test "create_run_event/4 creates custom event", %{bypass: bypass, config: config} do
      event_params = %{
        event_type: "customer.updated",
        data: %{
          customer_id: "ctm_789",
          email: "updated@example.com"
        },
        occurred_at: "2024-01-15T14:30:00Z"
      }

      event_response = %{
        "id" => "evt_custom_123",
        "event_type" => "customer.updated",
        "occurred_at" => "2024-01-15T14:30:00Z"
      }

      Bypass.expect(bypass, "POST", "/simulations/sim_123/runs/simrun_456/events", fn conn ->
        {:ok, body, _} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)

        assert params["event_type"] == "customer.updated"
        assert params["data"]["customer_id"] == "ctm_789"

        Plug.Conn.resp(
          conn,
          200,
          Jason.encode!(%{"data" => event_response})
        )
      end)

      assert {:ok, event} =
               Simulation.create_run_event("sim_123", "simrun_456", event_params, config: config)

      assert event["id"] == "evt_custom_123"
      assert event["event_type"] == "customer.updated"
    end
  end

  describe "list_types/1" do
    test "returns simulation types", %{bypass: bypass, config: config} do
      types_response = [
        %{
          "name" => "subscription_lifecycle",
          "description" => "Test complete subscription lifecycle events",
          "parameters" => %{
            "subscription_id" => "required",
            "events" => "array of event definitions"
          }
        },
        %{
          "name" => "payment_scenarios",
          "description" => "Test various payment processing scenarios",
          "parameters" => %{
            "customer_id" => "required",
            "scenarios" => "array of payment scenarios"
          }
        }
      ]

      Bypass.expect(bypass, "GET", "/simulation-types", fn conn ->
        Plug.Conn.resp(
          conn,
          200,
          Jason.encode!(%{"data" => types_response})
        )
      end)

      assert {:ok, types} = Simulation.list_types(config: config)
      assert length(types) == 2

      subscription_type = Enum.find(types, &(&1["name"] == "subscription_lifecycle"))
      assert subscription_type["description"] =~ "subscription lifecycle"
    end

    test "handles API errors", %{bypass: bypass, config: config} do
      Bypass.expect(bypass, "GET", "/simulation-types", fn conn ->
        Plug.Conn.resp(conn, 500, Jason.encode!(%{"error" => "Internal Server Error"}))
      end)

      assert {:error, %Error{}} = Simulation.list_types(config: config)
    end
  end

  describe "convenience functions" do
    test "list_ready/2 filters ready simulations", %{bypass: bypass, config: config} do
      Bypass.expect(bypass, "GET", "/simulations", fn conn ->
        assert conn.query_string =~ "status=ready"

        Plug.Conn.resp(conn, 200, Jason.encode!(%{"data" => []}))
      end)

      assert {:ok, []} = Simulation.list_ready([], config: config)
    end

    test "list_running/1 filters running simulations", %{bypass: bypass, config: config} do
      Bypass.expect(bypass, "GET", "/simulations", fn conn ->
        assert conn.query_string =~ "status=running"

        Plug.Conn.resp(conn, 200, Jason.encode!(%{"data" => []}))
      end)

      assert {:ok, []} = Simulation.list_running(config: config)
    end

    test "list_completed/1 filters completed simulations", %{bypass: bypass, config: config} do
      Bypass.expect(bypass, "GET", "/simulations", fn conn ->
        assert conn.query_string =~ "status=completed"

        Plug.Conn.resp(conn, 200, Jason.encode!(%{"data" => []}))
      end)

      assert {:ok, []} = Simulation.list_completed(config: config)
    end

    test "archive/2 archives simulation", %{bypass: bypass, config: config} do
      archived_response = %{
        "id" => "sim_123",
        "status" => "archived",
        "name" => "Archived Simulation",
        "type" => "subscription_lifecycle",
        "single_use" => false,
        "payload" => %{},
        "created_at" => "2024-01-15T10:30:00Z",
        "updated_at" => "2024-01-15T15:00:00Z"
      }

      Bypass.expect(bypass, "PATCH", "/simulations/sim_123", fn conn ->
        {:ok, body, _} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)
        assert params["status"] == "archived"

        Plug.Conn.resp(
          conn,
          200,
          Jason.encode!(%{"data" => archived_response})
        )
      end)

      assert {:ok, simulation} = Simulation.archive("sim_123", config: config)
      assert simulation.status == "archived"
    end

    test "create_subscription_test/3 creates subscription simulation", %{
      bypass: bypass,
      config: config
    } do
      events = [
        %{type: "subscription.canceled", delay: "1h"},
        %{type: "subscription.reactivated", delay: "2h"}
      ]

      created_response = %{
        "id" => "sim_sub_test",
        "status" => "draft",
        "name" => "Subscription Test - sub_123",
        "type" => "subscription_lifecycle",
        "single_use" => false,
        "payload" => %{
          "subscription_id" => "sub_123",
          "events" => events
        },
        "created_at" => "2024-01-15T16:00:00Z",
        "updated_at" => "2024-01-15T16:00:00Z"
      }

      Bypass.expect(bypass, "POST", "/simulations", fn conn ->
        {:ok, body, _} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)

        assert params["name"] == "Subscription Test - sub_123"
        assert params["type"] == "subscription_lifecycle"
        assert params["payload"]["subscription_id"] == "sub_123"

        Plug.Conn.resp(
          conn,
          200,
          Jason.encode!(%{"data" => created_response})
        )
      end)

      assert {:ok, simulation} =
               Simulation.create_subscription_test("sub_123", events, config: config)

      assert simulation.name == "Subscription Test - sub_123"
      assert simulation.type == "subscription_lifecycle"
    end

    test "create_payment_test/3 creates payment simulation", %{bypass: bypass, config: config} do
      scenarios = [
        %{type: "payment_failed", amount: "2999"},
        %{type: "payment_retry", delay: "1d"}
      ]

      created_response = %{
        "id" => "sim_pay_test",
        "status" => "draft",
        "name" => "Payment Test - ctm_123",
        "type" => "payment_scenarios",
        "single_use" => false,
        "payload" => %{
          "customer_id" => "ctm_123",
          "scenarios" => scenarios
        },
        "created_at" => "2024-01-15T16:00:00Z",
        "updated_at" => "2024-01-15T16:00:00Z"
      }

      Bypass.expect(bypass, "POST", "/simulations", fn conn ->
        {:ok, body, _} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)

        assert params["name"] == "Payment Test - ctm_123"
        assert params["type"] == "payment_scenarios"
        assert params["payload"]["customer_id"] == "ctm_123"

        Plug.Conn.resp(
          conn,
          200,
          Jason.encode!(%{"data" => created_response})
        )
      end)

      assert {:ok, simulation} =
               Simulation.create_payment_test("ctm_123", scenarios, config: config)

      assert simulation.name == "Payment Test - ctm_123"
      assert simulation.type == "payment_scenarios"
    end
  end

  describe "helper functions" do
    test "ready?/1" do
      ready = %Simulation{status: "ready"}
      draft = %Simulation{status: "draft"}

      assert Simulation.ready?(ready) == true
      assert Simulation.ready?(draft) == false
    end

    test "running?/1" do
      running = %Simulation{status: "running"}
      ready = %Simulation{status: "ready"}

      assert Simulation.running?(running) == true
      assert Simulation.running?(ready) == false
    end

    test "completed?/1" do
      completed = %Simulation{status: "completed"}
      running = %Simulation{status: "running"}

      assert Simulation.completed?(completed) == true
      assert Simulation.completed?(running) == false
    end

    test "archived?/1" do
      archived = %Simulation{status: "archived"}
      active = %Simulation{status: "ready"}

      assert Simulation.archived?(archived) == true
      assert Simulation.archived?(active) == false
    end

    test "single_use?/1" do
      single_use = %Simulation{single_use: true}
      reusable = %Simulation{single_use: false}

      assert Simulation.single_use?(single_use) == true
      assert Simulation.single_use?(reusable) == false
    end
  end
end
