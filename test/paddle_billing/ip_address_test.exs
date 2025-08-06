defmodule PaddleBilling.IpAddressTest do
  use ExUnit.Case, async: true
  alias PaddleBilling.{IpAddress, Error}

  setup do
    bypass = Bypass.open()

    config = %{
      api_key: "pdl_test_123456789",
      environment: :sandbox,
      base_url: "http://localhost:#{bypass.port}",
      timeout: 30_000,
      retry: false
    }

    {:ok, bypass: bypass, config: config}
  end

  describe "list/1" do
    test "returns list of IP addresses", %{bypass: bypass, config: config} do
      ips_response = [
        %{
          "ip" => "34.194.127.46",
          "type" => "webhook",
          "description" => "Primary webhook delivery"
        },
        %{
          "ip" => "54.234.237.108",
          "type" => "webhook",
          "description" => "Secondary webhook delivery"
        },
        %{
          "ip" => "52.45.78.201",
          "type" => "api",
          "description" => "API requests"
        }
      ]

      Bypass.expect(bypass, "GET", "/ips", fn conn ->
        Plug.Conn.resp(
          conn,
          200,
          Jason.encode!(%{"data" => ips_response})
        )
      end)

      assert {:ok, ips} = IpAddress.list(config: config)
      assert length(ips) == 3

      first_ip = List.first(ips)
      assert first_ip.ip == "34.194.127.46"
      assert first_ip.type == "webhook"
      assert first_ip.description == "Primary webhook delivery"
    end

    test "handles API errors", %{bypass: bypass, config: config} do
      Bypass.expect(bypass, "GET", "/ips", fn conn ->
        Plug.Conn.resp(conn, 500, Jason.encode!(%{"error" => "Internal Server Error"}))
      end)

      assert {:error, %Error{}} = IpAddress.list(config: config)
    end
  end

  describe "list_webhook_ips/1" do
    test "filters webhook IP addresses only", %{bypass: bypass, config: config} do
      ips_response = [
        %{
          "ip" => "34.194.127.46",
          "type" => "webhook",
          "description" => "Primary webhook delivery"
        },
        %{
          "ip" => "52.45.78.201",
          "type" => "api",
          "description" => "API requests"
        },
        %{
          "ip" => "54.234.237.108",
          "type" => "webhook",
          "description" => "Secondary webhook delivery"
        }
      ]

      Bypass.expect(bypass, "GET", "/ips", fn conn ->
        Plug.Conn.resp(
          conn,
          200,
          Jason.encode!(%{"data" => ips_response})
        )
      end)

      assert {:ok, webhook_ips} = IpAddress.list_webhook_ips(config: config)
      assert length(webhook_ips) == 2
      assert Enum.all?(webhook_ips, &(&1.type == "webhook"))
    end

    test "returns empty list when no webhook IPs", %{bypass: bypass, config: config} do
      ips_response = [
        %{
          "ip" => "52.45.78.201",
          "type" => "api",
          "description" => "API requests"
        }
      ]

      Bypass.expect(bypass, "GET", "/ips", fn conn ->
        Plug.Conn.resp(
          conn,
          200,
          Jason.encode!(%{"data" => ips_response})
        )
      end)

      assert {:ok, webhook_ips} = IpAddress.list_webhook_ips(config: config)
      assert Enum.empty?(webhook_ips)
    end
  end

  describe "list_ip_strings/1" do
    test "returns IP addresses as strings", %{bypass: bypass, config: config} do
      ips_response = [
        %{
          "ip" => "34.194.127.46",
          "type" => "webhook"
        },
        %{
          "ip" => "54.234.237.108",
          "type" => "webhook"
        }
      ]

      Bypass.expect(bypass, "GET", "/ips", fn conn ->
        Plug.Conn.resp(
          conn,
          200,
          Jason.encode!(%{"data" => ips_response})
        )
      end)

      assert {:ok, ip_strings} = IpAddress.list_ip_strings(config: config)
      assert ip_strings == ["34.194.127.46", "54.234.237.108"]
    end
  end

  describe "extract_ip_strings/1" do
    test "extracts IP strings from structs" do
      ip_structs = [
        %IpAddress{ip: "192.168.1.1", type: "webhook"},
        %IpAddress{ip: "10.0.0.1", type: "api"}
      ]

      ip_strings = IpAddress.extract_ip_strings(ip_structs)
      assert ip_strings == ["192.168.1.1", "10.0.0.1"]
    end

    test "handles empty list" do
      assert IpAddress.extract_ip_strings([]) == []
    end
  end

  describe "generate_firewall_config/2" do
    setup do
      ip_structs = [
        %IpAddress{ip: "34.194.127.46", type: "webhook"},
        %IpAddress{ip: "54.234.237.108", type: "webhook"}
      ]

      {:ok, ip_structs: ip_structs}
    end

    test "generates iptables configuration", %{ip_structs: ip_structs} do
      config = IpAddress.generate_firewall_config(ip_structs, :iptables)

      assert config == [
               "iptables -A INPUT -s 34.194.127.46 -j ACCEPT",
               "iptables -A INPUT -s 54.234.237.108 -j ACCEPT"
             ]
    end

    test "generates nginx configuration", %{ip_structs: ip_structs} do
      config = IpAddress.generate_firewall_config(ip_structs, :nginx)

      assert config == [
               "allow 34.194.127.46;",
               "allow 54.234.237.108;"
             ]
    end

    test "generates AWS Security Group CIDR format", %{ip_structs: ip_structs} do
      config = IpAddress.generate_firewall_config(ip_structs, :aws_sg)

      assert config == [
               "34.194.127.46/32",
               "54.234.237.108/32"
             ]
    end

    test "generates Cloudflare format", %{ip_structs: ip_structs} do
      config = IpAddress.generate_firewall_config(ip_structs, :cloudflare)

      assert config == [
               "34.194.127.46/32",
               "54.234.237.108/32"
             ]
    end

    test "generates plain IP list", %{ip_structs: ip_structs} do
      config = IpAddress.generate_firewall_config(ip_structs, :plain)

      assert config == [
               "34.194.127.46",
               "54.234.237.108"
             ]
    end

    test "defaults to plain format for unknown format", %{ip_structs: ip_structs} do
      config = IpAddress.generate_firewall_config(ip_structs, :unknown_format)

      assert config == [
               "34.194.127.46",
               "54.234.237.108"
             ]
    end

    test "handles empty IP list" do
      config = IpAddress.generate_firewall_config([], :iptables)
      assert config == []
    end
  end

  describe "helper functions" do
    test "webhook_ip?/1" do
      webhook_ip = %IpAddress{type: "webhook"}
      api_ip = %IpAddress{type: "api"}

      assert IpAddress.webhook_ip?(webhook_ip) == true
      assert IpAddress.webhook_ip?(api_ip) == false
    end

    test "valid_ipv4?/1" do
      assert IpAddress.valid_ipv4?("192.168.1.1") == true
      assert IpAddress.valid_ipv4?("0.0.0.0") == true
      assert IpAddress.valid_ipv4?("255.255.255.255") == true

      assert IpAddress.valid_ipv4?("invalid") == false
      assert IpAddress.valid_ipv4?("256.1.1.1") == false
      assert IpAddress.valid_ipv4?("192.168.1") == false
      assert IpAddress.valid_ipv4?("192.168.1.1.1") == false
      assert IpAddress.valid_ipv4?("") == false
      assert IpAddress.valid_ipv4?(nil) == false
      assert IpAddress.valid_ipv4?(123) == false
    end

    test "all_valid_ipv4?/1" do
      valid_ips = [
        %IpAddress{ip: "192.168.1.1"},
        %IpAddress{ip: "10.0.0.1"}
      ]

      invalid_ips = [
        %IpAddress{ip: "192.168.1.1"},
        %IpAddress{ip: "invalid"}
      ]

      assert IpAddress.all_valid_ipv4?(valid_ips) == true
      assert IpAddress.all_valid_ipv4?(invalid_ips) == false
      assert IpAddress.all_valid_ipv4?([]) == true
    end
  end

  describe "integration scenarios" do
    test "full webhook IP allowlist workflow", %{bypass: bypass, config: config} do
      # Mock API response with webhook IPs
      ips_response = [
        %{
          "ip" => "34.194.127.46",
          "type" => "webhook",
          "description" => "Primary webhook delivery"
        },
        %{
          "ip" => "54.234.237.108",
          "type" => "webhook",
          "description" => "Secondary webhook delivery"
        },
        %{
          "ip" => "52.45.78.201",
          "type" => "api",
          "description" => "API requests"
        }
      ]

      Bypass.expect(bypass, "GET", "/ips", fn conn ->
        Plug.Conn.resp(
          conn,
          200,
          Jason.encode!(%{"data" => ips_response})
        )
      end)

      # Get webhook IPs
      assert {:ok, webhook_ips} = IpAddress.list_webhook_ips(config: config)
      assert length(webhook_ips) == 2

      # Validate all IPs
      assert IpAddress.all_valid_ipv4?(webhook_ips) == true

      # Generate firewall configs
      iptables_rules = IpAddress.generate_firewall_config(webhook_ips, :iptables)
      nginx_rules = IpAddress.generate_firewall_config(webhook_ips, :nginx)

      assert length(iptables_rules) == 2
      assert length(nginx_rules) == 2
      assert Enum.all?(iptables_rules, &String.contains?(&1, "iptables"))
      assert Enum.all?(nginx_rules, &String.contains?(&1, "allow"))
    end

    test "handles mixed IP types correctly", %{bypass: bypass, config: config} do
      ips_response = [
        %{"ip" => "1.2.3.4", "type" => "webhook"},
        %{"ip" => "5.6.7.8", "type" => "api"},
        %{"ip" => "9.10.11.12", "type" => "webhook"}
      ]

      Bypass.expect(bypass, "GET", "/ips", fn conn ->
        Plug.Conn.resp(
          conn,
          200,
          Jason.encode!(%{"data" => ips_response})
        )
      end)

      # Test full list
      assert {:ok, all_ips} = IpAddress.list(config: config)
      assert length(all_ips) == 3

      # Test webhook filtering
      assert {:ok, webhook_ips} = IpAddress.list_webhook_ips(config: config)
      assert length(webhook_ips) == 2
      assert Enum.all?(webhook_ips, &IpAddress.webhook_ip?/1)

      # Test IP string extraction
      assert {:ok, all_ip_strings} = IpAddress.list_ip_strings(config: config)
      assert "1.2.3.4" in all_ip_strings
      assert "5.6.7.8" in all_ip_strings
      assert "9.10.11.12" in all_ip_strings
    end
  end
end
