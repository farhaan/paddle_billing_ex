defmodule PaddleBillingTest do
  use ExUnit.Case
  doctest PaddleBilling

  test "config/0 returns resolved configuration" do
    config = PaddleBilling.config()

    assert is_map(config)
    assert config.api_key == "pdl_test_123456789"
    assert config.environment == :sandbox
    assert config.base_url == "https://sandbox-api.paddle.com"
  end

  test "request/5 delegates to Client.request/5" do
    # This is more of an integration test
    # Just verify the function exists and accepts the right params
    assert function_exported?(PaddleBilling, :request, 5)
  end
end
