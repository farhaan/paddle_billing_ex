defmodule PaddleBilling.ConfigTest do
  use ExUnit.Case, async: true

  alias PaddleBilling.Config

  describe "resolve/0" do
    test "resolves configuration from application env" do
      config = Config.resolve()

      assert config.api_key == "pdl_test_123456789"
      assert config.environment == :sandbox
      assert config.base_url == "https://sandbox-api.paddle.com"
      assert config.timeout == 30_000
      assert config.retry == true
    end

    test "detects environment from API key" do
      Application.put_env(:paddle_billing, :api_key, "pdl_live_123456789")
      Application.put_env(:paddle_billing, :environment, nil)

      config = Config.resolve()
      assert config.environment == :live
      assert config.base_url == "https://api.paddle.com"

      # Reset
      Application.put_env(:paddle_billing, :api_key, "pdl_test_123456789")
      Application.put_env(:paddle_billing, :environment, :sandbox)
    end

    test "defaults to sandbox for safety" do
      Application.put_env(:paddle_billing, :api_key, "pdl_unknown_123456789")
      Application.put_env(:paddle_billing, :environment, nil)

      config = Config.resolve()
      assert config.environment == :sandbox

      # Reset
      Application.put_env(:paddle_billing, :api_key, "pdl_test_123456789")
      Application.put_env(:paddle_billing, :environment, :sandbox)
    end
  end

  describe "validate!/1" do
    test "validates correct configuration" do
      config = %{
        api_key: "pdl_live_123456789",
        environment: :live,
        base_url: "https://api.paddle.com",
        timeout: 30_000,
        retry: true
      }

      assert :ok = Config.validate!(config)
    end

    test "raises on invalid API key format" do
      config = %{
        api_key: "invalid_key",
        environment: :live,
        base_url: "https://api.paddle.com",
        timeout: 30_000,
        retry: true
      }

      assert_raise ArgumentError, ~r/Invalid API key format/, fn ->
        Config.validate!(config)
      end
    end

    test "raises on invalid environment" do
      config = %{
        api_key: "pdl_live_123456789",
        environment: :invalid,
        base_url: "https://api.paddle.com",
        timeout: 30_000,
        retry: true
      }

      assert_raise ArgumentError, ~r/Invalid environment/, fn ->
        Config.validate!(config)
      end
    end
  end
end
