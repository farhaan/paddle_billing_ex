defmodule PaddleBilling do
  @moduledoc """
  A modern Elixir client for the Paddle Billing API.

  This library provides a complete interface to Paddle's Billing API,
  supporting products, prices, customers, subscriptions, transactions,
  and webhooks with proper error handling and modern Elixir patterns.

  ## Configuration

  Configure your API key and environment:

      # Application config
      config :paddle_billing,
        api_key: "pdl_live_...",
        environment: :live

      # Or use environment variables
      export PADDLE_API_KEY="pdl_live_..."
      export PADDLE_ENVIRONMENT="live"

  ## Quick Start

      # List products
      {:ok, products} = PaddleBilling.Product.list()

      # Create a product
      {:ok, product} = PaddleBilling.Product.create(%{
        name: "My Product",
        description: "A great product"
      })

      # List customers
      {:ok, customers} = PaddleBilling.Customer.list()

  ## Error Handling

  All functions return `{:ok, result}` or `{:error, %PaddleBilling.Error{}}`:

      case PaddleBilling.Product.get("pro_123") do
        {:ok, product_data} ->
          IO.puts("Product: \#{product_data.name}")
        {:error, %PaddleBilling.Error{message: message}} ->
          IO.puts("Error: \#{message}")
      end

  ## Resources

  * `PaddleBilling.Product` - Manage products
  * `PaddleBilling.Price` - Manage pricing
  * `PaddleBilling.Customer` - Manage customers
  * `PaddleBilling.Address` - Manage customer addresses
  * `PaddleBilling.Business` - Manage business entities
  * `PaddleBilling.Subscription` - Manage subscriptions
  * `PaddleBilling.Transaction` - View transactions
  * `PaddleBilling.Discount` - Manage discounts and promotional codes
  * `PaddleBilling.Event` - Handle events and notifications
  * `PaddleBilling.Webhook` - Webhook utilities

  ## Links

  * [Paddle API Documentation](https://developer.paddle.com/api-reference/overview)
  * [GitHub Repository](https://github.com/farhaan/paddle_billing_ex)
  """

  alias PaddleBilling.{Client, Config, Error}

  @doc """
  Makes a direct API request. Useful for endpoints not yet supported by specific resources.

  ## Examples

      PaddleBilling.request(:get, "/event-types")
      {:ok, %{"data" => [...]}}

      PaddleBilling.request(:post, "/products", %{name: "My Product"})
      {:ok, %{"data" => %{"id" => "pro_123", ...}}}
  """
  @spec request(Client.method(), String.t(), map() | nil, map(), keyword()) ::
          {:ok, map() | list() | nil} | {:error, Error.t()}
  def request(method, path, body \\ nil, params \\ %{}, opts \\ []) do
    Client.request(method, path, body, params, opts)
  end

  @doc """
  Tests the API connection with your credentials.

  ## Examples

      PaddleBilling.ping()
      {:ok, %{"event_types" => [...]}}

      # With invalid credentials
      PaddleBilling.ping()
      {:error, %PaddleBilling.Error{type: :authentication_error}}
  """
  @spec ping() :: {:ok, map()} | {:error, Error.t()}
  def ping do
    Client.get("/event-types")
  end

  @doc """
  Returns the current configuration.

  ## Examples

      PaddleBilling.config()
      %{
        api_key: "pdl_live_...",
        environment: :live,
        base_url: "https://api.paddle.com",
        timeout: 30000,
        retry: true
      }
  """
  @spec config() :: Config.config()
  def config do
    Config.resolve()
  end
end
