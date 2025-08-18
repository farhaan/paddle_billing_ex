# PaddleBilling

An Elixir client for the Paddle Billing API.

## Configuration

Set your API key:

```bash
export PADDLE_API_KEY="pdl_live_your_api_key_here"
```

Or configure it in your app:

```elixir
config :paddle_billing,
  api_key: "pdl_live_your_api_key_here"
```

The library automatically detects if you're using live or sandbox keys.

## Usage

### Products

```elixir
# List products
{:ok, products} = PaddleBilling.Product.list()

# Create a product
{:ok, product} = PaddleBilling.Product.create(%{
  name: "Pro Plan",
  description: "Our premium offering"
})

# Get a product
{:ok, product} = PaddleBilling.Product.get("pro_123")

# Update it
{:ok, product} = PaddleBilling.Product.update("pro_123", %{
  description: "Updated description"
})
```

### Prices

```elixir
# Monthly recurring price
{:ok, price} = PaddleBilling.Price.create(%{
  product_id: "pro_123",
  name: "Monthly",
  type: "recurring",
  billing_cycle: %{
    interval: "month",
    frequency: 1
  },
  unit_price: %{
    amount: "29.99",
    currency_code: "USD"
  }
})

# One-time price
{:ok, price} = PaddleBilling.Price.create(%{
  product_id: "pro_123", 
  name: "Lifetime",
  type: "standard",
  unit_price: %{
    amount: "299.99",
    currency_code: "USD"
  }
})
```

### Customers

```elixir
# Create a customer
{:ok, customer} = PaddleBilling.Customer.create(%{
  email: "user@example.com"
})

# Find customers by email
{:ok, customers} = PaddleBilling.Customer.list(%{
  email: "user@example.com"
})
```

### Subscriptions

```elixir
# Create a subscription
{:ok, sub} = PaddleBilling.Subscription.create(%{
  customer_id: "ctm_123",
  items: [%{
    price_id: "pri_123",
    quantity: 1
  }]
})

# Cancel it
{:ok, sub} = PaddleBilling.Subscription.cancel(sub.id, %{
  effective_from: "end_of_billing_period"
})
```

### Transactions

```elixir
# List recent transactions
{:ok, transactions} = PaddleBilling.Transaction.list(%{
  status: "completed"
})

# Get transaction details
{:ok, transaction} = PaddleBilling.Transaction.get("txn_123")
```

## Error Handling

Functions return `{:ok, result}` or `{:error, error}`:

```elixir
case PaddleBilling.Product.get("invalid_id") do
  {:ok, product} -> 
    # Handle success
  {:error, error} -> 
    IO.puts("Error: #{error.message}")
end
```

Error types include:
- `:not_found_error` - Resource not found
- `:validation_error` - Invalid parameters  
- `:authentication_error` - Bad API key
- `:rate_limit_error` - Too many requests

## Pagination

Most list functions support pagination:

```elixir
# First page
{:ok, products} = PaddleBilling.Product.list(%{per_page: 50})

# Next page  
{:ok, more_products} = PaddleBilling.Product.list(%{
  per_page: 50,
  after: "pro_last_id_from_previous_page"
})
```

## Filtering

You can filter most list endpoints:

```elixir
# Products by status
{:ok, products} = PaddleBilling.Product.list(%{status: "active"})

# Transactions by date range
{:ok, transactions} = PaddleBilling.Transaction.list(%{
  billed_at: %{
    from: "2024-01-01T00:00:00Z",
    to: "2024-12-31T23:59:59Z"  
  }
})

# Customers by country
{:ok, customers} = PaddleBilling.Customer.list(%{
  "address[country_code]" => "US"
})
```

## Webhooks

Set up webhook endpoints:

```elixir
{:ok, webhook} = PaddleBilling.NotificationSetting.create(%{
  description: "My webhook",
  destination: "https://myapp.com/webhooks/paddle",
  subscribed_events: [
    %{name: "subscription.created"},
    %{name: "transaction.completed"}
  ]
})
```

## Custom Configuration

Override config per request:

```elixir
sandbox_config = %{
  api_key: "pdl_sdbx_different_key",
  environment: :sandbox
}

{:ok, products} = PaddleBilling.Product.list(%{}, config: sandbox_config)
```

## Available Resources

This library covers the full Paddle API:

- **Products** - Create and manage your products
- **Prices** - Set up pricing for products  
- **Customers** - Customer management
- **Subscriptions** - Recurring billing
- **Transactions** - Payment history and invoicing
- **Adjustments** - Credits and charges
- **Discounts** - Coupons and promotions
- **Reports** - Revenue and analytics data
- **Notifications** - Webhook management
- **Events** - Activity logs
- **Simulations** - Test scenarios

## Testing

### Unit Tests

Run the unit test suite:

```bash
mix test
```

For test coverage:

```bash
mix test --cover
```

The library includes test helpers for mocking Paddle API calls in your tests.

### Integration Testing

The library includes comprehensive tests against the real Paddle API to ensure reliability:

```bash
# Run integration tests with your sandbox key
export PADDLE_SANDBOX_API_KEY="your_sandbox_key"
mix test test/paddle_billing/e2e_test.exs --include e2e
```

For detailed testing documentation, see [TESTING.md](TESTING.md).

## Development

```bash
# Get dependencies
mix deps.get

# Run tests
mix test

# Check types
mix dialyzer

# Lint code  
mix credo
```

## License

MIT