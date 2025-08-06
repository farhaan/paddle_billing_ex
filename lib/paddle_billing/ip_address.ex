defmodule PaddleBilling.IpAddress do
  @moduledoc """
  Manage IP addresses in Paddle Billing.

  This module provides functionality to retrieve Paddle's IP addresses
  that should be added to your allowlist for secure webhook delivery.
  Paddle sends webhooks from these IP addresses, so adding them to your
  firewall or security configuration ensures reliable webhook delivery.
  """

  alias PaddleBilling.{Client, Error}

  @type t :: %__MODULE__{
          ip: String.t(),
          type: String.t(),
          description: String.t() | nil
        }

  defstruct [
    :ip,
    :type,
    :description
  ]

  @doc """
  Lists all Paddle IP addresses.

  Returns the current list of IP addresses that Paddle uses to send webhooks
  and other API communications. You should add these to your firewall
  allowlist to ensure reliable webhook delivery.

  ## Examples

      PaddleBilling.IpAddress.list()
      {:ok, [
        %PaddleBilling.IpAddress{
          ip: "34.194.127.46",
          type: "webhook",
          description: "Primary webhook delivery"
        },
        %PaddleBilling.IpAddress{
          ip: "54.234.237.108", 
          type: "webhook",
          description: "Secondary webhook delivery"
        },
        ...
      ]}

      # With custom configuration
      PaddleBilling.IpAddress.list(config: custom_config)
      {:ok, [%PaddleBilling.IpAddress{}, ...]}
  """
  @spec list(keyword()) :: {:ok, [t()]} | {:error, Error.t()}
  def list(opts \\ []) do
    case Client.get("/ips", %{}, opts) do
      {:ok, ips} when is_list(ips) ->
        {:ok, Enum.map(ips, &from_api/1)}

      {:ok, response} ->
        {:error, Error.from_response(response)}

      error ->
        error
    end
  end

  @doc """
  Gets webhook IP addresses only.

  Convenience function to filter IP addresses used specifically for webhook delivery.

  ## Examples

      PaddleBilling.IpAddress.list_webhook_ips()
      {:ok, [%PaddleBilling.IpAddress{type: "webhook"}, ...]}
  """
  @spec list_webhook_ips(keyword()) :: {:ok, [t()]} | {:error, Error.t()}
  def list_webhook_ips(opts \\ []) do
    case list(opts) do
      {:ok, ips} ->
        webhook_ips = Enum.filter(ips, &webhook_ip?/1)
        {:ok, webhook_ips}

      error ->
        error
    end
  end

  @doc """
  Gets all IP addresses as strings.

  Convenience function to extract just the IP address strings,
  useful for firewall configuration scripts.

  ## Examples

      PaddleBilling.IpAddress.list_ip_strings()
      {:ok, ["34.194.127.46", "54.234.237.108", ...]}

      # Get only webhook IPs as strings
      {:ok, webhook_ips} = PaddleBilling.IpAddress.list_webhook_ips()
      ip_strings = PaddleBilling.IpAddress.extract_ip_strings(webhook_ips)
      ["34.194.127.46", "54.234.237.108", ...]
  """
  @spec list_ip_strings(keyword()) :: {:ok, [String.t()]} | {:error, Error.t()}
  def list_ip_strings(opts \\ []) do
    case list(opts) do
      {:ok, ips} ->
        ip_strings = Enum.map(ips, & &1.ip)
        {:ok, ip_strings}

      error ->
        error
    end
  end

  @doc """
  Extracts IP strings from a list of IP address structs.

  ## Examples

      ip_structs = [%PaddleBilling.IpAddress{ip: "1.2.3.4"}, ...]
      PaddleBilling.IpAddress.extract_ip_strings(ip_structs)
      ["1.2.3.4", ...]
  """
  @spec extract_ip_strings([t()]) :: [String.t()]
  def extract_ip_strings(ip_structs) when is_list(ip_structs) do
    Enum.map(ip_structs, & &1.ip)
  end

  @doc """
  Generates firewall allowlist configuration.

  Creates configuration snippets for common firewall formats.

  ## Examples

      {:ok, ips} = PaddleBilling.IpAddress.list_webhook_ips()
      
      # For iptables
      PaddleBilling.IpAddress.generate_firewall_config(ips, :iptables)
      [
        "iptables -A INPUT -s 34.194.127.46 -j ACCEPT",
        "iptables -A INPUT -s 54.234.237.108 -j ACCEPT",
        ...
      ]

      # For nginx allowlist
      PaddleBilling.IpAddress.generate_firewall_config(ips, :nginx)
      [
        "allow 34.194.127.46;",
        "allow 54.234.237.108;",
        ...
      ]

      # For AWS Security Group (CIDR format)
      PaddleBilling.IpAddress.generate_firewall_config(ips, :aws_sg)
      [
        "34.194.127.46/32",
        "54.234.237.108/32",
        ...
      ]
  """
  @spec generate_firewall_config([t()], atom()) :: [String.t()]
  def generate_firewall_config(ip_structs, format) when is_list(ip_structs) do
    ip_strings = extract_ip_strings(ip_structs)

    case format do
      :iptables ->
        Enum.map(ip_strings, &"iptables -A INPUT -s #{&1} -j ACCEPT")

      :nginx ->
        Enum.map(ip_strings, &"allow #{&1};")

      :aws_sg ->
        Enum.map(ip_strings, &"#{&1}/32")

      :cloudflare ->
        Enum.map(ip_strings, &"#{&1}/32")

      :plain ->
        ip_strings

      _ ->
        ip_strings
    end
  end

  @doc """
  Checks if an IP address is for webhook delivery.

  ## Examples

      webhook_ip = %PaddleBilling.IpAddress{type: "webhook"}
      PaddleBilling.IpAddress.webhook_ip?(webhook_ip)
      true

      api_ip = %PaddleBilling.IpAddress{type: "api"}
      PaddleBilling.IpAddress.webhook_ip?(api_ip)
      false
  """
  @spec webhook_ip?(t()) :: boolean()
  def webhook_ip?(%__MODULE__{type: "webhook"}), do: true
  def webhook_ip?(%__MODULE__{}), do: false

  @doc """
  Validates if a string is a valid IPv4 address.

  ## Examples

      PaddleBilling.IpAddress.valid_ipv4?("192.168.1.1")
      true

      PaddleBilling.IpAddress.valid_ipv4?("invalid")
      false
  """
  @spec valid_ipv4?(String.t()) :: boolean()
  def valid_ipv4?(ip_string) when is_binary(ip_string) do
    # Check that IP has exactly 4 octets separated by dots
    parts = String.split(ip_string, ".")

    if length(parts) == 4 do
      case :inet.parse_ipv4_address(String.to_charlist(ip_string)) do
        {:ok, _} -> true
        _ -> false
      end
    else
      false
    end
  end

  def valid_ipv4?(_), do: false

  @doc """
  Validates if all IP addresses in a list are valid IPv4.

  ## Examples

      ips = [%PaddleBilling.IpAddress{ip: "192.168.1.1"}, %PaddleBilling.IpAddress{ip: "10.0.0.1"}]
      PaddleBilling.IpAddress.all_valid_ipv4?(ips)
      true
  """
  @spec all_valid_ipv4?([t()]) :: boolean()
  def all_valid_ipv4?(ip_structs) when is_list(ip_structs) do
    Enum.all?(ip_structs, fn ip_struct ->
      valid_ipv4?(ip_struct.ip)
    end)
  end

  # Private functions

  @spec from_api(map()) :: t()
  defp from_api(data) when is_map(data) do
    %__MODULE__{
      ip: Map.get(data, "ip"),
      type: Map.get(data, "type", "webhook"),
      description: Map.get(data, "description")
    }
  end
end
