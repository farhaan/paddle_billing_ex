# Testing Guide

This document covers testing strategies for the PaddleBilling Elixir library, including unit tests and end-to-end integration testing.

## Unit Testing

### Running Unit Tests

```bash
# Run all unit tests
mix test

# Run with coverage report
mix test --cover

# Run specific test file
mix test test/paddle_billing/product_test.exs

# Run with verbose output
mix test --trace
```

### Test Structure

The test suite includes:

- **Module Tests** - Test individual resource modules (Product, Price, Customer, etc.)
- **Client Tests** - HTTP client functionality and error handling
- **Integration Tests** - Mock API integration scenarios
- **Security Tests** - Input validation and attack prevention
- **Performance Tests** - Memory usage and timeout handling

### Test Helpers

The library provides test helpers for mocking Paddle API calls:

```elixir
use PaddleBilling.TestHelpers

# Create mock HTTP server
bypass = Bypass.open()
config = create_bypass_config(bypass)

# Set up mock responses
setup_successful_response(bypass, "GET", "/products/pro_123", %{
  "id" => "pro_123",
  "name" => "Test Product"
})
```

## End-to-End Testing

End-to-end tests validate the library against the real Paddle API to ensure complete integration works correctly.

### Prerequisites

You need a Paddle API key to run E2E tests:

- **Sandbox**: Get from [Paddle Sandbox Dashboard](https://sandbox-vendors.paddle.com/) (recommended)
- **Live**: Get from [Paddle Live Dashboard](https://vendors.paddle.com/) (use with caution)

### Quick Start

```bash
# Set your sandbox API key
export PADDLE_SANDBOX_API_KEY="pdl_sdbx_your_key_here"

# Run all E2E tests
mix test test/paddle_billing/e2e_test.exs --include e2e

# Or use the test runner script
./scripts/run_e2e_tests.sh all
```

### Configuration Options

#### Sandbox Testing (Recommended)

```bash
export PADDLE_SANDBOX_API_KEY="pdl_sdbx_your_key_here"
```

#### Live Environment Testing

**Warning**: Live environment testing creates real resources and may incur charges.

```bash
export PADDLE_API_KEY="pdl_live_your_key_here"
export PADDLE_ENVIRONMENT="live"
```

#### Custom Configuration

```bash
export PADDLE_API_KEY="your_key_here"
export PADDLE_ENVIRONMENT="sandbox"  # or "live"
export PADDLE_BASE_URL="https://custom-api.paddle.com"  # optional
```

### Test Categories

The E2E test suite covers:

#### Product Management
- Complete product lifecycle (create → read → update → archive)
- Product listing with filters and pagination
- Concurrent operations and performance testing

#### Price Management
- Price lifecycle with billing cycles
- Currency handling and validation
- Product association testing

#### Customer Management
- Customer creation and updates
- Email validation and unicode support
- Custom data handling

#### Error Handling
- Authentication errors (invalid API keys)
- Not found errors (non-existent resources)
- Validation errors (invalid data)
- API error classification

#### Performance & Reliability
- Concurrent request handling
- Large dataset processing
- Response time benchmarks
- Memory usage monitoring

#### API Features
- Response format validation
- Webhook endpoint access
- API versioning and headers
- Unicode and special character support

### Running Specific Test Categories

```bash
# Quick test (product lifecycle only)
./scripts/run_e2e_tests.sh quick

# Specific categories
./scripts/run_e2e_tests.sh products
./scripts/run_e2e_tests.sh prices
./scripts/run_e2e_tests.sh customers
./scripts/run_e2e_tests.sh errors
./scripts/run_e2e_tests.sh performance

# All tests
./scripts/run_e2e_tests.sh all

# Show help
./scripts/run_e2e_tests.sh help
```

### Expected Results

```
Running ExUnit with seed: 646363, max_cases: 20
............
Finished in 21.4 seconds (0.00s async, 21.4s sync)
12 tests, 0 failures
```

### Environment Variables Reference

| Variable | Required | Description | Example |
|----------|----------|-------------|---------|
| `PADDLE_API_KEY` | Yes* | Your Paddle API key | `pdl_sdbx_123...` |
| `PADDLE_SANDBOX_API_KEY` | Yes* | Alternative sandbox key variable | `pdl_sdbx_123...` |
| `PADDLE_ENVIRONMENT` | No | Environment (sandbox/live) | `sandbox` (default) |
| `PADDLE_BASE_URL` | No | Custom API base URL | Auto-detected |

*One of `PADDLE_API_KEY` or `PADDLE_SANDBOX_API_KEY` is required.

## Security & Best Practices

### API Key Management

- **Never hardcode API keys** in source code
- **Use environment variables** for all sensitive configuration
- **Use sandbox keys** for development and testing
- **Rotate keys regularly** in production

### Test Data Management

- E2E tests create unique resources using timestamps
- Resources are cleaned up (archived) after tests when possible
- Some sandbox resources may persist (this is normal)

### CI/CD Integration

#### GitHub Actions

```yaml
name: Tests
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: erlef/setup-beam@v1
        with:
          elixir-version: '1.15'
          otp-version: '26'
      - run: mix deps.get
      - run: mix test
      - name: Run E2E Tests
        run: mix test --include e2e
        env:
          PADDLE_SANDBOX_API_KEY: ${{ secrets.PADDLE_SANDBOX_API_KEY }}
```

#### GitLab CI

```yaml
test:
  script:
    - mix deps.get
    - mix test
    - mix test --include e2e
  variables:
    PADDLE_SANDBOX_API_KEY: $PADDLE_SANDBOX_API_KEY
```

## Troubleshooting

### Common Issues

#### API Key Issues

**Error**: "E2E tests require a Paddle API key..."
```bash
export PADDLE_SANDBOX_API_KEY="your_key_here"
```

**Error**: "Invalid API key format..."
- Ensure key starts with `pdl_sdbx_` (sandbox) or `pdl_live_` (live)
- Check for typos or extra characters

#### Network Issues

**Error**: Connection timeouts or network errors
- Verify internet connectivity
- Check if corporate firewall blocks Paddle API
- Try increasing timeout in test configuration

#### Authentication Errors

**Error**: 401/403 responses
- Verify API key is active in Paddle dashboard
- Check if key has required permissions
- Ensure correct environment (sandbox vs live)

#### Rate Limiting

**Error**: 429 Too Many Requests
- Tests include built-in delays
- If needed, add `Process.sleep(1000)` between test groups
- Check API rate limits in Paddle dashboard

### Performance Considerations

- E2E tests are slower than unit tests (20+ seconds vs milliseconds)
- Rate limiting may cause failures when running all tests together
- Run E2E tests separately or with limited concurrency
- Use `--max-cases 1` to run E2E tests sequentially

### Getting Help

If you encounter issues:

1. **Check Configuration**: Ensure environment variables are set correctly
2. **Verify API Key**: Test key manually in Paddle dashboard
3. **Check Network**: Ensure connectivity to Paddle API
4. **Review Logs**: Run tests with `--trace` for detailed output
5. **Update Dependencies**: Ensure latest version of the library

For Paddle API specific issues, consult the [Paddle API Documentation](https://developer.paddle.com/api-reference).