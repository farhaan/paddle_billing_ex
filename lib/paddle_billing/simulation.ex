defmodule PaddleBilling.Simulation do
  @moduledoc """
  Manage simulations in Paddle Billing.

  Simulations allow you to test billing scenarios without affecting real data
  or triggering actual charges. You can create simulations to test subscription
  lifecycle events, payment scenarios, and webhook deliveries in a controlled
  environment. Simulations are particularly useful for testing integrations,
  validating business logic, and training purposes.
  """

  alias PaddleBilling.{Client, Error}

  @type t :: %__MODULE__{
          id: String.t(),
          status: String.t(),
          name: String.t(),
          type: String.t(),
          single_use: boolean(),
          payload: map(),
          created_at: String.t(),
          updated_at: String.t()
        }

  defstruct [
    :id,
    :status,
    :name,
    :type,
    :single_use,
    :payload,
    :created_at,
    :updated_at
  ]

  @type simulation_run :: %{
          id: String.t(),
          status: String.t(),
          created_at: String.t(),
          updated_at: String.t()
        }

  @type simulation_event :: %{
          id: String.t(),
          event_type: String.t(),
          occurred_at: String.t(),
          data: map()
        }

  @type list_params :: %{
          optional(:after) => String.t(),
          optional(:id) => [String.t()],
          optional(:status) => [String.t()],
          optional(:type) => [String.t()],
          optional(:created_at) => map(),
          optional(:updated_at) => map(),
          optional(:per_page) => pos_integer()
        }

  @type create_params :: %{
          :name => String.t(),
          :type => String.t(),
          :payload => map(),
          optional(:single_use) => boolean()
        }

  @type update_params :: %{
          optional(:name) => String.t(),
          optional(:payload) => map(),
          optional(:single_use) => boolean(),
          optional(:status) => String.t()
        }

  @type create_run_params :: %{
          optional(:name) => String.t()
        }

  @type create_event_params :: %{
          :event_type => String.t(),
          :data => map(),
          optional(:occurred_at) => String.t()
        }

  @doc """
  Lists all simulations.

  ## Parameters

  * `:after` - Return simulations after this simulation ID (pagination)
  * `:id` - Filter by specific simulation IDs
  * `:status` - Filter by status (draft, ready, running, completed, archived)
  * `:type` - Filter by simulation type
  * `:created_at` - Filter by creation date range
  * `:updated_at` - Filter by update date range
  * `:per_page` - Number of results per page (max 200)

  ## Examples

      PaddleBilling.Simulation.list()
      {:ok, [%PaddleBilling.Simulation{}, ...]}

      PaddleBilling.Simulation.list(%{
        status: ["ready", "running"],
        type: ["subscription_lifecycle"],
        per_page: 50
      })
      {:ok, [%PaddleBilling.Simulation{}, ...]}

      # Filter by date ranges
      PaddleBilling.Simulation.list(%{
        created_at: %{
          from: "2023-01-01T00:00:00Z",
          to: "2023-12-31T23:59:59Z"
        }
      })
      {:ok, [%PaddleBilling.Simulation{}, ...]}
  """
  @spec list(list_params(), keyword()) :: {:ok, [t()]} | {:error, Error.t()}
  def list(params \\ %{}, opts \\ []) do
    case Client.get("/simulations", params, opts) do
      {:ok, simulations} when is_list(simulations) ->
        {:ok, Enum.map(simulations, &from_api/1)}

      {:ok, response} ->
        {:error, Error.from_response(response)}

      error ->
        error
    end
  end

  @doc """
  Gets a simulation by ID.

  ## Examples

      PaddleBilling.Simulation.get("sim_123")
      {:ok, %PaddleBilling.Simulation{id: "sim_123", status: "ready"}}

      PaddleBilling.Simulation.get("invalid_id")
      {:error, %PaddleBilling.Error{type: :not_found_error}}
  """
  @spec get(String.t(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def get(id, opts \\ []) do
    case Client.get("/simulations/#{id}", %{}, opts) do
      {:ok, simulation} when is_map(simulation) ->
        {:ok, from_api(simulation)}

      {:ok, response} ->
        {:error, Error.from_response(response)}

      error ->
        error
    end
  end

  @doc """
  Creates a new simulation.

  ## Parameters

  * `name` - Simulation name for identification (required)
  * `type` - Type of simulation to create (required)
    - "subscription_lifecycle" - Test subscription events
    - "payment_scenarios" - Test payment processing
    - "webhook_delivery" - Test webhook notifications
    - "billing_cycles" - Test recurring billing
  * `payload` - Configuration data for the simulation (required)
  * `single_use` - Whether simulation can only be run once (optional, default: false)

  ## Examples

      # Subscription lifecycle simulation
      PaddleBilling.Simulation.create(%{
        name: "Test Subscription Cancellation",
        type: "subscription_lifecycle",
        payload: %{
          subscription_id: "sub_123",
          events: [
            %{type: "subscription.canceled", delay: "1h"},
            %{type: "subscription.payment_failed", delay: "2h"}
          ]
        },
        single_use: true
      })
      {:ok, %PaddleBilling.Simulation{}}

      # Payment scenario simulation
      PaddleBilling.Simulation.create(%{
        name: "Payment Failure Recovery",
        type: "payment_scenarios",
        payload: %{
          customer_id: "ctm_456",
          scenarios: [
            %{type: "payment_failed", amount: "2999"},
            %{type: "payment_retry", delay: "1d"},
            %{type: "payment_success", delay: "2d"}
          ]
        }
      })
      {:ok, %PaddleBilling.Simulation{}}

      # Webhook delivery simulation
      PaddleBilling.Simulation.create(%{
        name: "Webhook Integration Test",
        type: "webhook_delivery",
        payload: %{
          endpoint: "https://api.example.com/webhooks",
          events: [
            %{type: "transaction.completed", data: %{amount: "1000"}},
            %{type: "customer.created", data: %{email: "test@example.com"}}
          ]
        }
      })
      {:ok, %PaddleBilling.Simulation{}}
  """
  @spec create(create_params(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def create(params, opts \\ []) do
    case Client.post("/simulations", params, opts) do
      {:ok, simulation} when is_map(simulation) ->
        {:ok, from_api(simulation)}

      {:ok, response} ->
        {:error, Error.from_response(response)}

      error ->
        error
    end
  end

  @doc """
  Updates a simulation.

  ## Parameters

  * `name` - Simulation name (optional)
  * `payload` - Configuration data (optional)
  * `single_use` - Whether simulation can only be run once (optional)
  * `status` - Simulation status: "draft", "ready", "archived" (optional)

  ## Examples

      PaddleBilling.Simulation.update("sim_123", %{
        name: "Updated Simulation Name",
        payload: %{
          additional_config: "value"
        }
      })
      {:ok, %PaddleBilling.Simulation{}}

      # Archive simulation
      PaddleBilling.Simulation.update("sim_123", %{
        status: "archived"
      })
      {:ok, %PaddleBilling.Simulation{}}
  """
  @spec update(String.t(), update_params(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def update(id, params, opts \\ []) do
    case Client.patch("/simulations/#{id}", params, opts) do
      {:ok, simulation} when is_map(simulation) ->
        {:ok, from_api(simulation)}

      {:ok, response} ->
        {:error, Error.from_response(response)}

      error ->
        error
    end
  end

  @doc """
  Creates a simulation run.

  Starts a new execution of the simulation. Each run generates events
  and data according to the simulation's configuration.

  ## Examples

      PaddleBilling.Simulation.create_run("sim_123")
      {:ok, %{
        "id" => "simrun_456",
        "status" => "running",
        "created_at" => "2024-01-15T10:30:00Z"
      }}

      PaddleBilling.Simulation.create_run("sim_123", %{
        name: "Production Test Run"
      })
      {:ok, %{...}}
  """
  @spec create_run(String.t(), create_run_params(), keyword()) ::
          {:ok, map()} | {:error, Error.t()}
  def create_run(simulation_id, params \\ %{}, opts \\ []) do
    Client.post("/simulations/#{simulation_id}/runs", params, opts)
  end

  @doc """
  Lists simulation runs for a specific simulation.

  ## Examples

      PaddleBilling.Simulation.list_runs("sim_123")
      {:ok, [
        %{
          "id" => "simrun_456",
          "status" => "completed",
          "created_at" => "2024-01-15T10:30:00Z",
          "updated_at" => "2024-01-15T10:35:00Z"
        },
        ...
      ]}
  """
  @spec list_runs(String.t(), keyword()) :: {:ok, [map()]} | {:error, Error.t()}
  def list_runs(simulation_id, opts \\ []) do
    Client.get("/simulations/#{simulation_id}/runs", %{}, opts)
  end

  @doc """
  Gets a specific simulation run.

  ## Examples

      PaddleBilling.Simulation.get_run("sim_123", "simrun_456")
      {:ok, %{
        "id" => "simrun_456",
        "status" => "completed",
        "events_generated" => 15,
        "created_at" => "2024-01-15T10:30:00Z",
        "completed_at" => "2024-01-15T10:35:00Z"
      }}
  """
  @spec get_run(String.t(), String.t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def get_run(simulation_id, run_id, opts \\ []) do
    Client.get("/simulations/#{simulation_id}/runs/#{run_id}", %{}, opts)
  end

  @doc """
  Lists events generated by a simulation run.

  ## Examples

      PaddleBilling.Simulation.list_run_events("sim_123", "simrun_456")
      {:ok, [
        %{
          "id" => "evt_789",
          "event_type" => "subscription.canceled",
          "occurred_at" => "2024-01-15T10:30:00Z",
          "data" => %{"subscription_id" => "sub_123"}
        },
        ...
      ]}
  """
  @spec list_run_events(String.t(), String.t(), keyword()) :: {:ok, [map()]} | {:error, Error.t()}
  def list_run_events(simulation_id, run_id, opts \\ []) do
    Client.get("/simulations/#{simulation_id}/runs/#{run_id}/events", %{}, opts)
  end

  @doc """
  Creates a custom event in a simulation run.

  Allows you to inject additional events into a running simulation
  for more complex testing scenarios.

  ## Examples

      PaddleBilling.Simulation.create_run_event("sim_123", "simrun_456", %{
        event_type: "customer.updated",
        data: %{
          customer_id: "ctm_789",
          email: "updated@example.com"
        },
        occurred_at: "2024-01-15T11:00:00Z"
      })
      {:ok, %{
        "id" => "evt_custom_123",
        "event_type" => "customer.updated",
        "occurred_at" => "2024-01-15T11:00:00Z"
      }}
  """
  @spec create_run_event(String.t(), String.t(), create_event_params(), keyword()) ::
          {:ok, map()} | {:error, Error.t()}
  def create_run_event(simulation_id, run_id, params, opts \\ []) do
    Client.post("/simulations/#{simulation_id}/runs/#{run_id}/events", params, opts)
  end

  @doc """
  Lists available simulation types.

  Returns information about all simulation types that can be created,
  including their descriptions and configuration options.

  ## Examples

      PaddleBilling.Simulation.list_types()
      {:ok, [
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
        },
        ...
      ]}
  """
  @spec list_types(keyword()) :: {:ok, [map()]} | {:error, Error.t()}
  def list_types(opts \\ []) do
    Client.get("/simulation-types", %{}, opts)
  end

  @doc """
  Gets ready simulations only.

  Convenience function to filter simulations that are ready to run.

  ## Examples

      PaddleBilling.Simulation.list_ready()
      {:ok, [%PaddleBilling.Simulation{status: "ready"}, ...]}

      PaddleBilling.Simulation.list_ready(["subscription_lifecycle"])
      {:ok, [%PaddleBilling.Simulation{}, ...]}
  """
  @spec list_ready([String.t()], keyword()) :: {:ok, [t()]} | {:error, Error.t()}
  def list_ready(types \\ [], opts \\ []) do
    filters = %{status: ["ready"]}
    filters = if types != [], do: Map.put(filters, :type, types), else: filters
    list(filters, opts)
  end

  @doc """
  Gets running simulations only.

  Convenience function to filter currently executing simulations.

  ## Examples

      PaddleBilling.Simulation.list_running()
      {:ok, [%PaddleBilling.Simulation{status: "running"}, ...]}
  """
  @spec list_running(keyword()) :: {:ok, [t()]} | {:error, Error.t()}
  def list_running(opts \\ []) do
    list(%{status: ["running"]}, opts)
  end

  @doc """
  Gets completed simulations only.

  Convenience function to filter finished simulations.

  ## Examples

      PaddleBilling.Simulation.list_completed()
      {:ok, [%PaddleBilling.Simulation{status: "completed"}, ...]}
  """
  @spec list_completed(keyword()) :: {:ok, [t()]} | {:error, Error.t()}
  def list_completed(opts \\ []) do
    list(%{status: ["completed"]}, opts)
  end

  @doc """
  Archives a simulation.

  Convenience function to archive simulations that are no longer needed.

  ## Examples

      PaddleBilling.Simulation.archive("sim_123")
      {:ok, %PaddleBilling.Simulation{status: "archived"}}
  """
  @spec archive(String.t(), keyword()) :: {:ok, t()} | {:error, Error.t()}
  def archive(id, opts \\ []) do
    update(id, %{status: "archived"}, opts)
  end

  @doc """
  Creates a subscription lifecycle simulation.

  Convenience function for creating subscription testing simulations.

  ## Examples

      PaddleBilling.Simulation.create_subscription_test("sub_123", [
        %{type: "subscription.canceled", delay: "1h"},
        %{type: "subscription.reactivated", delay: "2h"}
      ])
      {:ok, %PaddleBilling.Simulation{}}
  """
  @spec create_subscription_test(String.t(), [map()], keyword()) ::
          {:ok, t()} | {:error, Error.t()}
  def create_subscription_test(subscription_id, events, opts \\ []) do
    create(
      %{
        name: "Subscription Test - #{subscription_id}",
        type: "subscription_lifecycle",
        payload: %{
          subscription_id: subscription_id,
          events: events
        }
      },
      opts
    )
  end

  @doc """
  Creates a payment scenario simulation.

  Convenience function for creating payment testing simulations.

  ## Examples

      PaddleBilling.Simulation.create_payment_test("ctm_123", [
        %{type: "payment_failed", amount: "2999"},
        %{type: "payment_retry", delay: "1d"}
      ])
      {:ok, %PaddleBilling.Simulation{}}
  """
  @spec create_payment_test(String.t(), [map()], keyword()) :: {:ok, t()} | {:error, Error.t()}
  def create_payment_test(customer_id, scenarios, opts \\ []) do
    create(
      %{
        name: "Payment Test - #{customer_id}",
        type: "payment_scenarios",
        payload: %{
          customer_id: customer_id,
          scenarios: scenarios
        }
      },
      opts
    )
  end

  @doc """
  Checks if a simulation is ready to run.

  ## Examples

      PaddleBilling.Simulation.ready?(%PaddleBilling.Simulation{status: "ready"})
      true

      PaddleBilling.Simulation.ready?(%PaddleBilling.Simulation{status: "draft"})
      false
  """
  @spec ready?(t()) :: boolean()
  def ready?(%__MODULE__{status: "ready"}), do: true
  def ready?(%__MODULE__{}), do: false

  @doc """
  Checks if a simulation is currently running.

  ## Examples

      PaddleBilling.Simulation.running?(%PaddleBilling.Simulation{status: "running"})
      true
  """
  @spec running?(t()) :: boolean()
  def running?(%__MODULE__{status: "running"}), do: true
  def running?(%__MODULE__{}), do: false

  @doc """
  Checks if a simulation is completed.

  ## Examples

      PaddleBilling.Simulation.completed?(%PaddleBilling.Simulation{status: "completed"})
      true
  """
  @spec completed?(t()) :: boolean()
  def completed?(%__MODULE__{status: "completed"}), do: true
  def completed?(%__MODULE__{}), do: false

  @doc """
  Checks if a simulation is archived.

  ## Examples

      PaddleBilling.Simulation.archived?(%PaddleBilling.Simulation{status: "archived"})
      true
  """
  @spec archived?(t()) :: boolean()
  def archived?(%__MODULE__{status: "archived"}), do: true
  def archived?(%__MODULE__{}), do: false

  @doc """
  Checks if a simulation is single-use only.

  ## Examples

      PaddleBilling.Simulation.single_use?(%PaddleBilling.Simulation{single_use: true})
      true
  """
  @spec single_use?(t()) :: boolean()
  def single_use?(%__MODULE__{single_use: true}), do: true
  def single_use?(%__MODULE__{}), do: false

  # Private functions

  @spec from_api(map()) :: t()
  defp from_api(data) when is_map(data) do
    %__MODULE__{
      id: Map.get(data, "id"),
      status: Map.get(data, "status"),
      name: Map.get(data, "name"),
      type: Map.get(data, "type"),
      single_use: Map.get(data, "single_use", false),
      payload: Map.get(data, "payload", %{}),
      created_at: Map.get(data, "created_at"),
      updated_at: Map.get(data, "updated_at")
    }
  end
end
