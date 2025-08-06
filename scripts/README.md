# API Coverage Testing Scripts

This directory contains scripts to verify API endpoint coverage against OpenAPI specifications.

## api_coverage.exs

A script that analyzes OpenAPI specifications and generates unit tests to verify whether API endpoints are implemented in the PaddleBilling Elixir library.

### Usage

```bash
# Analyze coverage from OpenAPI spec
elixir scripts/api_coverage.exs <openapi_spec_file_or_url>

# Generate test file and show coverage report  
elixir scripts/api_coverage.exs <openapi_spec_file_or_url> <output_test_file>
```

### Examples

```bash
# Analyze coverage from local YAML file
elixir scripts/api_coverage.exs sample_openapi.yaml

# Generate tests and coverage report
elixir scripts/api_coverage.exs sample_openapi.yaml test/api_coverage_test.exs

# Analyze from remote URL (if accessible)
elixir scripts/api_coverage.exs https://example.com/api/openapi.yaml
```

### Output

The script provides:

1. **Coverage Analysis**: Shows which endpoints are implemented vs missing
2. **Test Generation**: Creates ExUnit tests that verify function exports
3. **Detailed Mapping**: Maps OpenAPI paths to expected Elixir module functions

### Sample Output

```
Analyzing API coverage from: sample_openapi.yaml
Found 10 endpoints:
  [✓] GET /products -> PaddleBilling.Product.list/2
  [✗] POST /products -> PaddleBilling.Product.create/2
  [✓] GET /products/{product_id} -> PaddleBilling.Product.get/3
  ...

Coverage: 7/10 (70%)
```

### Supported API Patterns

The script recognizes common REST API patterns and maps them to expected Elixir functions:

- `GET /resources` → `Module.list/2`
- `POST /resources` → `Module.create/2` 
- `GET /resources/{id}` → `Module.get/3`
- `PATCH /resources/{id}` → `Module.update/3`
- Other endpoints → `Client.{method}/3`

### Extending the Script

To add support for new API resources, update the `get_expected_implementation/1` function with new pattern matches.

## Dependencies

The script requires these packages (automatically installed):
- `jason` - JSON parsing
- `req` - HTTP requests
- `yaml_elixir` - YAML parsing