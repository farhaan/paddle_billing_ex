ExUnit.start()

# Set test configuration to avoid requiring real API keys during unit tests
# E2E tests will use environment variables for real API keys
test_api_key = System.get_env("PADDLE_API_KEY") || 
               System.get_env("PADDLE_SANDBOX_API_KEY") || 
               "pdl_test_123456789"

test_environment = case System.get_env("PADDLE_ENVIRONMENT") do
  "live" -> :live
  "production" -> :live
  _ -> :sandbox
end

Application.put_env(:paddle_billing, :api_key, test_api_key)
Application.put_env(:paddle_billing, :environment, test_environment)

# Configure ExUnit for better test output
ExUnit.configure(
  exclude: [:skip],
  formatters: [ExUnit.CLIFormatter],
  max_cases: System.schedulers_online() * 2,
  # 30 second timeout for individual tests
  timeout: 30_000,
  capture_log: true
)

# Add test utilities module
defmodule PaddleBilling.TestHelpers do
  @moduledoc """
  Helper functions for testing PaddleBilling functionality.
  """

  alias PaddleBilling.JSON

  import ExUnit.Assertions

  def create_test_config(override_opts \\ []) do
    base_config = %PaddleBilling.Config{
      api_key: "pdl_test_123456789",
      environment: :sandbox,
      base_url: "https://sandbox-api.paddle.com",
      timeout: 30_000,
      retry: false
    }

    Enum.reduce(override_opts, base_config, fn {key, value}, config ->
      Map.put(config, key, value)
    end)
  end

  def create_bypass_config(bypass, override_opts \\ []) do
    create_test_config(
      [
        base_url: "http://localhost:#{bypass.port}"
      ] ++ override_opts
    )
  end

  def setup_successful_response(bypass, method, path, response_data) do
    Bypass.expect_once(bypass, method, path, fn conn ->
      Plug.Conn.resp(conn, 200, JSON.encode!(%{"data" => response_data}))
    end)
  end

  def setup_error_response(bypass, method, path, status, error_data) do
    Bypass.expect_once(bypass, method, path, fn conn ->
      Plug.Conn.resp(conn, status, JSON.encode!(error_data))
    end)
  end

  def assert_valid_paddle_headers(conn) do
    headers = Enum.into(conn.req_headers, %{})

    # Check authentication header
    assert String.starts_with?(headers["authorization"], "Bearer pdl_")

    # Check API version header
    assert headers["paddle-version"] == "1"

    # Check content type
    assert headers["content-type"] == "application/json"

    # Check accept header
    assert headers["accept"] == "application/json"

    # Check user agent
    assert headers["user-agent"] == "paddle_billing_ex/0.1.0 (Elixir)"
  end

  def measure_execution_time(func) do
    start_time = System.monotonic_time(:microsecond)
    result = func.()
    end_time = System.monotonic_time(:microsecond)

    {result, end_time - start_time}
  end

  def create_large_string(size_kb) do
    base_string = "This is a test string for performance testing. "
    repetitions = div(size_kb * 1024, byte_size(base_string))
    String.duplicate(base_string, repetitions)
  end

  def create_nested_map(depth) when depth <= 0, do: %{"leaf" => "value"}

  def create_nested_map(depth) do
    %{
      "level_#{depth}" => create_nested_map(depth - 1),
      "data_#{depth}" => "value_#{depth}"
    }
  end

  def wait_for_condition(condition_fn, timeout_ms \\ 5000, check_interval_ms \\ 50) do
    end_time = System.monotonic_time(:millisecond) + timeout_ms

    wait_for_condition_loop(condition_fn, end_time, check_interval_ms)
  end

  defp wait_for_condition_loop(condition_fn, end_time, check_interval_ms) do
    if condition_fn.() do
      :ok
    else
      current_time = System.monotonic_time(:millisecond)

      if current_time >= end_time do
        {:timeout, "Condition not met within timeout"}
      else
        Process.sleep(check_interval_ms)
        wait_for_condition_loop(condition_fn, end_time, check_interval_ms)
      end
    end
  end

  def assert_memory_within_bounds(initial_memory, max_growth_mb) do
    :erlang.garbage_collect()
    Process.sleep(10)

    final_memory = :erlang.memory(:total)
    growth_bytes = final_memory - initial_memory
    growth_mb = growth_bytes / (1024 * 1024)

    if growth_mb > max_growth_mb do
      ExUnit.Assertions.flunk(
        "Memory growth exceeded limit: #{Float.round(growth_mb, 2)}MB > #{max_growth_mb}MB"
      )
    end

    :ok
  end

  def simulate_network_delay(min_ms \\ 10, max_ms \\ 100) do
    delay = :rand.uniform(max_ms - min_ms) + min_ms
    Process.sleep(delay)
  end

  def create_malicious_payload(type) do
    case type do
      :xss -> "<script>alert('xss')</script>"
      :sql_injection -> "'; DROP TABLE users; --"
      :command_injection -> "$(rm -rf /)"
      :path_traversal -> "../../../etc/passwd"
      :null_bytes -> "payload\x00withNull"
      :unicode_attack -> "﷽" <> String.duplicate("A", 1000)
      :billion_laughs -> String.duplicate("lol", 1_000_000)
      _ -> "unknown_payload_type"
    end
  end

  def generate_test_product_data(opts \\ []) do
    %{
      name: Keyword.get(opts, :name, "Test Product"),
      description: Keyword.get(opts, :description, "A test product for unit testing"),
      type: Keyword.get(opts, :type, "standard"),
      tax_category: Keyword.get(opts, :tax_category, "standard"),
      custom_data:
        Keyword.get(opts, :custom_data, %{
          "test" => true,
          "generated_at" => DateTime.utc_now() |> DateTime.to_iso8601()
        })
    }
  end

  def create_e2e_config(override_opts \\ []) do
    api_key = System.get_env("PADDLE_API_KEY") || 
              System.get_env("PADDLE_SANDBOX_API_KEY") || 
              raise """
              
              E2E tests require a Paddle API key to be set in environment variables.
              
              For sandbox testing, set:
                export PADDLE_SANDBOX_API_KEY="pdl_sdbx_your_key_here"
              
              For live testing (not recommended), set:
                export PADDLE_API_KEY="pdl_live_your_key_here"
                export PADDLE_ENVIRONMENT="live"
              
              """

    environment = case System.get_env("PADDLE_ENVIRONMENT") do
      "live" -> :live
      "production" -> :live
      _ -> :sandbox
    end

    base_url = case environment do
      :live -> "https://api.paddle.com"
      :sandbox -> "https://sandbox-api.paddle.com"
    end

    base_config = %PaddleBilling.Config{
      api_key: api_key,
      environment: environment,
      base_url: base_url,
      timeout: 30_000,
      retry: false
    }

    Enum.reduce(override_opts, base_config, fn {key, value}, config ->
      Map.put(config, key, value)
    end)
  end

  def skip_e2e_unless_configured do
    case System.get_env("PADDLE_API_KEY") || System.get_env("PADDLE_SANDBOX_API_KEY") do
      nil -> {:skip, "No Paddle API key configured for E2E tests"}
      _key -> :ok
    end
  end
end

# TestHelpers module is now available in all test files
# Use: import PaddleBilling.TestHelpers in individual test files that need it
