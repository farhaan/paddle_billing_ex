#!/bin/bash

# Paddle Billing E2E Test Runner
# This script makes it easy to run E2E tests with different configurations

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_step() {
    echo -e "${BLUE}==>${NC} $1"
}

print_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if API key is set
check_api_key() {
    if [[ -z "$PADDLE_API_KEY" && -z "$PADDLE_SANDBOX_API_KEY" ]]; then
        print_error "No Paddle API key found in environment variables!"
        echo ""
        echo "Set one of the following:"
        echo "  export PADDLE_SANDBOX_API_KEY=\"pdl_sdbx_your_key_here\""
        echo "  export PADDLE_API_KEY=\"pdl_sdbx_your_key_here\""
        echo ""
        echo "For quick testing with the provided sandbox key:"
        echo "  export PADDLE_SANDBOX_API_KEY=\"pdl_sdbx_apikey_01k2pjtf6kqkqjcc56rz6jwk35_gKVxmrNryprNCpZjv4j4qc_A65\""
        echo ""
        exit 1
    fi
}

# Display current configuration
show_config() {
    print_step "Current E2E Test Configuration:"
    
    if [[ -n "$PADDLE_SANDBOX_API_KEY" ]]; then
        echo "  API Key: PADDLE_SANDBOX_API_KEY (${PADDLE_SANDBOX_API_KEY:0:20}...)"
    elif [[ -n "$PADDLE_API_KEY" ]]; then
        echo "  API Key: PADDLE_API_KEY (${PADDLE_API_KEY:0:20}...)"
    fi
    
    echo "  Environment: ${PADDLE_ENVIRONMENT:-sandbox}"
    echo "  Base URL: ${PADDLE_BASE_URL:-auto-detected}"
    echo ""
}

# Function to run specific test suites
run_test_suite() {
    local test_name="$1"
    local test_pattern="$2"
    
    print_step "Running $test_name..."
    
    if mix test test/paddle_billing/e2e_test.exs $test_pattern --include e2e --formatter ExUnit.CLIFormatter; then
        print_success "$test_name completed successfully"
        return 0
    else
        print_error "$test_name failed"
        return 1
    fi
}

# Main execution
main() {
    echo ""
    echo "Paddle Billing E2E Test Runner"
    echo "=================================="
    echo ""
    
    # Check dependencies
    if ! command -v mix &> /dev/null; then
        print_error "Elixir/Mix is not installed or not in PATH"
        exit 1
    fi
    
    # Check API key
    check_api_key
    
    # Show configuration
    show_config
    
    # Parse command line arguments
    case "${1:-all}" in
        "quick")
            print_step "Running quick E2E test (product lifecycle only)..."
            run_test_suite "Quick Test" "-k 'complete product lifecycle'"
            ;;
        "products")
            print_step "Running Product Management tests..."
            run_test_suite "Product Tests" "-k 'E2E Product Management'"
            ;;
        "prices")
            print_step "Running Price Management tests..."
            run_test_suite "Price Tests" "-k 'E2E Price Management'"
            ;;
        "customers")
            print_step "Running Customer Management tests..."
            run_test_suite "Customer Tests" "-k 'E2E Customer Management'"
            ;;
        "errors")
            print_step "Running Error Handling tests..."
            run_test_suite "Error Tests" "-k 'E2E Error Handling'"
            ;;
        "performance")
            print_step "Running Performance tests..."
            run_test_suite "Performance Tests" "-k 'E2E Performance'"
            ;;
        "all"|"")
            print_step "Running all E2E tests..."
            if mix test test/paddle_billing/e2e_test.exs --include e2e --formatter ExUnit.CLIFormatter; then
                print_success "All E2E tests completed successfully!"
            else
                print_error "Some E2E tests failed"
                exit 1
            fi
            ;;
        "help"|"-h"|"--help")
            echo "Usage: $0 [test_suite]"
            echo ""
            echo "Test suites:"
            echo "  all         - Run all E2E tests (default)"
            echo "  quick       - Run a quick product lifecycle test"
            echo "  products    - Run product management tests"
            echo "  prices      - Run price management tests"
            echo "  customers   - Run customer management tests"
            echo "  errors      - Run error handling tests"
            echo "  performance - Run performance tests"
            echo "  help        - Show this help message"
            echo ""
            echo "Environment Variables:"
            echo "  PADDLE_SANDBOX_API_KEY - Your sandbox API key"
            echo "  PADDLE_API_KEY         - Your API key (sandbox or live)"
            echo "  PADDLE_ENVIRONMENT     - 'sandbox' or 'live' (default: sandbox)"
            echo ""
            echo "Examples:"
            echo "  # Quick test with provided sandbox key"
            echo "  export PADDLE_SANDBOX_API_KEY=\"pdl_sdbx_apikey_01k2pjtf6kqkqjcc56rz6jwk35_gKVxmrNryprNCpZjv4j4qc_A65\""
            echo "  $0 quick"
            echo ""
            echo "  # Full test suite"
            echo "  $0 all"
            echo ""
            echo "  # Test specific functionality"
            echo "  $0 products"
            exit 0
            ;;
        *)
            print_error "Unknown test suite: $1"
            echo "Run '$0 help' for available options"
            exit 1
            ;;
    esac
    
    echo ""
    print_success "E2E test execution completed!"
}

# Run main function
main "$@"