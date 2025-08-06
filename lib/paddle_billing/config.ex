defmodule PaddleBilling.Config do
  @moduledoc """
  Configuration management for Paddle Billing API client.

  Supports both environment variables and application configuration.
  API keys should follow the format: `pdl_live_*` or `pdl_sdbx_*`
  """

  @type environment :: :sandbox | :live
  @type config :: %__MODULE__{
          api_key: String.t(),
          environment: environment(),
          base_url: String.t(),
          timeout: pos_integer(),
          retry: boolean()
        }

  defstruct [:api_key, :environment, :base_url, :timeout, :retry]

  @live_base_url "https://api.paddle.com"
  @sandbox_base_url "https://sandbox-api.paddle.com"
  @default_timeout 30_000
  @default_retry true

  @doc """
  Resolves the configuration from application config or environment variables.

  ## Configuration Priority

  1. Application configuration
  2. Environment variables
  3. Default values

  ## Examples

      # Application config
      config :paddle_billing,
        api_key: "pdl_live_...",
        environment: :live
      
      # Environment variables
      export PADDLE_API_KEY="pdl_sdbx_..."
      export PADDLE_ENVIRONMENT="sandbox"
      
      PaddleBilling.Config.resolve()
      #=> %{
      #     api_key: "pdl_sdbx_...",
      #     environment: :sandbox,
      #     base_url: "https://sandbox-api.paddle.com",
      #     timeout: 30000,
      #     retry: true
      #   }
  """
  @spec resolve() :: config()
  def resolve do
    api_key = get_api_key()
    environment = get_environment(api_key)

    %__MODULE__{
      api_key: api_key,
      environment: environment,
      base_url: get_base_url(environment),
      timeout: get_timeout(),
      retry: get_retry()
    }
  end

  @doc """
  Validates that the configuration is valid for making API requests.
  """
  @spec validate!(config()) :: :ok | no_return()
  def validate!(config) do
    validate_api_key!(config.api_key)
    validate_environment!(config.environment)
    validate_base_url!(config.base_url)
    :ok
  end

  # Private functions

  defp get_api_key do
    Application.get_env(:paddle_billing, :api_key) ||
      System.get_env("PADDLE_API_KEY") ||
      raise_missing_config("API key")
  end

  defp get_environment(api_key) do
    configured_env =
      Application.get_env(:paddle_billing, :environment) ||
        parse_env_var(System.get_env("PADDLE_ENVIRONMENT"))

    configured_env || detect_environment_from_key(api_key)
  end

  defp get_base_url(:live), do: @live_base_url
  defp get_base_url(:sandbox), do: @sandbox_base_url

  defp get_timeout do
    Application.get_env(:paddle_billing, :timeout) ||
      parse_timeout(System.get_env("PADDLE_TIMEOUT")) ||
      @default_timeout
  end

  defp get_retry do
    case Application.get_env(:paddle_billing, :retry) do
      nil ->
        case System.get_env("PADDLE_RETRY") do
          nil -> @default_retry
          "false" -> false
          "true" -> true
          _ -> @default_retry
        end

      retry when is_boolean(retry) ->
        retry

      _ ->
        @default_retry
    end
  end

  defp detect_environment_from_key(api_key) do
    cond do
      String.contains?(api_key, "live_") -> :live
      String.contains?(api_key, "sdbx_") -> :sandbox
      # Default to sandbox for safety
      true -> :sandbox
    end
  end

  defp parse_env_var("live"), do: :live
  defp parse_env_var("sandbox"), do: :sandbox
  defp parse_env_var("production"), do: :live
  defp parse_env_var(_), do: nil

  defp parse_timeout(nil), do: nil

  defp parse_timeout(timeout_str) do
    case Integer.parse(timeout_str) do
      {timeout, ""} when timeout > 0 -> timeout
      _ -> nil
    end
  end

  defp validate_api_key!(api_key) when is_binary(api_key) do
    # Check basic format
    unless String.starts_with?(api_key, "pdl_") do
      raise ArgumentError, """
      Invalid API key format. Paddle API keys should start with 'pdl_'.
      Expected format: pdl_live_... or pdl_sdbx_...
      Got: #{String.slice(api_key, 0, 10)}...
      """
    end

    # Check length constraints (reasonable API key length)
    if String.length(api_key) < 10 or String.length(api_key) > 200 do
      raise ArgumentError, "API key length is invalid. Must be between 10 and 200 characters."
    end

    # Check for malicious patterns
    malicious_patterns = [
      ~r/<script/i,
      ~r/javascript:/i,
      ~r/'; DROP TABLE/i,
      # Path traversal
      ~r/\.\./,
      # HTML/JSON injection characters
      ~r/[<>{}]/,
      # SQL injection
      ~r/OR\s+1=1/i,
      # LDAP injection
      ~r/\$\{jndi:/i,
      # Template injection
      ~r/\{\{.*\}\}/,
      # ERB/template injection
      ~r/<%.*%>/,
      # Command injection
      ~r/`.*`/
    ]

    for pattern <- malicious_patterns do
      if Regex.match?(pattern, api_key) do
        raise ArgumentError, "API key contains invalid characters or patterns"
      end
    end

    # Check for proper environment format (allow test keys for testing)
    unless String.contains?(api_key, "live_") or String.contains?(api_key, "sdbx_") or
             String.contains?(api_key, "test_") do
      raise ArgumentError,
            "API key must contain 'live_', 'sdbx_', or 'test_' to indicate environment"
    end
  end

  defp validate_api_key!("") do
    raise ArgumentError, "API key cannot be empty"
  end

  defp validate_api_key!(nil) do
    raise ArgumentError, "API key cannot be nil"
  end

  defp validate_api_key!(_) do
    raise ArgumentError, "API key must be a string"
  end

  defp validate_environment!(env) when env in [:live, :sandbox], do: :ok

  defp validate_environment!(env) do
    raise ArgumentError, "Invalid environment: #{inspect(env)}. Must be :live or :sandbox"
  end

  defp validate_base_url!(nil) do
    raise ArgumentError, "Base URL cannot be nil"
  end

  defp validate_base_url!("") do
    raise ArgumentError, "Base URL cannot be empty"
  end

  defp validate_base_url!(url) when is_binary(url) do
    case URI.parse(url) do
      %URI{scheme: scheme, host: host} when scheme in ["http", "https"] and is_binary(host) ->
        # Check for dangerous protocols and patterns
        validate_url_safety!(url)
        :ok

      %URI{scheme: nil} ->
        raise ArgumentError, "Base URL must include protocol (http:// or https://)"

      %URI{scheme: scheme} when scheme not in ["http", "https"] ->
        raise ArgumentError, "Base URL must use http or https protocol, got: #{scheme}"

      %URI{host: nil} ->
        raise ArgumentError, "Base URL must include a valid host"

      _ ->
        raise ArgumentError, "Invalid base URL format"
    end
  end

  defp validate_base_url!(_) do
    raise ArgumentError, "Base URL must be a string"
  end

  defp validate_url_safety!(url) do
    dangerous_patterns = [
      ~r/javascript:/i,
      ~r/data:/i,
      ~r/file:/i,
      ~r/ftp:/i,
      ~r/ldap:/i,
      ~r/vbscript:/i,
      # Credentials in URL (user:pass@host or user@host)
      ~r/\/\/[^\/]*@/,
      # Path traversal
      ~r/\.\./,
      # Script injection
      ~r/<script/i,
      # Null bytes
      ~r/%00/,
      # Control characters
      ~r/\x00-\x1f/
    ]

    for pattern <- dangerous_patterns do
      if Regex.match?(pattern, url) do
        raise ArgumentError, "Base URL contains unsafe characters or patterns"
      end
    end
  end

  @spec raise_missing_config(String.t()) :: no_return()
  defp raise_missing_config(config_name) do
    raise RuntimeError, """
    Missing required configuration: #{config_name}

    Please set your Paddle API key using one of these methods:

    1. Application configuration:
       config :paddle_billing, api_key: "pdl_live_..."

    2. Environment variable:
       export PADDLE_API_KEY="pdl_live_..."

    You can get your API key from: https://vendors.paddle.com/authentication
    """
  end
end

defimpl Inspect, for: PaddleBilling.Config do
  @doc """
  Custom inspect implementation that hides sensitive API key information.
  """
  def inspect(config, _opts) do
    masked_api_key = mask_api_key(config.api_key)

    "#PaddleBilling.Config<api_key: #{masked_api_key}, environment: #{config.environment}, base_url: #{config.base_url}, timeout: #{config.timeout}, retry: #{config.retry}>"
  end

  # Mask API key to show only prefix and masked suffix
  defp mask_api_key(api_key) when is_binary(api_key) and byte_size(api_key) > 8 do
    prefix = String.slice(api_key, 0..7)
    suffix_length = byte_size(api_key) - 8
    masked_suffix = String.duplicate("*", min(suffix_length, 20))
    "\"#{prefix}#{masked_suffix}\""
  end

  defp mask_api_key(api_key) when is_binary(api_key) do
    masked = String.duplicate("*", byte_size(api_key))
    "\"#{masked}\""
  end

  defp mask_api_key(_), do: "\"***INVALID***\""
end
